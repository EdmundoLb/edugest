<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { supabase } from '@/lib/supabase'
import { traerTodo } from '@/lib/paginar'
import { formatearFecha, hoyLocal, rangoDelMes } from '@/lib/fecha'
import { cursosDelUsuario } from '@/lib/api/cursos'
import { resumenPorFecha, porcentajeAsistencia, esFuncionFaltante } from '@/lib/api/reportes'
import { descargarCsv, nombreArchivo } from '@/lib/exportar'

const toast = useToast()
const { state, esAdmin, rutaInicio } = useAuth()

const loading = ref(true)
const filas = ref([]) // { curso_id, curso_nombre, fecha, total, presentes, ausentes, justificados }
const cursos = ref([])
const cursoId = ref('')

const hoy = hoyLocal()
const [anioActual, mesActual] = hoy.split('-').map(Number)
const desde = ref(rangoDelMes(anioActual, mesActual).desde)
const hasta = ref(hoy)

const PERIODOS = {
  'este-mes': () => ({ desde: rangoDelMes(anioActual, mesActual).desde, hasta: hoy }),
  'mes-anterior': () =>
    mesActual === 1 ? rangoDelMes(anioActual - 1, 12) : rangoDelMes(anioActual, mesActual - 1),
  'este-anio': () => ({ desde: `${anioActual}-01-01`, hasta: hoy }),
}

function elegirPeriodo(clave) {
  const r = PERIODOS[clave]()
  desde.value = r.desde
  hasta.value = r.hasta
}

onMounted(async () => {
  try {
    cursos.value = await cursosDelUsuario({
      esAdmin: esAdmin(),
      profesorId: state.datosUsuario?.id,
    })
  } catch (e) {
    toast.error('No se pudieron cargar los cursos', e)
  }
  await cargarReportes()
})

watch([desde, hasta, cursoId], () => {
  if (desde.value && hasta.value && desde.value <= hasta.value) cargarReportes()
})

// Si la migración 0008 todavía no se aplicó, se cae a traer las filas crudas
// y sumar en el navegador (más lento, pero funciona igual).
async function cargarSinFuncionSql() {
  const consulta = () => {
    let q = supabase
      .from('asistencia')
      .select('id, fecha, estado, horarios!inner (curso_id, cursos (id, nombre))')
      .gte('fecha', desde.value)
      .lte('fecha', hasta.value)
      .order('fecha', { ascending: false })
      .order('id')
    if (cursoId.value) q = q.eq('horarios.curso_id', cursoId.value)
    return q
  }
  const crudas = await traerTodo(consulta)
  const mapa = new Map()
  crudas.forEach((r) => {
    const curso = r.horarios?.cursos
    if (!curso) return
    const clave = `${curso.id}|${r.fecha}`
    if (!mapa.has(clave)) {
      mapa.set(clave, {
        curso_id: curso.id,
        curso_nombre: curso.nombre,
        fecha: r.fecha,
        total: 0,
        presentes: 0,
        ausentes: 0,
        justificados: 0,
      })
    }
    const f = mapa.get(clave)
    f.total++
    if (r.estado === 'presente') f.presentes++
    else if (r.estado === 'justificado') f.justificados++
    else f.ausentes++
  })
  return [...mapa.values()]
}

async function cargarReportes() {
  loading.value = true
  try {
    try {
      filas.value = await resumenPorFecha({
        desde: desde.value,
        hasta: hasta.value,
        cursoId: cursoId.value || null,
      })
    } catch (e) {
      if (!esFuncionFaltante(e)) throw e
      filas.value = await cargarSinFuncionSql()
    }
  } catch (e) {
    toast.error('No se pudieron cargar los reportes', e)
  } finally {
    loading.value = false
  }
}

const reportesAgrupados = computed(() => {
  const grupos = new Map()
  const ordenadas = [...filas.value].sort(
    (a, b) => a.curso_nombre.localeCompare(b.curso_nombre) || b.fecha.localeCompare(a.fecha),
  )
  ordenadas.forEach((r) => {
    if (!grupos.has(r.curso_id)) {
      grupos.set(r.curso_id, { cursoId: r.curso_id, cursoNombre: r.curso_nombre, fechas: {} })
    }
    grupos.get(r.curso_id).fechas[r.fecha] = {
      fecha: r.fecha,
      total: Number(r.total),
      presentes: Number(r.presentes),
      ausentes: Number(r.ausentes),
      justificados: Number(r.justificados),
    }
  })
  return [...grupos.values()]
})

