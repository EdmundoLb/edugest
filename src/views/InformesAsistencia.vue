<script setup>
import { useToast } from '@/composables/useToast'
import PageHeader from '@/components/PageHeader.vue'
import { ref, computed, onMounted } from 'vue'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { formatearFecha } from '@/lib/fecha'
import {
  linkWhatsapp,
  armarMensajeAsistencia,
  linkWhatsappGrupo,
  armarMensajeGrupoAsistencia,
} from '@/lib/whatsapp'
import AppPagination from '@/components/AppPagination.vue'
import EmptyState from '@/components/EmptyState.vue'
import AppSpinner from '@/components/AppSpinner.vue'

const toast = useToast()

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
      .select(
        `
        id,
        fecha,
        estado,
        creado_at,
        horario_id,
        horarios ( dia_semana, cursos ( nombre ) ),
        profesores ( nombre, apellido )
      `,
      )
      .order('creado_at', { ascending: false })

    if (error) throw error
    informes.value = data || []
  } catch (e) {
    toast.error('No se pudieron cargar los informes', e)
  } finally {
    loading.value = false
  }
}

const informesFiltrados = computed(() => informes.value.filter((i) => i.estado === filtro.value))

const totalPages = computed(() => Math.max(1, Math.ceil(informesFiltrados.value.length / pageSize)))

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
    toast.error('No se pudo cargar el detalle del informe', e)
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
    }),
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
    }),
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
    toast.exito('Informe marcado como revisado')

    if (informeAbierto.value?.id === informe.id) {
      informeAbierto.value = null
      detalleAlumnos.value = []
    }
  } catch (e) {
    toast.error('No se pudo marcar como revisado', e)
  } finally {
    marcandoRevisado.value = false
  }
}
</script>

<template>
  <div class="informes-page">
    <PageHeader
      titulo="Informes de asistencia"
      subtitulo="Informes remitidos por los docentes para avisar a las familias"
      volver="/admin"
    />

    <div class="page-content">
      <div v-if="loading" class="loading-state">
        <AppSpinner size="large" />
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
          :title="
            filtro === 'pendiente'
              ? 'No hay informes pendientes'
              : 'Todavía no hay informes revisados'
          "
          hint="Los profesores remiten un informe después de tomar asistencia, desde Llamar Lista."
        />

        <div v-else class="informes-list">
          <div v-for="informe in informesPagina" :key="informe.id" class="informe-card">
            <button class="informe-resumen" @click="toggleExpandir(informe)">
              <div class="informe-info">
                <span class="informe-curso">{{
                  informe.horarios?.cursos?.nombre || 'Sin curso'
                }}</span>
                <span class="informe-meta">
                  {{
                    formatearFecha(informe.fecha, {
                      weekday: 'long',
                      day: 'numeric',
                      month: 'long',
                    })
                  }}
                  · {{ informe.profesores?.nombre }} {{ informe.profesores?.apellido }}
                </span>
              </div>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                class="chevron"
                :class="{ open: informeAbierto?.id === informe.id }"
              >
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>

            <div v-if="informeAbierto?.id === informe.id" class="informe-detalle">
              <div v-if="cargandoDetalle" class="loading-detalle">
                <AppSpinner size="small" />
                <span>Cargando alumnos...</span>
              </div>

              <div v-else>
                <a
                  v-if="
                    ausentesYJustificados.ausentes.length ||
                    ausentesYJustificados.justificados.length
                  "
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
                      <span v-if="alumno.observacion" class="detalle-observacion">{{
                        alumno.observacion
                      }}</span>
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

        <AppPagination
          :current-page="currentPage"
          :total-pages="totalPages"
          @page-change="currentPage = $event"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.informes-page {
  min-height: calc(100vh - var(--navbar-height));
}

.page-content {
  padding: 2rem;
  max-width: 760px;
  margin: 0 auto;
}

.loading-state {
  text-align: center;
  padding: 4rem 2rem;
  color: var(--text-muted);
}

.filtro-tabs {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.filtro-tab {
  padding: 0.5rem 1rem;
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  background: var(--surface);
  color: var(--text-2);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.filtro-tab:hover {
  color: var(--text);
}

.filtro-tab.active {
  background: var(--primary-soft-strong);
  border-color: var(--primary-border);
  color: var(--text);
}

.informes-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.informe-card {
  background: var(--surface);
  border: 1px solid var(--border);
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
  color: var(--text);
}

.informe-meta {
  font-size: 0.8125rem;
  color: var(--text-muted);
  text-transform: capitalize;
}

.chevron {
  width: 18px;
  height: 18px;
  color: var(--text-subtle);
  flex-shrink: 0;
  transition: transform 0.2s;
}

.chevron.open {
  transform: rotate(180deg);
}

.informe-detalle {
  padding: 0 1.25rem 1.25rem;
  border-top: 1px solid var(--border);
}

.loading-detalle {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1.25rem 0;
  color: var(--text-muted);
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
  background: var(--surface);
  border: 1px solid var(--border);
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
  color: var(--text);
}

.detalle-status {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
}

.detalle-status.presente {
  color: var(--success-text);
  background: var(--success-soft);
}

.detalle-status.ausente {
  color: var(--danger-text);
  background: var(--danger-soft);
}

.detalle-status.justificado {
  color: var(--warning-text);
  background: var(--warning-soft);
}

.detalle-observacion {
  font-size: 0.75rem;
  color: var(--text-subtle);
}

.btn-whatsapp {
  padding: 0.5rem 0.875rem;
  border-radius: 6px;
  background: var(--whatsapp-soft);
  border: 1px solid var(--success-border);
  color: var(--success-text);
  font-size: 0.8125rem;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.2s;
  white-space: nowrap;
}

.btn-whatsapp:hover {
  background: var(--whatsapp-soft);
}

.sin-telefono {
  font-size: 0.8125rem;
  color: var(--text-subtle);
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
  background: var(--whatsapp-soft);
  border: 1px solid var(--success-border);
  color: var(--success-text);
  font-size: 0.875rem;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.2s;
}

.btn-whatsapp-grupo:hover {
  background: var(--whatsapp-soft);
}

.sin-ausencias {
  font-size: 0.8125rem;
  color: var(--text-subtle);
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
  background: var(--primary);
  color: var(--on-primary);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-revisado:hover:not(:disabled) {
  background: var(--primary-hover);
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
