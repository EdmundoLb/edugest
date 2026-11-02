<script setup>
// Familia de un alumno en su perfil: tutores vinculados al portal y, para el
// admin, los códigos de vinculación (generar, compartir por WhatsApp, anular).
// El docente solo ve los tutores (tutores_de_alumno filtra por permiso).
import { ref, watch } from 'vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import {
  tutoresDeAlumno,
  desvincularTutor,
  generarCodigo,
  codigosActivos,
  anularCodigo,
  esFuncionFaltante,
  esEsquemaFaltante,
} from '@/lib/api/familias'
import { formatearCodigo, linkRegistroConCodigo } from '@/lib/vinculacion'
import { linkWhatsapp, linkWhatsappGrupo, armarMensajeCodigoVinculacion } from '@/lib/whatsapp'
import { formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const props = defineProps({
  // { id, nombre, apellido, telefono_padre }
  alumno: { type: Object, required: true },
})

const emit = defineEmits(['cambio'])

const { esAdmin } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const tutores = ref([])
const codigos = ref([])
const cargando = ref(false)
const faltaMigracion = ref(false)
const generando = ref(false)

watch(() => props.alumno.id, cargar, { immediate: true })

async function cargar() {
  cargando.value = true
  faltaMigracion.value = false
  try {
    const [t, c] = await Promise.all([
      tutoresDeAlumno(props.alumno.id),
      esAdmin() ? codigosActivos(props.alumno.id) : [],
    ])
    tutores.value = t
    codigos.value = c
  } catch (e) {
    if (esFuncionFaltante(e) || esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudo cargar la familia del alumno', e)
  } finally {
    cargando.value = false
  }
}

async function generar() {
  generando.value = true
  try {
    await generarCodigo(props.alumno.id)
    codigos.value = await codigosActivos(props.alumno.id)
    toast.exito('Código generado. Compartilo con la familia.')
  } catch (e) {
    toast.error('No se pudo generar el código', e)
  } finally {
    generando.value = false
  }
}

function vence(c) {
  return fechaLocalDeTimestamp(c.expira_at)
}

function mensaje(c) {
  return armarMensajeCodigoVinculacion({
    alumno: props.alumno,
    codigo: formatearCodigo(c.codigo),
    vence: vence(c),
    link: linkRegistroConCodigo(window.location.origin, c.codigo),
  })
}

// Sin teléfono cargado, WhatsApp abre el selector de chat.
function linkCompartir(c) {
  return linkWhatsapp(props.alumno.telefono_padre, mensaje(c)) ?? linkWhatsappGrupo(mensaje(c))
}

async function copiar(c) {
  try {
    await navigator.clipboard.writeText(mensaje(c))
    toast.exito('Mensaje copiado')
  } catch {
    toast.info(`Código: ${formatearCodigo(c.codigo)}`)
  }
}

async function anular(c) {
  const ok = await confirmar({
    titulo: '¿Anular este código?',
    mensaje: 'La familia ya no va a poder usarlo para vincularse.',
    aceptar: 'Anular',
    peligro: true,
  })
  if (!ok) return
  try {
    await anularCodigo(c.codigo)
    codigos.value = codigos.value.filter((x) => x.codigo !== c.codigo)
    toast.exito('Código anulado')
  } catch (e) {
    toast.error('No se pudo anular el código', e)
  }
}

async function desvincular(t) {
  const ok = await confirmar({
    titulo: `¿Desvincular a ${t.nombre} ${t.apellido}?`,
    mensaje: 'Deja de ver la asistencia de este alumno en el portal de familias.',
    aceptar: 'Desvincular',
    peligro: true,
  })
  if (!ok) return
  try {
    await desvincularTutor(t.vinculo_id)
    toast.exito('Tutor desvinculado')
    await cargar()
    emit('cambio')
  } catch (e) {
    toast.error('No se pudo desvincular', e)
  }
}
</script>

<template>
  <section class="tarjeta familia" aria-label="Familia">
    <div class="cabecera">
      <h2>Familia</h2>
      <button
        v-if="esAdmin() && !faltaMigracion"
        type="button"
        class="btn btn-primario btn-chico"
        :disabled="generando"
        @click="generar"
      >
        {{ generando ? 'Generando...' : 'Generar código para la familia' }}
      </button>
    </div>

    <p v-if="faltaMigracion" class="aviso">
      El portal de familias no está habilitado: falta aplicar la migración
      <code>0013_portal_familias.sql</code>.
    </p>

    <p v-else-if="cargando" class="texto-muted">Cargando...</p>

    <template v-else>
      <ul v-if="codigos.length" class="codigos">
        <li v-for="c in codigos" :key="c.codigo" class="codigo-item">
          <div>
            <span class="codigo">{{ formatearCodigo(c.codigo) }}</span>
            <span class="texto-muted chico">
              vence el {{ formatearFecha(vence(c), { day: 'numeric', month: 'long' }) }}
            </span>
          </div>
          <div class="acciones">
            <a
              :href="linkCompartir(c)"
              target="_blank"
              rel="noopener"
              class="btn btn-secundario btn-chico"
              >Enviar por WhatsApp</a
            >
            <button type="button" class="btn btn-secundario btn-chico" @click="copiar(c)">
              Copiar mensaje
            </button>
            <button type="button" class="btn btn-peligro btn-chico" @click="anular(c)">
              Anular
            </button>
          </div>
        </li>
      </ul>

      <p v-if="!tutores.length" class="texto-muted chico">
        Ningún familiar vinculado al portal todavía.
        <template v-if="esAdmin()">
          Generá un código y compartilo con la familia para que pueda ver la asistencia.
        </template>
      </p>

      <ul v-else class="tutores">
        <li v-for="t in tutores" :key="t.vinculo_id" class="tutor">
          <div class="tutor-datos">
            <strong>{{ t.nombre }} {{ t.apellido }}</strong>
            <span v-if="t.principal" class="badge">Contacto principal</span>
            <span v-if="t.parentesco" class="texto-muted chico">{{ t.parentesco }}</span>
            <span class="texto-muted chico">
              {{ t.telefono || 'Sin teléfono' }}<template v-if="t.email"> · {{ t.email }}</template>
            </span>
          </div>
          <button
            v-if="esAdmin()"
            type="button"
            class="btn btn-peligro btn-chico"
            @click="desvincular(t)"
          >
            Desvincular
          </button>
        </li>
      </ul>
    </template>
  </section>
</template>

<style scoped>
.familia {
  padding: 1.25rem;
}

.cabecera {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  margin-bottom: 0.75rem;
}

.cabecera h2 {
  font-size: 1.125rem;
  font-weight: 700;
}

.chico {
  font-size: 0.8125rem;
}

.aviso {
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--warning-border);
  border-radius: var(--radius-sm);
  background: var(--warning-soft);
  font-size: 0.875rem;
}

.codigos,
.tutores {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.codigos {
  margin-bottom: 1rem;
}

.codigo-item,
.tutor {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  padding: 0.75rem;
  border: 1px solid var(--border);
  border-radius: var(--radius);
}

.codigo-item {
  background: var(--primary-soft);
  border-style: dashed;
}

.codigo-item > div:first-child,
.tutor-datos {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.codigo {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 1.125rem;
  font-weight: 700;
  letter-spacing: 0.12em;
}

.acciones {
  display: flex;
  gap: 0.375rem;
  flex-wrap: wrap;
}

.badge {
  align-self: flex-start;
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  background: var(--success-soft);
  color: var(--success-text);
  font-size: 0.6875rem;
  font-weight: 600;
}
</style>
