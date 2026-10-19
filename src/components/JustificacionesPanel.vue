<script setup>
// Justificaciones de faltas por rango (ej. certificado médico). Al cargar una,
// la base pasa a 'justificado' las faltas de ese rango, incluidas las que se
// tomen después; al anularla, vuelven a 'ausente' (triggers de 0012).
import { ref, computed, watch } from 'vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import {
  listarJustificaciones,
  crearJustificacion,
  anularJustificacion,
  esEsquemaFaltante,
} from '@/lib/api/justificaciones'
import { hoyLocal, formatearFecha } from '@/lib/fecha'

const props = defineProps({
  alumnoId: { type: String, required: true },
  // Cursos que se ofrecen en el formulario: [{ cursoId, cursoNombre }]
  cursos: { type: Array, default: () => [] },
  editable: { type: Boolean, default: false },
})

const emit = defineEmits(['cambio'])

const { state, esAdmin } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const lista = ref([])
const cargando = ref(false)
const faltaMigracion = ref(false)
const mostrarFormulario = ref(false)
const guardando = ref(false)

const vacio = () => ({ cursoId: '', desde: hoyLocal(), hasta: hoyLocal(), motivo: '' })
const form = ref(vacio())

// Un docente solo puede justificar en un curso que dicta (RLS), no en "todos".
const puedeTodosLosCursos = computed(() => esAdmin())
const formularioValido = computed(
  () =>
    form.value.desde &&
    form.value.hasta &&
    form.value.hasta >= form.value.desde &&
    form.value.motivo.trim() &&
    (puedeTodosLosCursos.value || form.value.cursoId),
)

watch(() => props.alumnoId, cargar, { immediate: true })

async function cargar() {
  cargando.value = true
  faltaMigracion.value = false
  try {
    lista.value = await listarJustificaciones(props.alumnoId)
  } catch (e) {
    if (esEsquemaFaltante(e)) {
      faltaMigracion.value = true
      console.error(e)
    } else {
      toast.error('No se pudieron cargar las justificaciones', e)
    }
  } finally {
    cargando.value = false
  }
}

function abrirFormulario() {
  form.value = vacio()
  if (!puedeTodosLosCursos.value && props.cursos.length === 1) {
    form.value.cursoId = props.cursos[0].cursoId
  }
  mostrarFormulario.value = true
}

async function guardar() {
  if (!formularioValido.value) return
  guardando.value = true
  try {
    await crearJustificacion({
      alumnoId: props.alumnoId,
      ...form.value,
      creadoPor: state.user?.id,
    })
    toast.exito('Justificación cargada. Las faltas de ese período quedaron justificadas.')
    mostrarFormulario.value = false
    await cargar()
    emit('cambio')
  } catch (e) {
    toast.error('No se pudo guardar la justificación', e)
  } finally {
    guardando.value = false
  }
}

function puedeAnular(j) {
  return props.editable && (esAdmin() || j.creado_por === state.user?.id)
}

async function anular(j) {
  const ok = await confirmar({
    titulo: '¿Anular esta justificación?',
    mensaje: `Las faltas del ${rango(j)} que justificó vuelven a quedar como ausencias.`,
    aceptar: 'Anular',
    peligro: true,
  })
  if (!ok) return
  try {
    await anularJustificacion(j.id)
    toast.exito('Justificación anulada')
    await cargar()
    emit('cambio')
  } catch (e) {
    toast.error('No se pudo anular la justificación', e)
  }
}

function rango(j) {
  const opciones = { day: 'numeric', month: 'short', year: 'numeric' }
  return j.desde === j.hasta
    ? formatearFecha(j.desde, opciones)
    : `${formatearFecha(j.desde, opciones)} al ${formatearFecha(j.hasta, opciones)}`
}
</script>

