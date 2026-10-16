<script setup>
import { useToast } from '@/composables/useToast'
import { porcentajeAsistencia } from '@/lib/api/reportes'
import { UMBRAL_PORCENTAJE, FALTAS_SEGUIDAS } from '@/lib/api/alertas'
import PageHeader from '@/components/PageHeader.vue'
import { ref, onMounted, computed } from 'vue'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { parseFechaLocal, formatearHora } from '@/lib/fecha'
import AppSpinner from '@/components/AppSpinner.vue'

const toast = useToast()

const { state } = useAuth()
const loading = ref(true)
const asistencia = ref([])
const cursos = ref([])

onMounted(async () => {
  await cargarAsistencia()
})

async function cargarAsistencia() {
  loading.value = true
  try {
    // Fila de alumnos del usuario logueado, ya cargada por el store de auth.
    const alumno = state.datosUsuario

    if (alumno) {
      const { data: asistenciaData, error } = await supabase
        .from('asistencia')
        .select(
          `
          id,
          fecha,
          estado,
          observacion,
          horarios (
            id,
            dia_semana,
            hora_inicio,
            hora_fin,
            cursos (id, nombre)
          )
        `,
        )
        .eq('alumno_id', alumno.id)
        .order('fecha', { ascending: false })

      if (!error && asistenciaData) {
        asistencia.value = asistenciaData

        const cursosMap = new Map()
        asistenciaData.forEach((a) => {
          if (a.horarios?.cursos) {
            cursosMap.set(a.horarios.cursos.id, a.horarios.cursos)
          }
        })
        cursos.value = Array.from(cursosMap.values())
      }
    }
  } catch (e) {
    toast.error('No se pudo cargar tu asistencia', e)
  } finally {
    loading.value = false
  }
}

const nombreAlumno = computed(() => {
  return state.datosUsuario
    ? `${state.datosUsuario.nombre} ${state.datosUsuario.apellido}`
    : state.user?.email || 'Alumno'
})

const estadisticas = computed(() => {
  const total = asistencia.value.length
  const presentes = asistencia.value.filter((a) => a.estado === 'presente').length
  const ausentes = asistencia.value.filter((a) => a.estado === 'ausente').length
  const justificados = asistencia.value.filter((a) => a.estado === 'justificado').length
  const base = total - justificados
  const porcentaje = base > 0 ? Math.round((presentes / base) * 100) : 0
  return { total, presentes, ausentes, justificados, porcentaje }
})

function resumenCurso(registros) {
  const t = { total: registros.length, presentes: 0, justificados: 0 }
  registros.forEach((r) => {
    if (r.estado === 'presente') t.presentes++
    if (r.estado === 'justificado') t.justificados++
  })
  // Faltas seguidas más recientes (los registros vienen de la fecha más nueva
  // a la más vieja).
  let seguidas = 0
  for (const r of registros) {
    if (r.estado !== 'ausente') break
    seguidas++
  }
  return { porcentaje: porcentajeAsistencia(t), seguidas }
}

// Cursos en los que conviene avisarle al estudiante.
const alertas = computed(() =>
  Object.values(asistenciaPorCurso.value)
    .map((d) => ({
      curso: d.curso.nombre,
      ...resumenCurso(d.registros),
      total: d.registros.length,
    }))
    .filter(
      (a) =>
        a.seguidas >= FALTAS_SEGUIDAS ||
        (a.total >= 3 && a.porcentaje !== null && a.porcentaje < UMBRAL_PORCENTAJE),
    ),
)

const asistenciaPorCurso = computed(() => {
  const agrupado = {}
  cursos.value.forEach((curso) => {
    agrupado[curso.id] = {
      curso: curso,
      registros: asistencia.value.filter((a) => a.horarios?.cursos?.id === curso.id),
    }
  })
  return agrupado
})
</script>

