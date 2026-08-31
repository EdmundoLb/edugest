<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatearFecha } from '@/lib/fecha'
import {
  linkWhatsapp,
  armarMensajeAsistencia,
  linkWhatsappGrupo,
  armarMensajeGrupoAsistencia,
} from '@/lib/whatsapp'
import Pagination from '@/components/Pagination.vue'
import EmptyState from '@/components/EmptyState.vue'
import Spinner from '@/components/Spinner.vue'

const router = useRouter()
const { state } = useAuth()

const loading = ref(true)
const informes = ref([])
const filtro = ref('pendiente')
const currentPage = ref(1)
const pageSize = 10

const informeAbierto = ref(null)
const detalleAlumnos = ref([])
const cargandoDetalle = ref(false)
const marcandoRevisado = ref(false)

const ESTADO_LABEL = { presente: 'Presente', ausente: 'Ausente', justificado: 'Justificado' }

onMounted(async () => {
  await cargarInformes()
})

async function cargarInformes() {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('informes_asistencia')
      .select(`
        id,
        fecha,
        estado,
        creado_at,
        horario_id,
        horarios ( dia_semana, cursos ( nombre ) ),
        profesores ( nombre, apellido )
      `)
      .order('creado_at', { ascending: false })

    if (error) throw error
    informes.value = data || []
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
}

const informesFiltrados = computed(() =>
  informes.value.filter((i) => i.estado === filtro.value)
)

const totalPages = computed(() =>
  Math.max(1, Math.ceil(informesFiltrados.value.length / pageSize))
)

const informesPagina = computed(() => {
  const inicio = (currentPage.value - 1) * pageSize
  return informesFiltrados.value.slice(inicio, inicio + pageSize)
})

function cambiarFiltro(nuevoFiltro) {
  filtro.value = nuevoFiltro
  currentPage.value = 1
  informeAbierto.value = null
}

async function toggleExpandir(informe) {
  if (informeAbierto.value?.id === informe.id) {
    informeAbierto.value = null
    detalleAlumnos.value = []
    return
  }

  informeAbierto.value = informe
  cargandoDetalle.value = true
  detalleAlumnos.value = []

  try {
    const { data, error } = await supabase
      .from('asistencia')
      .select('estado, observacion, alumnos ( id, nombre, apellido, telefono_padre )')
      .eq('horario_id', informe.horario_id)
      .eq('fecha', informe.fecha)

    if (error) throw error

    detalleAlumnos.value = (data || [])
      .filter((a) => a.alumnos)
      .map((a) => ({ ...a.alumnos, estado: a.estado, observacion: a.observacion }))
      .sort((a, b) => a.apellido.localeCompare(b.apellido))
  } catch (e) {
    console.error(e)
  } finally {
    cargandoDetalle.value = false
  }
}

function waLink(alumno) {
  if (!informeAbierto.value) return null
  return linkWhatsapp(
    alumno.telefono_padre,
    armarMensajeAsistencia({
      alumno,
      curso: informeAbierto.value.horarios?.cursos?.nombre || 'el curso',
      fecha: informeAbierto.value.fecha,
      estado: alumno.estado,
      observacion: alumno.observacion,
    })
  )
}

const ausentesYJustificados = computed(() => ({
  ausentes: detalleAlumnos.value.filter((a) => a.estado === 'ausente'),
  justificados: detalleAlumnos.value.filter((a) => a.estado === 'justificado'),
}))

function linkGrupo() {
  if (!informeAbierto.value) return null
  return linkWhatsappGrupo(
    armarMensajeGrupoAsistencia({
      curso: informeAbierto.value.horarios?.cursos?.nombre || 'el curso',
      fecha: informeAbierto.value.fecha,
      ausentes: ausentesYJustificados.value.ausentes,
      justificados: ausentesYJustificados.value.justificados,
    })
  )
}