const estadisticasGenerales = computed(() => {
  const t = { total: 0, presentes: 0, ausentes: 0, justificados: 0 }
  filas.value.forEach((r) => {
    t.total += Number(r.total)
    t.presentes += Number(r.presentes)
    t.ausentes += Number(r.ausentes)
    t.justificados += Number(r.justificados)
  })
  return { ...t, porcentaje: porcentajeAsistencia(t) ?? 0 }
})

function porcentajeFecha(f) {
  return porcentajeAsistencia(f) ?? 0
}

function getPorcentajeClass(fechaData) {
  const pct = porcentajeFecha(fechaData)
  if (pct >= 90) return 'excelente'
  if (pct >= 70) return 'bueno'
  if (pct >= 50) return 'regular'
  return 'critico'
}

function exportarCsv() {
  descargarCsv(nombreArchivo('resumen_asistencia', desde.value, hasta.value), [
    [`Centro Cultural Gymmart — Resumen de asistencia del ${desde.value} al ${hasta.value}`],
    [],
    ['Curso', 'Fecha', 'Presentes', 'Ausentes', 'Justificados', 'Total', '% Asistencia'],
    ...reportesAgrupados.value.flatMap((c) =>
      Object.values(c.fechas).map((f) => [
        c.cursoNombre,
        f.fecha,
        f.presentes,
        f.ausentes,
        f.justificados,
        f.total,
        porcentajeFecha(f),
      ]),
    ),
  ])
  toast.exito('Planilla descargada')
}
</script>