<template>
  <div class="asistencia-page">
    <PageHeader titulo="Mi asistencia" :subtitulo="nombreAlumno" />

    <div class="page-content">
      <div v-if="loading" class="loading-state">
        <AppSpinner size="large" />
        <p>Cargando asistencia...</p>
      </div>

      <div v-else class="asistencia-content">
        <div class="welcome-section">
          <h2>Hola, {{ nombreAlumno }}</h2>
          <p>Aquí puedes ver tu historial de asistencia</p>
        </div>

        <div class="stats-grid">
          <div class="stat-card">
            <span class="stat-value">{{ estadisticas.total }}</span>
            <span class="stat-label">Total clases</span>
          </div>
          <div class="stat-card presente">
            <span class="stat-value">{{ estadisticas.presentes }}</span>
            <span class="stat-label">Presente</span>
          </div>
          <div class="stat-card ausente">
            <span class="stat-value">{{ estadisticas.ausentes }}</span>
            <span class="stat-label">Ausente</span>
          </div>
          <div class="stat-card justificado">
            <span class="stat-value">{{ estadisticas.justificados }}</span>
            <span class="stat-label">Justificado</span>
          </div>
          <div class="stat-card porcentaje">
            <span class="stat-value">{{ estadisticas.porcentaje }}%</span>
            <span class="stat-label">Asistencia</span>
          </div>
        </div>

        <div v-if="alertas.length" class="alerta-estudiante" role="status">
          <strong>Atención con tu asistencia</strong>
          <ul>
            <li v-for="a in alertas" :key="a.curso">
              {{ a.curso }}:
              <template v-if="a.seguidas >= FALTAS_SEGUIDAS"
                >{{ a.seguidas }} faltas seguidas</template
              >
              <template
                v-if="
                  a.seguidas >= FALTAS_SEGUIDAS &&
                  a.porcentaje !== null &&
                  a.porcentaje < UMBRAL_PORCENTAJE
                "
              >
                y
              </template>
              <template v-if="a.porcentaje !== null && a.porcentaje < UMBRAL_PORCENTAJE">
                {{ a.porcentaje }}% de asistencia
              </template>
            </li>
          </ul>
          <span
            >Si tus faltas tienen justificación, avisale a tu docente o a la administración.</span
          >
        </div>

        <div v-if="asistencia.length === 0" class="empty-state">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            class="empty-icon"
          >
            <circle cx="12" cy="12" r="10" />
            <polyline points="12 6 12 12 16 14" />
          </svg>
          <p>No hay registros de asistencia</p>
        </div>

        <div v-else class="cursos-section">
          <h3>Asistencia por Curso</h3>

          <div v-for="(data, cursoId) in asistenciaPorCurso" :key="cursoId" class="curso-card">
            <div class="curso-header">
              <span class="curso-nombre">{{ data.curso.nombre }}</span>
              <span class="curso-stats">
                {{ data.registros.filter((r) => r.estado === 'presente').length }}/{{
                  data.registros.length
                }}
                presentes
                <strong
                  v-if="resumenCurso(data.registros).porcentaje !== null"
                  :class="[
                    'curso-pct',
                    { bajo: resumenCurso(data.registros).porcentaje < UMBRAL_PORCENTAJE },
                  ]"
                >
                  · {{ resumenCurso(data.registros).porcentaje }}%
                </strong>
              </span>
            </div>

            <div class="registros-list">
              <div
                v-for="registro in data.registros.slice(0, 10)"
                :key="registro.id"
                :class="['registro-item', registro.estado]"
              >
                <div class="registro-fecha">
                  <span class="fecha-dia">{{ parseFechaLocal(registro.fecha).getDate() }}</span>
                  <span class="fecha-mes">{{
                    parseFechaLocal(registro.fecha).toLocaleDateString('es-ES', { month: 'short' })
                  }}</span>
                </div>
                <div class="registro-info">
                  <span class="registro-curso">{{ registro.horarios?.cursos?.nombre }}</span>
                  <span class="registro-horario">
                    {{ registro.horarios?.dia_semana }}
                    {{ formatearHora(registro.horarios?.hora_inicio) }}
                  </span>
                </div>
                <div class="registro-estado">
                  <span v-if="registro.estado === 'presente'" class="estado-badge presente"
                    >Presente</span
                  >
                  <span
                    v-else-if="registro.estado === 'justificado'"
                    class="estado-badge justificado"
                    >Justificado</span
                  >
                  <span v-else class="estado-badge ausente">Ausente</span>
                </div>
                <div v-if="registro.observacion" class="registro-observacion">
                  {{ registro.observacion }}
                </div>
              </div>
            </div>

            <div v-if="data.registros.length > 10" class="ver-mas">
              Mostrando últimos 10 de {{ data.registros.length }} registros
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.asistencia-page {
  min-height: calc(100vh - var(--navbar-height));
}

