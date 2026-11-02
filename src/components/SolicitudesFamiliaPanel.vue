<script setup>
// La familia avisa una ausencia o pide justificar faltas (con certificado
// opcional) y sigue el estado de lo que mandó. Admin o el docente del curso
// la aprueba en /solicitudes; al aprobarse, la base justifica las faltas.
import { ref, computed, watch } from 'vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import { inscripcionesDeAlumno } from '@/lib/api/historial'
import {
  crearSolicitud,
  solicitudesDeAlumno,
  cancelarSolicitud,
  urlAdjunto,
  esEsquemaFaltante,
} from '@/lib/api/solicitudes'
import { ESTADOS_SOLICITUD, TIPOS_ADJUNTO, validarAdjunto, describirRango } from '@/lib/solicitudes'
import { hoyLocal, sumarDias } from '@/lib/fecha'

const props = defineProps({
  alumnoId: { type: String, required: true },
  nombreAlumno: { type: String, default: '' },
})

const { state } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const hoy = hoyLocal()
const MIN_FECHA = sumarDias(hoy, -60)
const MAX_FECHA = sumarDias(hoy, 60)

const lista = ref([])
const cursos = ref([])
const cargando = ref(false)
const faltaMigracion = ref(false)
const mostrarFormulario = ref(false)
const enviando = ref(false)
const errorFormulario = ref('')

const vacio = () => ({ cursoId: '', desde: hoy, hasta: hoy, motivo: '', archivo: null })
const form = ref(vacio())

const formularioValido = computed(
  () =>
    form.value.desde &&
    form.value.hasta &&
    form.value.hasta >= form.value.desde &&
    form.value.motivo.trim().length >= 3,
)

watch(() => props.alumnoId, cargar, { immediate: true })

async function cargar() {
  cargando.value = true
  faltaMigracion.value = false
  try {
    const [solicitudes, inscripciones] = await Promise.all([
      solicitudesDeAlumno(props.alumnoId),
      inscripcionesDeAlumno(props.alumnoId),
    ])
    lista.value = solicitudes
    cursos.value = inscripciones.filter((i) => i.activa)
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudieron cargar los avisos enviados', e)
  } finally {
    cargando.value = false
  }
}

function abrir() {
  form.value = vacio()
  errorFormulario.value = ''
  mostrarFormulario.value = true
}

function elegirArchivo(e) {
  const archivo = e.target.files?.[0] ?? null
  errorFormulario.value = validarAdjunto(archivo) ?? ''
  form.value.archivo = errorFormulario.value ? null : archivo
  if (errorFormulario.value) e.target.value = ''
}

async function enviar() {
  if (!formularioValido.value) return
  enviando.value = true
  errorFormulario.value = ''
  try {
    await crearSolicitud({ alumnoId: props.alumnoId, ...form.value })
    toast.exito('Aviso enviado. La institución lo va a revisar.')
    mostrarFormulario.value = false
    await cargar()
  } catch (e) {
    toast.error('No se pudo enviar el aviso', e)
  } finally {
    enviando.value = false
  }
}

async function cancelar(s) {
  const ok = await confirmar({
    titulo: '¿Cancelar este aviso?',
    mensaje: 'La institución ya no lo va a ver como pendiente.',
    aceptar: 'Cancelar aviso',
    cancelar: 'Volver',
    peligro: true,
  })
  if (!ok) return
  try {
    await cancelarSolicitud(s.id)
    toast.exito('Aviso cancelado')
    await cargar()
  } catch (e) {
    toast.error('No se pudo cancelar', e)
  }
}

async function verAdjunto(s) {
  try {
    window.open(await urlAdjunto(s.adjunto_path), '_blank', 'noopener')
  } catch (e) {
    toast.error('No se pudo abrir el certificado', e)
  }
}
</script>

