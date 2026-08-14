<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { parseFechaLocal } from '@/lib/fecha'

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
    const { data: alumno } = await supabase
      .from('alumnos')
      .select('id')
      .eq('perfil_id', state.perfil?.id)
      .single()

    if (alumno) {
      const { data: asistenciaData, error } = await supabase
        .from('asistencia')
        .select(`
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
        `)
        .eq('alumno_id', alumno.id)
        .order('fecha', { ascending: false })

      if (!error && asistenciaData) {
        asistencia.value = asistenciaData

        const cursosMap = new Map()
        asistenciaData.forEach(a => {
          if (a.horarios?.cursos) {
            cursosMap.set(a.horarios.cursos.id, a.horarios.cursos)
          }
        })
        cursos.value = Array.from(cursosMap.values())
      }
    }
  } catch (e) {
    console.error(e)
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
  const presentes = asistencia.value.filter(a => a.estado === 'presente').length
  const ausentes = asistencia.value.filter(a => a.estado === 'ausente').length
  const justificados = asistencia.value.filter(a => a.estado === 'justificado').length
  const base = total - justificados
  const porcentaje = base > 0 ? Math.round((presentes / base) * 100) : 0
  return { total, presentes, ausentes, justificados, porcentaje }
})

const asistenciaPorCurso = computed(() => {
  const agrupado = {}
  cursos.value.forEach(curso => {
    agrupado[curso.id] = {
      curso: curso,
      registros: asistencia.value.filter(a => a.horarios?.cursos?.id === curso.id)
    }
  })
  return agrupado
})
</script>

<template>
  <div class="asistencia-page">
    <header class="page-header">
      <div class="header-left">
        <h1>Mi Asistencia</h1>
      </div>
      <div class="header-right">
        <span class="user-name">{{ nombreAlumno }}</span>
      </div>
    </header>

    <main class="page-content">
      <div v-if="loading" class="loading-state">
        <div class="spinner" />
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

        <div v-if="asistencia.length === 0" class="empty-state">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-icon">
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
                {{ data.registros.filter(r => r.estado === 'presente').length }}/{{ data.registros.length }} presentes
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
                  <span class="fecha-mes">{{ parseFechaLocal(registro.fecha).toLocaleDateString('es-ES', { month: 'short' }) }}</span>
                </div>
                <div class="registro-info">
                  <span class="registro-curso">{{ registro.horarios?.cursos?.nombre }}</span>
                  <span class="registro-horario">
                    {{ registro.horarios?.dia_semana }} {{ registro.horarios?.hora_inicio }}
                  </span>
                </div>
                <div class="registro-estado">
                  <span v-if="registro.estado === 'presente'" class="estado-badge presente">Presente</span>
                  <span v-else-if="registro.estado === 'justificado'" class="estado-badge justificado">Justificado</span>
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
    </main>
  </div>
</template>

<style scoped>
.asistencia-page {
  position: fixed;
  inset: 0;
  background: #000000;
  color: #fff;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  overflow-y: auto;
  padding-top: 82px;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 2rem;
  background: #022451;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.page-header h1 {
  font-size: 1.25rem;
  font-weight: 600;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.user-name {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
}

.btn-logout {
  padding: 0.5rem 1rem;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.8125rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.page-content {
  padding: 2rem;
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}

.spinner {
  width: 28px;
  height: 28px;
  margin: 0 auto 1rem;
  border: 2px solid rgba(255, 255, 255, 0.15);
  border-top-color: #004aad;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
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
  color: rgba(255, 255, 255, 0.5);
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
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
}

.stat-card .stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #fff;
}

.stat-card .stat-label {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.5);
}

.stat-card.presente .stat-value {
  color: #6ee7b7;
}

.stat-card.ausente .stat-value {
  color: #fca5a5;
}

.stat-card.justificado .stat-value {
  color: #fcd34d;
}

.stat-card.porcentaje .stat-value {
  color: #004aad;
}

.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}

.empty-icon {
  width: 48px;
  height: 48px;
  margin: 0 auto 1rem;
  color: rgba(255, 255, 255, 0.2);
}

.cursos-section h3 {
  font-size: 1rem;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.8);
  margin-bottom: 1rem;
}

.curso-card {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
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
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.curso-nombre {
  font-weight: 600;
  color: #fff;
}

.curso-stats {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
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
  background: rgba(255, 255, 255, 0.02);
  border-radius: 8px;
  border-left: 3px solid transparent;
}

.registro-item.presente {
  border-left-color: #10b981;
}

.registro-item.ausente {
  border-left-color: #ef4444;
}

.registro-item.justificado {
  border-left-color: #eab308;
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
  color: #fff;
  line-height: 1;
}

.fecha-mes {
  font-size: 0.6875rem;
  color: rgba(255, 255, 255, 0.5);
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
  color: #fff;
}

.registro-horario {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.5);
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
  background: rgba(16, 185, 129, 0.15);
  color: #6ee7b7;
}

.estado-badge.ausente {
  background: rgba(239, 68, 68, 0.15);
  color: #fca5a5;
}

.estado-badge.justificado {
  background: rgba(234, 179, 8, 0.15);
  color: #fcd34d;
}

.registro-observacion {
  grid-column: 1 / -1;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.4);
  font-style: italic;
  padding-left: 0.5rem;
}

.ver-mas {
  text-align: center;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.4);
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }

  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .page-content {
    padding: 1rem;
  }
}
</style>