.btn-logout {
  padding: 0.5rem 1rem;
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  background: var(--surface-2);
  color: var(--text-2);
  font-size: 0.8125rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.page-content {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--text-muted);
}

.welcome-section {
  margin-bottom: 1.5rem;
}

.welcome-section h2 {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.welcome-section p {
  font-size: 0.875rem;
  color: var(--text-muted);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
}

.stat-card .stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text);
}

.stat-card .stat-label {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.stat-card.presente .stat-value {
  color: var(--success-text);
}

.stat-card.ausente .stat-value {
  color: var(--danger-text);
}

.stat-card.justificado .stat-value {
  color: var(--warning-text);
}

.stat-card.porcentaje .stat-value {
  color: var(--primary-text);
}

.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--text-muted);
}

.empty-icon {
  width: 48px;
  height: 48px;
  margin: 0 auto 1rem;
  color: var(--text-subtle);
}

.cursos-section h3 {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text);
  margin-bottom: 1rem;
}

.curso-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 1.25rem;
  margin-bottom: 1rem;
}

.curso-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.75rem;
  border-bottom: 1px solid var(--border);
}

.curso-nombre {
  font-weight: 600;
  color: var(--text);
}

.curso-stats {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.registros-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.registro-item {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 1rem;
  align-items: center;
  padding: 0.75rem;
  background: var(--surface);
  border-radius: 8px;
  border-left: 3px solid transparent;
}

.registro-item.presente {
  border-left-color: var(--success);
}

.registro-item.ausente {
  border-left-color: var(--danger);
}

.registro-item.justificado {
  border-left-color: var(--warning);
}

.registro-fecha {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 40px;
}

.fecha-dia {
  font-size: 1.125rem;
  font-weight: 700;
  color: var(--text);
  line-height: 1;
}

.fecha-mes {
  font-size: 0.6875rem;
  color: var(--text-muted);
  text-transform: uppercase;
}

.registro-info {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.registro-curso {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text);
}

.registro-horario {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.registro-estado {
  justify-self: end;
}

.estado-badge {
  padding: 0.25rem 0.625rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.estado-badge.presente {
  background: var(--success-soft);
  color: var(--success-text);
}

.estado-badge.ausente {
  background: var(--danger-soft);
  color: var(--danger-text);
}

.estado-badge.justificado {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.registro-observacion {
  grid-column: 1 / -1;
  font-size: 0.75rem;
  color: var(--text-subtle);
  font-style: italic;
  padding-left: 0.5rem;
}

.ver-mas {
  text-align: center;
  font-size: 0.75rem;
  color: var(--text-subtle);
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--border);
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .page-content {
    padding: 1rem;
  }
}

.alerta-estudiante {
  margin-bottom: 1.5rem;
  padding: 1rem 1.25rem;
  border: 1px solid var(--warning-border);
  border-left: 4px solid var(--warning);
  border-radius: var(--radius);
  background: var(--warning-soft);
  color: var(--text);
  font-size: 0.875rem;
}

.alerta-estudiante ul {
  margin: 0.375rem 0 0.5rem 1.25rem;
}

.alerta-estudiante span {
  color: var(--text-2);
}

.curso-pct {
  color: var(--success-text);
}

.curso-pct.bajo {
  color: var(--danger-text);
}
</style>