<template>
  <section class="tarjeta solicitudes" aria-label="Avisos y justificaciones">
    <div class="cabecera">
      <div>
        <h2>Avisar una ausencia o justificar faltas</h2>
        <p class="texto-muted chico">
          Contale a la institución por qué {{ nombreAlumno || 'tu hijo' }} faltó o va a faltar.
          Podés adjuntar un certificado.
        </p>
      </div>
      <button
        v-if="!faltaMigracion && !mostrarFormulario"
        type="button"
        class="btn btn-primario btn-chico"
        @click="abrir"
      >
        Nuevo aviso
      </button>
    </div>

    <p v-if="faltaMigracion" class="aviso">
      Esta función todavía no está habilitada en la institución.
    </p>

    <form v-if="mostrarFormulario" class="formulario" @submit.prevent="enviar">
      <div class="campo">
        <label for="sol-curso">Curso</label>
        <select id="sol-curso" v-model="form.cursoId" class="input">
          <option value="">Todos sus cursos</option>
          <option v-for="c in cursos" :key="c.cursoId" :value="c.cursoId">
            {{ c.cursoNombre }}
          </option>
        </select>
      </div>
      <div class="fechas">
        <div class="campo">
          <label for="sol-desde">Desde</label>
          <input
            id="sol-desde"
            v-model="form.desde"
            class="input"
            type="date"
            :min="MIN_FECHA"
            :max="MAX_FECHA"
            required
          />
        </div>
        <div class="campo">
          <label for="sol-hasta">Hasta</label>
          <input
            id="sol-hasta"
            v-model="form.hasta"
            class="input"
            type="date"
            :min="form.desde || MIN_FECHA"
            :max="MAX_FECHA"
            required
          />
        </div>
      </div>
      <div class="campo">
        <label for="sol-motivo">Motivo</label>
        <textarea
          id="sol-motivo"
          v-model="form.motivo"
          class="input"
          rows="3"
          maxlength="500"
          placeholder="Ej: turno médico, enfermedad, viaje familiar"
          required
        />
      </div>
      <div class="campo">
        <label for="sol-archivo">Certificado (opcional, PDF o foto, hasta 5 MB)</label>
        <input
          id="sol-archivo"
          class="input"
          type="file"
          :accept="TIPOS_ADJUNTO"
          @change="elegirArchivo"
        />
      </div>

      <p v-if="errorFormulario" class="error" role="alert">{{ errorFormulario }}</p>

      <div class="acciones">
        <button type="button" class="btn btn-secundario" @click="mostrarFormulario = false">
          Cancelar
        </button>
        <button type="submit" class="btn btn-primario" :disabled="!formularioValido || enviando">
          {{ enviando ? 'Enviando...' : 'Enviar aviso' }}
        </button>
      </div>
    </form>

    <p v-if="cargando" class="texto-muted chico">Cargando...</p>

    <ul v-else-if="lista.length" class="lista">
      <li v-for="s in lista" :key="s.id" class="item">
        <div class="item-cabecera">
          <strong>{{ describirRango(s.desde, s.hasta) }}</strong>
          <span :class="['estado', s.estado]">{{ ESTADOS_SOLICITUD[s.estado] }}</span>
        </div>
        <span class="texto-muted chico">{{ s.cursos?.nombre ?? 'Todos sus cursos' }}</span>
        <p class="motivo">{{ s.motivo }}</p>
        <p v-if="s.respuesta" class="respuesta">
          <strong>Respuesta de la institución:</strong> {{ s.respuesta }}
        </p>
        <div class="item-acciones">
          <button
            v-if="s.adjunto_path"
            type="button"
            class="btn btn-secundario btn-chico"
            @click="verAdjunto(s)"
          >
            Ver certificado
          </button>
          <button
            v-if="s.estado === 'pendiente' && s.creada_por === state.user?.id"
            type="button"
            class="btn btn-peligro btn-chico"
            @click="cancelar(s)"
          >
            Cancelar
          </button>
        </div>
      </li>
    </ul>

    <p v-else-if="!faltaMigracion" class="texto-muted chico">Todavía no enviaste avisos.</p>
  </section>
</template>

<style scoped>
.solicitudes {
  padding: 1.25rem;
}

.cabecera {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 0.75rem;
  flex-wrap: wrap;
  margin-bottom: 1rem;
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

.formulario {
  display: flex;
  flex-direction: column;
  gap: 0.875rem;
  padding: 1rem;
  margin-bottom: 1rem;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--surface-2);
}

.fechas {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

textarea.input {
  resize: vertical;
  font-family: inherit;
}

.error {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--danger-border);
  border-radius: var(--radius-sm);
  background: var(--danger-soft);
  color: var(--danger-text);
  font-size: 0.875rem;
}

.acciones,
.item-acciones {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.acciones {
  justify-content: flex-end;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
}

.item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.75rem;
  border: 1px solid var(--border);
  border-radius: var(--radius);
}

.item-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
}

.motivo {
  font-size: 0.875rem;
}

.respuesta {
  font-size: 0.8125rem;
  color: var(--text-2);
}

.item-acciones:empty {
  display: none;
}

.estado {
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
  background: var(--surface-hover);
  color: var(--text-2);
}

.estado.pendiente {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.estado.aprobada {
  background: var(--success-soft);
  color: var(--success-text);
}

.estado.rechazada {
  background: var(--danger-soft);
  color: var(--danger-text);
}

@media (max-width: 480px) {
  .fechas {
    grid-template-columns: 1fr;
  }
}
</style>
