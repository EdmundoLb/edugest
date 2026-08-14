<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatearDias } from '@/lib/dias'
import Spinner from '@/components/Spinner.vue'
import EmptyState from '@/components/EmptyState.vue'

const router = useRouter()
const { state } = useAuth()
const loading = ref(true)
const horarios = ref([])

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

const diasActivos = computed(() => new Set(horarios.value.map(h => h.dia_semana)).size)

const cursosAgrupados = computed(() => {
  const grupos = new Map()
  horarios.value.forEach(h => {
    if (!h.cursos) return
    const key = `${h.cursos.id}|${h.hora_inicio}|${h.hora_fin}|${h.turno}`
    if (!grupos.has(key)) {
      grupos.set(key, {
        curso: h.cursos,
        horaInicio: h.hora_inicio,
        horaFin: h.hora_fin,
        turno: h.turno,
        horarios: []
      })
    }
    grupos.get(key).horarios.push(h)
  })
  return Array.from(grupos.values()).sort((a, b) => a.curso.nombre.localeCompare(b.curso.nombre))
})

const cursosUnicos = computed(() => new Set(cursosAgrupados.value.map(g => g.curso.id)).size)

function irALlamarLista(grupo) {
  router.push({ path: '/LlamarLista', query: { curso: grupo.curso.id } })
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
        <Spinner size="large" />
        <p>Cargando cursos...</p>
      </div>

      <EmptyState v-else-if="horarios.length === 0" title="No tienes cursos asignados">
        <template #icon>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
            <path d="M4 19.5A2.5 2.5 0 016.5 17H20" />
            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" />
          </svg>
        </template>
      </EmptyState>

      <div v-else class="cursos-content">
        <section class="cursos-resumen">
          <h2>Resumen</h2>
          <div class="resumen-stats">
            <div class="resumen-stat">
              <span class="stat-value">{{ cursosUnicos }}</span>
              <span class="stat-label">Cursos</span>
            </div>
            <div class="resumen-stat">
              <span class="stat-value">{{ horarios.length }}</span>
              <span class="stat-label">Horarios</span>
            </div>
            <div class="resumen-stat">
              <span class="stat-value">{{ diasActivos }}</span>
              <span class="stat-label">Días activos</span>
            </div>
          </div>
        </section>

        <section class="cursos-lista">
          <h2>Mis Cursos</h2>

          <div class="cursos-grid">
            <div v-for="grupo in cursosAgrupados" :key="`${grupo.curso.id}-${grupo.horaInicio}`" class="curso-card">
              <div class="horario-curso">
                <span class="curso-nombre">{{ grupo.curso.nombre }}</span>
                <span class="horario-turno">{{ grupo.turno }}</span>
              </div>
              <p v-if="grupo.curso.descripcion" class="curso-descripcion">{{ grupo.curso.descripcion }}</p>
              <div class="dias-chips">
                <span v-for="chip in formatearDias(grupo.horarios.map(h => h.dia_semana))" :key="chip" class="dia-chip">
                  {{ chip }}
                </span>
              </div>
              <div class="horario-tiempo">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="time-icon">
                  <circle cx="12" cy="12" r="10" />
                  <polyline points="12 6 12 12 16 14" />
                </svg>
                <span>{{ grupo.horaInicio }} - {{ grupo.horaFin }}</span>
              </div>
              <button
                v-if="state.perfil?.rol === 'docente'"
                class="btn-llamar"
                @click="irALlamarLista(grupo)"
              >
                Llamar Lista
              </button>
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

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}

.loading-state :deep(.spinner) {
  margin: 0 auto 1rem;
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

.cursos-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.curso-card {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1.25rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
}

.curso-descripcion {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
  margin: -0.5rem 0 0;
}

.dias-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.dia-chip {
  padding: 0.25rem 0.5rem;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 6px;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.7);
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

  .cursos-grid {
    grid-template-columns: 1fr;
  }
}
</style>