<template>
  <div class="reportes-page">
    <PageHeader
      titulo="Resumen por fecha"
      subtitulo="Totales de asistencia por curso y día"
      :volver="rutaInicio()"
    >
      <router-link to="/Reportes/institucional" class="btn btn-secundario">Resumen del mes</router-link>
      <router-link to="/Reportes/mensual" class="btn btn-secundario">Reporte mensual</router-link>
      <button type="button" class="btn btn-primario" :disabled="!filas.length" @click="exportarCsv">
        Descargar Excel
      </button>
    </PageHeader>

    <div class="page-content">
      <section class="filtros" aria-label="Filtros">
        <div class="campo">
          <label for="curso">Curso</label>
          <select id="curso" v-model="cursoId">
            <option value="">Todos mis cursos</option>
            <option v-for="c in cursos" :key="c.id" :value="c.id">{{ c.nombre }}</option>
          </select>
        </div>
        <div class="campo">
          <label for="desde">Desde</label>
          <input id="desde" v-model="desde" type="date" :max="hasta" />
        </div>
        <div class="campo">
          <label for="hasta">Hasta</label>
          <input id="hasta" v-model="hasta" type="date" :min="desde" />
        </div>
        <div class="periodos" role="group" aria-label="Períodos rápidos">
          <button type="button" @click="elegirPeriodo('este-mes')">Este mes</button>
          <button type="button" @click="elegirPeriodo('mes-anterior')">Mes anterior</button>
          <button type="button" @click="elegirPeriodo('este-anio')">Este año</button>
        </div>
      </section>

      <div v-if="loading" class="loading-state">
        <AppSpinner size="large" />
        <p>Cargando reportes...</p>
      </div>

      <div v-else class="reportes-content">
        <div class="stats-summary">
          <div class="stat-card">
            <span class="stat-value">{{ estadisticasGenerales.total }}</span>
            <span class="stat-label">Total registros</span>
          </div>
          <div class="stat-card presente">
            <span class="stat-value">{{ estadisticasGenerales.presentes }}</span>
            <span class="stat-label">Presentes</span>
          </div>
          <div class="stat-card ausente">
            <span class="stat-value">{{ estadisticasGenerales.ausentes }}</span>
            <span class="stat-label">Ausentes</span>
          </div>
          <div class="stat-card justificado">
            <span class="stat-value">{{ estadisticasGenerales.justificados }}</span>
            <span class="stat-label">Justificados</span>
          </div>
          <div class="stat-card porcentaje">
            <span class="stat-value">{{ estadisticasGenerales.porcentaje }}%</span>
            <span class="stat-label">Tasa asistencia</span>
          </div>
        </div>

        <div v-if="filas.length === 0" class="empty-state">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            class="empty-icon"
          >
            <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <line x1="16" y1="13" x2="8" y2="13" />
            <line x1="16" y1="17" x2="8" y2="17" />
          </svg>
          <p>No hay asistencia registrada en este período</p>
          <span class="empty-hint">Probá con otro rango de fechas o curso</span>
        </div>

        <div v-else class="reportes-list">
          <div v-for="curso in reportesAgrupados" :key="curso.cursoId" class="curso-report">
            <div class="curso-header">
              <h3>{{ curso.cursoNombre }}</h3>
              <span class="curso-total">
                {{ Object.values(curso.fechas).reduce((acc, f) => acc + f.total, 0) }} registros
              </span>
            </div>

            <div class="fechas-table">
              <div class="table-header">
                <span class="col-fecha">Fecha</span>
                <span class="col-presentes">Presentes</span>
                <span class="col-ausentes">Ausentes</span>
                <span class="col-justificados">Justificados</span>
                <span class="col-porcentaje">%</span>
              </div>

              <div v-for="(fechaData, fecha) in curso.fechas" :key="fecha" class="table-row">
                <span class="col-fecha">
                  {{ formatearFecha(fecha, { weekday: 'short', day: 'numeric', month: 'short' }) }}
                </span>
                <span class="col-presentes">{{ fechaData.presentes }}</span>
                <span class="col-ausentes">{{ fechaData.ausentes }}</span>
                <span class="col-justificados">{{ fechaData.justificados }}</span>
                <span class="col-porcentaje" :class="getPorcentajeClass(fechaData)">
                  {{ porcentajeFecha(fechaData) }}%
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.reportes-page {
  min-height: calc(100vh - var(--navbar-height));
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

.stats-summary {
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

.empty-hint {
  display: block;
  font-size: 0.8125rem;
  color: var(--text-subtle);
  margin-top: 0.5rem;
}

.reportes-list {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.curso-report {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  overflow: hidden;
}

.curso-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
}

.curso-header h3 {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text);
}

.curso-total {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.fechas-table {
  display: table;
  width: 100%;
}

.table-header {
  display: table-row;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.table-header > span {
  display: table-cell;
  padding: 0.75rem 1.25rem;
  border-bottom: 1px solid var(--border);
}

.table-row {
  display: table-row;
}

.table-row > span {
  display: table-cell;
  padding: 0.875rem 1.25rem;
  border-bottom: 1px solid var(--border);
  font-size: 0.875rem;
}

.table-row:last-child > span {
  border-bottom: none;
}

.col-fecha {
  color: var(--text);
}

.col-presentes {
  color: var(--success-text);
}

.col-ausentes {
  color: var(--danger-text);
}

.col-justificados {
  color: var(--warning-text);
}

.col-porcentaje {
  font-weight: 600;
}

.col-porcentaje.excelente {
  color: var(--success-text);
}

.col-porcentaje.bueno {
  color: var(--success-text);
}

.col-porcentaje.regular {
  color: var(--warning-text);
}

.col-porcentaje.critico {
  color: var(--danger-text);
}

@media (max-width: 768px) {
  .stats-summary {
    grid-template-columns: repeat(2, 1fr);
  }

  .page-content {
    padding: 1rem;
  }

  .fechas-table {
    display: block;
    overflow-x: auto;
  }

  .table-header > span,
  .table-row > span {
    padding: 0.625rem 0.75rem;
  }
}

.filtros {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 1rem;
  padding: 1rem;
  margin-bottom: 1.5rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
}

.campo {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  flex: 1 1 180px;
}

.campo label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
}

.campo select,
.campo input {
  padding: 0.5625rem 0.75rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-sm);
  background: var(--surface);
  color: var(--text);
  font-size: 0.9375rem;
}

.periodos {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.periodos button {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border-strong);
  border-radius: 999px;
  background: transparent;
  color: var(--text-2);
  font-size: 0.8125rem;
  cursor: pointer;
}

.periodos button:hover {
  background: var(--surface-hover);
}

.btn {
  padding: 0.5625rem 1rem;
  border-radius: var(--radius-sm);
  font-size: 0.875rem;
  font-weight: 600;
  text-decoration: none;
  cursor: pointer;
}

.btn:disabled {
  opacity: 0.5;
  cursor: default;
}

.btn-primario {
  border: none;
  background: var(--primary);
  color: var(--on-primary);
}

.btn-secundario {
  border: 1px solid var(--border-strong);
  background: var(--surface);
  color: var(--text);
}
</style>
