<script setup>
// Bandeja de avisos y pedidos de justificación que mandan las familias.
// Admin ve y resuelve todos; un docente ve los de sus alumnos y resuelve los
// de sus cursos (resolver_solicitud vuelve a validarlo en la base).
import { ref, computed, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { supabase } from '@/lib/supabase'
import {
  solicitudesPendientes,
  solicitudesResueltas,
  resolverSolicitud,
  urlAdjunto,
  esEsquemaFaltante,
} from '@/lib/api/solicitudes'
import { ESTADOS_SOLICITUD, puedeResolver, describirRango } from '@/lib/solicitudes'
import { formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const { state, esAdmin, esDocente } = useAuth()
const toast = useToast()

const pestana = ref('pendientes')
const pendientes = ref([])
const resueltas = ref(null) // null = todavía no se cargaron
const cursosPropios = ref([])
const respuestas = ref({}) // solicitudId -> texto
const cargando = ref(true)
const faltaMigracion = ref(false)
const resolviendo = ref(null)

const lista = computed(() =>
  pestana.value === 'pendientes' ? pendientes.value : (resueltas.value ?? []),
)

onMounted(async () => {
  try {
    const [p] = await Promise.all([solicitudesPendientes(), cargarCursosPropios()])
    pendientes.value = p
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudieron cargar las solicitudes', e)
  } finally {
    cargando.value = false
  }
})

async function cargarCursosPropios() {
  if (!esDocente() || !state.datosUsuario) return
  const { data, error } = await supabase
    .from('horarios')
    .select('curso_id')
    .eq('profesor_id', state.datosUsuario.id)
  if (error) throw error
  cursosPropios.value = [...new Set(data.map((h) => h.curso_id))]
}

async function verResueltas() {
  pestana.value = 'resueltas'
  if (resueltas.value) return
  try {
    resueltas.value = await solicitudesResueltas()
  } catch (e) {
    resueltas.value = []
    toast.error('No se pudieron cargar las solicitudes resueltas', e)
  }
}

function resoluble(s) {
  return puedeResolver(s, { esAdmin: esAdmin(), cursosPropios: cursosPropios.value })
}

async function resolver(s, aprobar) {
  const respuesta = respuestas.value[s.id] ?? ''
  if (!aprobar && !respuesta.trim()) {
    toast.error('Para rechazar, escribí el motivo en la respuesta a la familia')
    return
  }
  resolviendo.value = s.id
  try {
    await resolverSolicitud(s.id, { aprobar, respuesta })
    pendientes.value = pendientes.value.filter((x) => x.id !== s.id)
    resueltas.value = null
    toast.exito(
      aprobar
        ? `Aprobada: las faltas de ${s.alumnos?.nombre ?? 'el alumno'} quedan justificadas`
        : 'Solicitud rechazada',
    )
  } catch (e) {
    toast.error('No se pudo resolver la solicitud', e)
  } finally {
    resolviendo.value = null
  }
}

async function verAdjunto(s) {
  try {
    window.open(await urlAdjunto(s.adjunto_path), '_blank', 'noopener')
  } catch (e) {
    toast.error('No se pudo abrir el certificado', e)
  }
}

function fechaCorta(timestamp) {
  return formatearFecha(fechaLocalDeTimestamp(timestamp), { day: 'numeric', month: 'short' })
}
</script>

<template>
  <div class="solicitudes-page">
    <PageHeader
      titulo="Avisos de las familias"
      subtitulo="Ausencias avisadas y pedidos de justificación"
    />

    <div class="contenedor">
      <div class="pestanas" role="tablist">
        <button
          type="button"
          role="tab"
          :aria-selected="pestana === 'pendientes'"
          :class="['pestana', { activa: pestana === 'pendientes' }]"
          @click="pestana = 'pendientes'"
        >
          Pendientes <span class="contador">{{ pendientes.length }}</span>
        </button>
        <button
          type="button"
          role="tab"
          :aria-selected="pestana === 'resueltas'"
          :class="['pestana', { activa: pestana === 'resueltas' }]"
          @click="verResueltas"
        >
          Resueltas
        </button>
      </div>

      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="faltaMigracion"
        title="Función no habilitada"
        hint="Falta aplicar la migración 0014_solicitudes_justificacion.sql."
      />

      <div v-else-if="pestana === 'resueltas' && resueltas === null" class="cargando">
        <AppSpinner size="medium" />
      </div>

      <EmptyState
        v-else-if="!lista.length"
        :title="pestana === 'pendientes' ? 'No hay avisos pendientes' : 'Sin solicitudes resueltas'"
        hint="Cuando una familia avise una ausencia o mande un certificado, aparece acá."
      />

      <ul v-else class="lista">
        <li v-for="s in lista" :key="s.id" class="tarjeta item">
          <div class="item-cabecera">
            <div>
              <router-link :to="`/Estudiantes/${s.alumno_id}`" class="alumno">
                {{ s.alumnos?.nombre }} {{ s.alumnos?.apellido }}
              </router-link>
              <span class="texto-muted chico">
                · {{ s.cursos?.nombre ?? 'Todos sus cursos' }} · enviado el
                {{ fechaCorta(s.created_at) }}
              </span>
            </div>
            <span :class="['estado', s.estado]">{{ ESTADOS_SOLICITUD[s.estado] }}</span>
          </div>

          <p class="rango">{{ describirRango(s.desde, s.hasta) }}</p>
          <p class="motivo">{{ s.motivo }}</p>
          <p v-if="s.respuesta && s.estado !== 'pendiente'" class="respuesta texto-muted">
            Respuesta: {{ s.respuesta }}
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
            <span v-else-if="s.estado === 'pendiente'" class="texto-muted chico">
              Sin certificado adjunto
            </span>
          </div>

          <form v-if="resoluble(s)" class="resolver" @submit.prevent>
            <input
              v-model="respuestas[s.id]"
              class="input"
              type="text"
              maxlength="300"
              placeholder="Respuesta a la familia (obligatoria para rechazar)"
              :aria-label="`Respuesta para la familia de ${s.alumnos?.nombre ?? 'el alumno'}`"
            />
            <button
              type="button"
              class="btn btn-peligro btn-chico"
              :disabled="resolviendo === s.id"
              @click="resolver(s, false)"
            >
              Rechazar
            </button>
            <button
              type="button"
              class="btn btn-primario btn-chico"
              :disabled="resolviendo === s.id"
              @click="resolver(s, true)"
            >
              Aprobar y justificar
            </button>
          </form>
          <p v-else-if="s.estado === 'pendiente'" class="texto-muted chico">
            Esta solicitud vale para todos sus cursos o para un curso que no dictás: la resuelve
            administración.
          </p>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.solicitudes-page {
  min-height: calc(100vh - var(--navbar-height));
}

.pestanas {
  display: flex;
  gap: 0.25rem;
  margin-bottom: 1.25rem;
  border-bottom: 1px solid var(--border);
}

.pestana {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.625rem 1rem;
  border: none;
  border-bottom: 2px solid transparent;
  background: transparent;
  color: var(--text-muted);
  font-weight: 600;
  cursor: pointer;
}

.pestana.activa {
  color: var(--primary-text);
  border-bottom-color: var(--primary);
}

.contador {
  padding: 0 0.4375rem;
  border-radius: 999px;
  background: var(--primary-soft-strong);
  color: var(--primary-text);
  font-size: 0.75rem;
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.item {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1rem 1.25rem;
}

.item-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 0.75rem;
}

.alumno {
  font-weight: 700;
  color: var(--text);
  text-decoration: none;
}

.alumno:hover {
  color: var(--primary-text);
  text-decoration: underline;
}

.chico {
  font-size: 0.8125rem;
}

.rango {
  font-weight: 600;
  font-size: 0.9375rem;
}

.motivo,
.respuesta {
  font-size: 0.875rem;
}

.item-acciones {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.item-acciones:empty {
  display: none;
}

.resolver {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  padding-top: 0.5rem;
  border-top: 1px solid var(--border);
}

.resolver .input {
  flex: 1;
  min-width: 0;
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

@media (max-width: 640px) {
  .resolver {
    flex-wrap: wrap;
  }

  .resolver .input {
    flex-basis: 100%;
  }
}
</style>
