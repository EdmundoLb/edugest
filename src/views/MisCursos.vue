<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'

const router = useRouter()
const { state } = useAuth()
const loading = ref(true)
const horarios = ref([])

const diasOrden = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']

onMounted(async () => {
  await cargarHorarios()
})

async function cargarHorarios() {
  loading.value = true
  try {
    const columnas = `
      id,
      dia_semana,
      hora_inicio,
      hora_fin,
      turno,
      cursos (id, nombre, descripcion)
    `

    if (state.perfil?.rol === 'admin') {
      const { data, error } = await supabase
        .from('horarios')
        .select(columnas)
        .order('dia_semana')

      if (!error) {
        horarios.value = data || []
      }
      return
    }

    const { data: profesor } = await supabase
      .from('profesores')
      .select('id')
      .eq('perfil_id', state.perfil?.id)
      .single()

    if (profesor) {
      const { data, error } = await supabase
        .from('horarios')
        .select(columnas)
        .eq('profesor_id', profesor.id)
        .order('dia_semana')

      if (!error) {
        horarios.value = data || []
      }
    }
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const horariosPorDia = computed(() => {
  const agrupado = {}
  diasOrden.forEach(dia => {
    agrupado[dia] = horarios.value.filter(h => h.dia_semana === dia)
  })
  return agrupado
})

const cursosUnicos = computed(() => {
  const cursos = new Map()
  horarios.value.forEach(h => {
    if (h.cursos) {
      cursos.set(h.cursos.id, h.cursos)
    }
  })
  return Array.from(cursos.values())
})

function irALlamarLista(horarioId) {
  router.push({ path: '/LlamarLista', query: { horario: horarioId } })
}
</script>

<template>
  <div class="cursos-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/ProfesorDashboard')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="back-icon">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
        </button>
        <h1>Mis Cursos</h1>
      </div>
      <router-link to="/ProfesorDashboard" class="btn-volver">
        ← Volver al panel
      </router-link>
    </header>

    <main class="page-content">
      <div v-if="loading" class="loading-state">
        <div class="spinner" />
        <p>Cargando cursos...</p>
      </div>

      <div v-else-if="horarios.length === 0" class="empty-state">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="empty-icon">
          <path d="M4 19.5A2.5 2.5 0 016.5 17H20" />
          <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" />
        </svg>
        <p>No tienes cursos asignados</p>
      </div>

      <div v-else class="cursos-content">
        <section class="cursos-resumen">
          <h2>Resumen</h2>
          <div class="resumen-stats">
            <div class="resumen-stat">
              <span class="stat-value">{{ cursosUnicos.length }}</span>
              <span class="stat-label">Cursos</span>
            </div>
            <div class="resumen-stat">
              <span class="stat-value">{{ horarios.length }}</span>
              <span class="stat-label">Horarios</span>
            </div>
            <div class="resumen-stat">
              <span class="stat-value">{{ Object.values(horariosPorDia).filter(d => d.length > 0).length }}</span>
              <span class="stat-label">Días activos</span>
            </div>
          </div>
        </section>

        <section class="cursos-lista">
          <h2>Horarios por Día</h2>

          <div v-for="dia in diasOrden" :key="dia" class="dia-section" v-show="horariosPorDia[dia].length > 0">
            <h3 class="dia-titulo">
              <span class="dia-num">{{ diasOrden.indexOf(dia) + 1 }}</span>
              {{ dia }}
            </h3>

            <div class="horarios-grid">
              <div v-for="horario in horariosPorDia[dia]" :key="horario.id" class="horario-card">
                <div class="horario-curso">
                  <span class="curso-nombre">{{ horario.cursos?.nombre || 'Curso' }}</span>
                  <span class="horario-turno">{{ horario.turno }}</span>
                </div>
                <div class="horario-tiempo">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="time-icon">
                    <circle cx="12" cy="12" r="10" />
                    <polyline points="12 6 12 12 16 14" />
                  </svg>
                  <span>{{ horario.hora_inicio }} - {{ horario.hora_fin }}</span>
                </div>
                <button
                  v-if="state.perfil?.rol === 'docente'"
                  class="btn-llamar"
                  @click="irALlamarLista(horario.id, horario.cursos?.nombre)"
                >
                  Llamar Lista
                </button>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  </div>
</template>

<style scoped>
.cursos-page {
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

.header-left {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.page-header h1 {
  font-size: 1.25rem;
  font-weight: 600;
}

.btn-back {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.7);
  cursor: pointer;
  transition: all 0.2s;
}

.btn-back:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
}

.back-icon {
  width: 18px;
  height: 18px;
}

.btn-volver {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
  text-decoration: none;
  transition: color 0.2s;
}

.btn-volver:hover {
  color: #fff;
}

.page-content {
  padding: 2rem;
}

.loading-state,
.empty-state {
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

.empty-icon {
  width: 48px;
  height: 48px;
  margin: 0 auto 1rem;
  color: rgba(255, 255, 255, 0.2);
}

.cursos-content h2 {
  font-size: 1rem;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.8);
  margin-bottom: 1rem;
}

.cursos-resumen {
  margin-bottom: 2.5rem;
}

.resumen-stats {
  display: flex;
  gap: 1.5rem;
}

.resumen-stat {
  display: flex;
  flex-direction: column;
  padding: 1rem 1.5rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
}

.resumen-stat .stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #004aad;
}

.resumen-stat .stat-label {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
}

.dia-section {
  margin-bottom: 2rem;
}

.dia-titulo {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: 1rem;
}

.dia-num {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  background: #004aad;
  border-radius: 50%;
  font-size: 0.8125rem;
  font-weight: 700;
}

.horarios-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.horario-card {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1.25rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
}

.horario-curso {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.curso-nombre {
  font-size: 1rem;
  font-weight: 600;
  color: #fff;
}

.horario-turno {
  font-size: 0.75rem;
  color: #004aad;
  text-transform: uppercase;
  font-weight: 500;
}

.horario-tiempo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: rgba(255, 255, 255, 0.7);
}

.time-icon {
  width: 16px;
  height: 16px;
  color: rgba(255, 255, 255, 0.4);
}

.btn-llamar {
  padding: 0.625rem 1rem;
  border: none;
  border-radius: 8px;
  background: linear-gradient(135deg, #022451, #004aad);
  color: #fff;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
  margin-top: 0.5rem;
}

.btn-llamar:hover {
  box-shadow: 0 4px 16px rgba(0, 74, 173, 0.5);
  transform: translateY(-1px);
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }

  .page-content {
    padding: 1rem;
  }

  .resumen-stats {
    flex-direction: column;
    gap: 0.75rem;
  }

  .horarios-grid {
    grid-template-columns: 1fr;
  }
}
</style>