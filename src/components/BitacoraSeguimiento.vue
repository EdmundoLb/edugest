<script setup>
// Bitácora de seguimiento de un alumno (0018): qué se hizo con la familia,
// qué se acordó y cuándo revisar. Solo la ve el personal. El día de la
// revisión, la base le manda una notificación a quien la cargó.
import { ref, computed, watch, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import {
  listarSeguimientos,
  crearSeguimiento,
  eliminarSeguimiento,
  esEsquemaFaltante,
} from '@/lib/api/seguimiento'
import { TIPOS_SEGUIMIENTO } from '@/lib/seguimiento'
import { hoyLocal, sumarDias, formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const props = defineProps({
  alumnoId: { type: String, required: true },
})

const route = useRoute()
const { state, esAdmin } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const hoy = hoyLocal()
const lista = ref([])
const cargando = ref(false)
const faltaMigracion = ref(false)
const mostrarFormulario = ref(false)
const guardando = ref(false)

const vacio = () => ({
  tipo: 'llamada',
  descripcion: '',
  compromiso: '',
  proximaRevision: sumarDias(hoy, 7),
})
const form = ref(vacio())
const valido = computed(() => form.value.descripcion.trim().length >= 3)

watch(() => props.alumnoId, cargar, { immediate: true })

async function cargar() {
  cargando.value = true
  faltaMigracion.value = false
  try {
    lista.value = await listarSeguimientos(props.alumnoId)
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudo cargar el seguimiento', e)
  } finally {
    cargando.value = false
  }
  // Desde "Alumnos en riesgo" se llega con #seguimiento: bajar hasta acá.
  if (route.hash === '#seguimiento') {
    await nextTick()
    document.getElementById('seguimiento')?.scrollIntoView({ behavior: 'smooth' })
  }
}

function abrir() {
  form.value = vacio()
  mostrarFormulario.value = true
}

async function guardar() {
  if (!valido.value) return
  guardando.value = true
  try {
    await crearSeguimiento({ alumnoId: props.alumnoId, ...form.value })
    toast.exito('Seguimiento registrado')
    mostrarFormulario.value = false
    await cargar()
  } catch (e) {
    toast.error('No se pudo guardar el seguimiento', e)
  } finally {
    guardando.value = false
  }
}

async function eliminar(s) {
  const ok = await confirmar({
    titulo: '¿Eliminar este registro?',
    mensaje: 'Se borra de la bitácora del alumno.',
    aceptar: 'Eliminar',
    peligro: true,
  })
  if (!ok) return
  try {
    await eliminarSeguimiento(s.id)
    lista.value = lista.value.filter((x) => x.id !== s.id)
  } catch (e) {
    toast.error('No se pudo eliminar', e)
  }
}

function fechaCorta(fecha) {
  return formatearFecha(fecha, { day: 'numeric', month: 'short', year: 'numeric' })
}
</script>

<template>
  <section id="seguimiento" class="tarjeta bitacora" aria-label="Seguimiento">
    <div class="cabecera">
      <div>
        <h2>Seguimiento con la familia</h2>
        <p class="texto-muted chico">
          Registrá cada contacto, lo que se acordó y cuándo volver a revisar. Solo lo ve el
          personal.
        </p>
      </div>
      <button
        v-if="!faltaMigracion && !mostrarFormulario"
        type="button"
        class="btn btn-primario btn-chico"
        @click="abrir"
      >
        Registrar contacto
      </button>
    </div>

    <p v-if="faltaMigracion" class="aviso">
      Falta aplicar la migración <code>0018_seguimiento_y_entrevistas.sql</code>.
    </p>

    <form v-if="mostrarFormulario" class="formulario" @submit.prevent="guardar">
      <div class="fila">
        <div class="campo">
          <label for="seg-tipo">Tipo</label>
          <select id="seg-tipo" v-model="form.tipo" class="input">
            <option v-for="(texto, valor) in TIPOS_SEGUIMIENTO" :key="valor" :value="valor">
              {{ texto }}
            </option>
          </select>
        </div>
        <div class="campo">
          <label for="seg-revision">Volver a revisar el</label>
          <input
            id="seg-revision"
            v-model="form.proximaRevision"
            class="input"
            type="date"
            :min="hoy"
          />
        </div>
      </div>
      <div class="campo">
        <label for="seg-descripcion">Qué pasó</label>
        <textarea
          id="seg-descripcion"
          v-model="form.descripcion"
          class="input"
          rows="3"
          maxlength="2000"
          placeholder="Ej: Hablé con la madre. Está con un problema de salud y tiene turno el martes."
        />
      </div>
      <div class="campo">
        <label for="seg-compromiso">Compromiso (opcional)</label>
        <input
          id="seg-compromiso"
          v-model="form.compromiso"
          class="input"
          type="text"
          maxlength="300"
          placeholder="Ej: Trae el certificado médico el lunes."
        />
      </div>
      <div class="acciones">
        <button type="button" class="btn btn-secundario" @click="mostrarFormulario = false">
          Cancelar
        </button>
        <button type="submit" class="btn btn-primario" :disabled="!valido || guardando">
          {{ guardando ? 'Guardando...' : 'Guardar' }}
        </button>
      </div>
    </form>

    <p v-if="cargando" class="texto-muted chico">Cargando...</p>

    <ol v-else-if="lista.length" class="linea">
      <li v-for="s in lista" :key="s.id" class="registro">
        <div class="registro-cabecera">
          <span class="tipo">{{ TIPOS_SEGUIMIENTO[s.tipo] }}</span>
          <span class="texto-muted chico">
            {{ fechaCorta(fechaLocalDeTimestamp(s.created_at)) }} · {{ s.autor_nombre }}
          </span>
          <button
            v-if="esAdmin() || s.autor_id === state.user?.id"
            type="button"
            class="quitar"
            :aria-label="`Eliminar registro del ${fechaCorta(fechaLocalDeTimestamp(s.created_at))}`"
            @click="eliminar(s)"
          >
            ✕
          </button>
        </div>
        <p class="descripcion">{{ s.descripcion }}</p>
        <p v-if="s.compromiso" class="compromiso">
          <strong>Compromiso:</strong> {{ s.compromiso }}
        </p>
        <p
          v-if="s.proxima_revision"
          :class="['revision', { vencida: s.proxima_revision <= hoy && s === lista[0] }]"
        >
          Revisar el {{ fechaCorta(s.proxima_revision) }}
        </p>
      </li>
    </ol>

    <p v-else-if="!faltaMigracion" class="texto-muted chico">
      Todavía no se registró ningún contacto con la familia.
    </p>
  </section>
</template>

<style scoped>
.bitacora {
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

.fila {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0.75rem;
}

textarea.input {
  resize: vertical;
  font-family: inherit;
}

.acciones {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

.linea {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0;
  border-left: 2px solid var(--border);
  margin-left: 0.375rem;
}

.registro {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0 0 1rem 1rem;
}

.registro::before {
  content: '';
  position: absolute;
  left: -0.4375rem;
  top: 0.3125rem;
  width: 0.75rem;
  height: 0.75rem;
  border-radius: 50%;
  background: var(--primary);
  border: 2px solid var(--surface);
}

.registro-cabecera {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.tipo {
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  background: var(--primary-soft);
  color: var(--primary-text);
  font-size: 0.75rem;
  font-weight: 700;
}

.quitar {
  margin-left: auto;
  border: none;
  background: none;
  color: var(--text-muted);
  cursor: pointer;
}

.descripcion {
  white-space: pre-line;
  font-size: 0.875rem;
}

.compromiso,
.revision {
  font-size: 0.8125rem;
  color: var(--text-2);
}

.revision.vencida {
  color: var(--warning-text);
  font-weight: 600;
}
</style>