<template>
  <section class="tarjeta panel" aria-label="Justificaciones">
    <div class="panel-cabecera">
      <div>
        <h2>Justificaciones</h2>
        <p class="texto-muted">Certificados o permisos que justifican faltas en un período.</p>
      </div>
      <button
        v-if="editable && !faltaMigracion && !mostrarFormulario"
        type="button"
        class="btn btn-primario btn-chico no-print"
        @click="abrirFormulario"
      >
        Nueva justificación
      </button>
    </div>

    <p v-if="faltaMigracion" class="aviso">
      Falta aplicar <code>supabase/migrations/0012_justificaciones_y_bajas.sql</code> en el SQL
      Editor de Supabase para usar las justificaciones.
    </p>

    <form v-else-if="mostrarFormulario" class="formulario" @submit.prevent="guardar">
      <div class="campo">
        <label for="just-curso">Curso</label>
        <select id="just-curso" v-model="form.cursoId" class="input">
          <option v-if="puedeTodosLosCursos" value="">Todos sus cursos</option>
          <option v-else value="" disabled>Elegí un curso</option>
          <option v-for="c in cursos" :key="c.cursoId" :value="c.cursoId">
            {{ c.cursoNombre }}
          </option>
        </select>
      </div>
      <div class="campo">
        <label for="just-desde">Desde</label>
        <input id="just-desde" v-model="form.desde" class="input" type="date" required />
      </div>
      <div class="campo">
        <label for="just-hasta">Hasta</label>
        <input
          id="just-hasta"
          v-model="form.hasta"
          class="input"
          type="date"
          :min="form.desde"
          required
        />
      </div>
      <div class="campo campo-ancho">
        <label for="just-motivo">Motivo</label>
        <input
          id="just-motivo"
          v-model="form.motivo"
          class="input"
          type="text"
          maxlength="200"
          placeholder="Ej: certificado médico, viaje familiar, competencia deportiva"
          required
        />
      </div>
      <div class="formulario-acciones">
        <button
          type="button"
          class="btn btn-secundario btn-chico"
          :disabled="guardando"
          @click="mostrarFormulario = false"
        >
          Cancelar
        </button>
        <button
          type="submit"
          class="btn btn-primario btn-chico"
          :disabled="!formularioValido || guardando"
        >
          {{ guardando ? 'Guardando...' : 'Guardar justificación' }}
        </button>
      </div>
    </form>

    <p v-if="!faltaMigracion && !cargando && !lista.length" class="texto-muted vacio">
      No hay justificaciones cargadas.
    </p>

    <ul v-else-if="!faltaMigracion" class="lista">
      <li v-for="j in lista" :key="j.id" class="item">
        <div class="item-info">
          <strong>{{ rango(j) }}</strong>
          <span class="texto-muted">{{ j.cursos?.nombre ?? 'Todos sus cursos' }}</span>
          <span class="motivo">{{ j.motivo }}</span>
        </div>
        <button
          v-if="puedeAnular(j)"
          type="button"
          class="btn btn-peligro btn-chico no-print"
          @click="anular(j)"
        >
          Anular
        </button>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.panel {
  padding: 1.25rem;
}

.panel-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 1rem;
  flex-wrap: wrap;
  margin-bottom: 1rem;
}

h2 {
  font-size: 1.125rem;
  font-weight: 700;
}

.panel-cabecera .texto-muted {
  font-size: 0.8125rem;
}

.aviso {
  padding: 0.875rem 1rem;
  border-radius: var(--radius);
  border: 1px solid var(--warning-border);
  background: var(--warning-soft);
  color: var(--text-2);
  font-size: 0.875rem;
}

.formulario {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 0.75rem;
  padding: 1rem;
  margin-bottom: 1rem;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--surface-2);
}

.campo-ancho,
.formulario-acciones {
  grid-column: 1 / -1;
}

.formulario-acciones {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

.vacio {
  font-size: 0.875rem;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 0.875rem;
  border: 1px solid var(--border);
  border-left: 3px solid var(--warning);
  border-radius: var(--radius-sm);
}

.item-info {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  font-size: 0.875rem;
  min-width: 0;
}

.item-info .texto-muted {
  font-size: 0.8125rem;
}

.motivo {
  color: var(--text-2);
}
</style>