async function marcarRevisado(informe) {
  marcandoRevisado.value = true
  try {
    const { error } = await supabase
      .from('informes_asistencia')
      .update({
        estado: 'revisado',
        revisado_at: new Date().toISOString(),
        revisado_por: state.perfil?.id,
      })
      .eq('id', informe.id)

    if (error) throw error

    const local = informes.value.find((i) => i.id === informe.id)
    if (local) local.estado = 'revisado'

    if (informeAbierto.value?.id === informe.id) {
      informeAbierto.value = null
      detalleAlumnos.value = []
    }
  } catch (e) {
    console.error(e)
  } finally {
    marcandoRevisado.value = false
  }
}
</script>

<template>
  <div class="informes-page">
    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="router.push('/admin')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="back-icon">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
        </button>
        <h1>Informes de Asistencia</h1>
      </div>
      <router-link to="/admin" class="btn-volver">← Volver al panel</router-link>
    </header>

    <main class="page-content">
      <div v-if="loading" class="loading-state">
        <Spinner size="large" />
        <p>Cargando informes...</p>
      </div>

      <div v-else>
        <div class="filtro-tabs">
          <button
            class="filtro-tab"
            :class="{ active: filtro === 'pendiente' }"
            @click="cambiarFiltro('pendiente')"
          >
            Pendientes
          </button>
          <button
            class="filtro-tab"
            :class="{ active: filtro === 'revisado' }"
            @click="cambiarFiltro('revisado')"
          >
            Revisados
          </button>
        </div>

        <EmptyState
          v-if="informesFiltrados.length === 0"
          :title="filtro === 'pendiente' ? 'No hay informes pendientes' : 'Todavía no hay informes revisados'"
          hint="Los profesores remiten un informe después de tomar asistencia, desde Llamar Lista."
        />

        <div v-else class="informes-list">
          <div v-for="informe in informesPagina" :key="informe.id" class="informe-card">
            <button class="informe-resumen" @click="toggleExpandir(informe)">
              <div class="informe-info">
                <span class="informe-curso">{{ informe.horarios?.cursos?.nombre || 'Sin curso' }}</span>
                <span class="informe-meta">
                  {{ formatearFecha(informe.fecha, { weekday: 'long', day: 'numeric', month: 'long' }) }}
                  · {{ informe.profesores?.nombre }} {{ informe.profesores?.apellido }}
                </span>
              </div>
              <svg
                viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                class="chevron" :class="{ open: informeAbierto?.id === informe.id }"
              >
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>

            <div v-if="informeAbierto?.id === informe.id" class="informe-detalle">
              <div v-if="cargandoDetalle" class="loading-detalle">
                <Spinner size="small" />
                <span>Cargando alumnos...</span>
              </div>

              <div v-else>
                <a
                  v-if="ausentesYJustificados.ausentes.length || ausentesYJustificados.justificados.length"
                  :href="linkGrupo()"
                  target="_blank"
                  rel="noopener"
                  class="btn-whatsapp-grupo"
                >
                  Enviar reporte de ausentes/justificados al grupo
                </a>
                <p v-else class="sin-ausencias">
                  Sin ausentes ni justificados que reportar en esta fecha.
                </p>

                <div class="detalle-alumnos">
                <div v-for="alumno in detalleAlumnos" :key="alumno.id" class="detalle-alumno">
                  <div class="detalle-alumno-info">
                    <span class="detalle-nombre">{{ alumno.nombre }} {{ alumno.apellido }}</span>
                    <span :class="['detalle-status', alumno.estado]">
                      {{ ESTADO_LABEL[alumno.estado] }}
                    </span>
                    <span v-if="alumno.observacion" class="detalle-observacion">{{ alumno.observacion }}</span>
                  </div>

                  <a
                    v-if="waLink(alumno)"
                    :href="waLink(alumno)"
                    target="_blank"
                    rel="noopener"
                    class="btn-whatsapp"
                  >
                    Enviar por WhatsApp
                  </a>
                  <span v-else class="sin-telefono">Sin teléfono cargado</span>
                </div>
                </div>
              </div>

              <div v-if="informe.estado === 'pendiente'" class="informe-acciones">
                <button
                  class="btn-revisado"
                  @click="marcarRevisado(informe)"
                  :disabled="marcandoRevisado"
                >
                  {{ marcandoRevisado ? 'Guardando...' : 'Marcar como revisado' }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <Pagination
          :current-page="currentPage"
          :total-pages="totalPages"
          @page-change="currentPage = $event"
        />
      </div>
    </main>
  </div>
</template>

<style scoped>
.informes-page {
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
  max-width: 760px;
  margin: 0 auto;
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}

.filtro-tabs {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.filtro-tab {
  padding: 0.5rem 1rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.03);
  color: rgba(255, 255, 255, 0.6);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.filtro-tab:hover {
  color: #fff;
}

.filtro-tab.active {
  background: rgba(0, 74, 173, 0.2);
  border-color: rgba(0, 74, 173, 0.4);
  color: #fff;
}

.informes-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.informe-card {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  overflow: hidden;
}

.informe-resumen {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1.25rem;
  border: none;
  background: transparent;
  color: inherit;
  cursor: pointer;
  text-align: left;
  font-family: inherit;
}

.informe-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.informe-curso {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #fff;
}

.informe-meta {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
  text-transform: capitalize;
}

.chevron {
  width: 18px;
  height: 18px;
  color: rgba(255, 255, 255, 0.4);
  flex-shrink: 0;
  transition: transform 0.2s;
}

.chevron.open {
  transform: rotate(180deg);
}

.informe-detalle {
  padding: 0 1.25rem 1.25rem;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}

.loading-detalle {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1.25rem 0;
  color: rgba(255, 255, 255, 0.5);
  font-size: 0.875rem;
}

.detalle-alumnos {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-top: 1rem;
}

.detalle-alumno {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.5rem;
  padding: 0.625rem 0.875rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 8px;
}

.detalle-alumno-info {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.detalle-nombre {
  font-size: 0.875rem;
  color: #fff;
}

.detalle-status {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
}

.detalle-status.presente {
  color: #6ee7b7;
  background: rgba(16, 185, 129, 0.15);
}

.detalle-status.ausente {
  color: #fca5a5;
  background: rgba(239, 68, 68, 0.15);
}

.detalle-status.justificado {
  color: #fcd34d;
  background: rgba(234, 179, 8, 0.15);
}

.detalle-observacion {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.4);
}

.btn-whatsapp {
  padding: 0.5rem 0.875rem;
  border-radius: 6px;
  background: rgba(37, 211, 102, 0.15);
  border: 1px solid rgba(37, 211, 102, 0.4);
  color: #6ee7b7;
  font-size: 0.8125rem;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-whatsapp:hover {
  background: rgba(37, 211, 102, 0.25);
}

.sin-telefono {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.35);
  white-space: nowrap;
}

.btn-whatsapp-grupo {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  border-radius: 8px;
  background: rgba(37, 211, 102, 0.15);
  border: 1px solid rgba(37, 211, 102, 0.4);
  color: #6ee7b7;
  font-size: 0.875rem;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.2s;
}

.btn-whatsapp-grupo:hover {
  background: rgba(37, 211, 102, 0.25);
}

.sin-ausencias {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.4);
  margin-bottom: 1rem;
}

.informe-acciones {
  margin-top: 1.25rem;
  display: flex;
  justify-content: center;
}

.btn-revisado {
  padding: 0.625rem 1.25rem;
  border: none;
  border-radius: 8px;
  background: #004aad;
  color: #fff;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-revisado:hover:not(:disabled) {
  background: #003380;
}

.btn-revisado:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .page-content {
    padding: 1.25rem;
  }

  .detalle-alumno {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
