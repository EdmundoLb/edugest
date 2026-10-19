<script setup>
// Historial de asistencia de un alumno: resumen por curso, evolución por mes
// y detalle clase por clase. Lo usan el perfil del alumno (admin/docente) y
// "Mi asistencia" (el propio alumno). RLS decide qué registros llegan.
import { ref, computed, watch } from 'vue'
import AppSpinner from '@/components/AppSpinner.vue'
import AppPagination from '@/components/AppPagination.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useToast } from '@/composables/useToast'
import { asistenciaDeAlumno } from '@/lib/api/historial'
import { UMBRAL_PORCENTAJE, FALTAS_SEGUIDAS } from '@/lib/api/alertas'
import {
  normalizarRegistro,
  combinarPorDia,
  contar,
  resumirPorCurso,
  resumirPorMes,
} from '@/lib/historial'
import {
  hoyLocal,
  mesesAnteriores,
  rangoDeMeses,
  nombreDelMes,
  formatearFecha,
  formatearHora,
} from '@/lib/fecha'
import { descargarCsv, nombreArchivo } from '@/lib/exportar'

const props = defineProps({
  alumnoId: { type: String, required: true },
  nombreAlumno: { type: String, default: '' },
})

const emit = defineEmits(['cargado'])

const toast = useToast()

const POR_PAGINA = 15
const ESTADOS = { presente: 'Presente', ausente: 'Ausente', justificado: 'Justificado' }

const mesActual = hoyLocal().slice(0, 7)
const mesDesde = ref(mesesAnteriores(mesActual, 6)[0])
const mesHasta = ref(mesActual)
const filtroCurso = ref('')
const filtroEstado = ref('')
const pagina = ref(1)

const cargando = ref(false)
const dias = ref([]) // combinados: un registro por curso+fecha

const cursos = computed(() =>
  resumirPorCurso(dias.value).map(({ cursoId, cursoNombre }) => ({ cursoId, cursoNombre })),
)
const diasDelCurso = computed(() =>
  filtroCurso.value ? dias.value.filter((d) => d.cursoId === filtroCurso.value) : dias.value,
)
const totales = computed(() => contar(diasDelCurso.value))
const porCurso = computed(() => resumirPorCurso(dias.value))
const porMes = computed(() => resumirPorMes(diasDelCurso.value).reverse())

const detalle = computed(() =>
  filtroEstado.value
    ? diasDelCurso.value.filter((d) => d.estado === filtroEstado.value)
    : diasDelCurso.value,
)
const totalPaginas = computed(() => Math.max(1, Math.ceil(detalle.value.length / POR_PAGINA)))
const detallePagina = computed(() =>
  detalle.value.slice((pagina.value - 1) * POR_PAGINA, pagina.value * POR_PAGINA),
)

const tituloPeriodo = computed(() => {
  const [a1, m1] = mesDesde.value.split('-').map(Number)
  const [a2, m2] = mesHasta.value.split('-').map(Number)
  const desde = nombreDelMes(a1, m1)
  const hasta = nombreDelMes(a2, m2)
  return desde === hasta ? desde : `${desde} a ${hasta}`
})

watch([() => props.alumnoId, mesDesde, mesHasta], () => cargar(), { immediate: true })
watch([filtroCurso, filtroEstado], () => (pagina.value = 1))

async function cargar() {
  if (!props.alumnoId || !mesDesde.value || !mesHasta.value) return
  if (mesDesde.value > mesHasta.value)
    [mesDesde.value, mesHasta.value] = [mesHasta.value, mesDesde.value]
  cargando.value = true
  try {
    const filas = await asistenciaDeAlumno(
      props.alumnoId,
      rangoDeMeses(mesDesde.value, mesHasta.value),
    )
    dias.value = combinarPorDia(filas.map(normalizarRegistro))
    if (filtroCurso.value && !dias.value.some((d) => d.cursoId === filtroCurso.value)) {
      filtroCurso.value = ''
    }
    pagina.value = 1
    emit('cargado', dias.value)
  } catch (e) {
    toast.error('No se pudo cargar el historial de asistencia', e)
  } finally {
    cargando.value = false
  }
}

function pct(valor) {
  return valor === null ? '—' : `${valor}%`
}

function nombreMes(mes) {
  const [a, m] = mes.split('-').map(Number)
  return nombreDelMes(a, m)
}

function exportarCsv() {
  const filas = [
    [`Centro Cultural Gymmart — Historial de asistencia — ${props.nombreAlumno}`],
    [`Período: ${tituloPeriodo.value}`],
    [],
    ['Resumen por curso'],
    ['Curso', 'Clases', 'Presentes', 'Ausentes', 'Justificadas', '% Asistencia'],
    ...porCurso.value.map((c) => [
      c.cursoNombre,
      c.total,
      c.presentes,
      c.ausentes,
      c.justificados,
      c.porcentaje ?? '',
    ]),
    [],
    ['Resumen por mes'],
    ['Mes', 'Clases', 'Presentes', 'Ausentes', 'Justificadas', '% Asistencia'],
    ...porMes.value.map((m) => [
      nombreMes(m.mes),
      m.total,
      m.presentes,
      m.ausentes,
      m.justificados,
      m.porcentaje ?? '',
    ]),
    [],
    ['Detalle'],
    ['Fecha', 'Curso', 'Estado', 'Observación'],
    ...detalle.value.map((d) => [
      formatearFecha(d.fecha, { day: '2-digit', month: '2-digit', year: 'numeric' }),
      d.cursoNombre,
      ESTADOS[d.estado] ?? d.estado,
      d.observacion,
    ]),
  ]
  descargarCsv(
    nombreArchivo('historial', props.nombreAlumno, mesDesde.value, mesHasta.value),
    filas,
  )
  toast.exito('Historial descargado')
}

function imprimir() {
  window.print()
}

defineExpose({ recargar: cargar })
</script>

<template>
  <section class="historial" aria-label="Historial de asistencia">
    <div class="historial-cabecera">
      <div>
        <h2>Historial de asistencia</h2>
        <p class="texto-muted">{{ tituloPeriodo }}</p>
      </div>
      <div class="acciones no-print">
        <button
          type="button"
          class="btn btn-secundario btn-chico"
          :disabled="!dias.length"
          @click="exportarCsv"
        >
          Descargar Excel
        </button>
        <button
          type="button"
          class="btn btn-secundario btn-chico"
          :disabled="!dias.length"
          @click="imprimir"
        >
          Imprimir / PDF
        </button>
      </div>
    </div>

    <div class="filtros no-print">
      <div class="campo">
        <label for="hist-desde">Desde</label>
        <input id="hist-desde" v-model="mesDesde" class="input" type="month" :max="mesActual" />
      </div>
      <div class="campo">
        <label for="hist-hasta">Hasta</label>
        <input id="hist-hasta" v-model="mesHasta" class="input" type="month" :max="mesActual" />
      </div>
      <div class="campo">
        <label for="hist-curso">Curso</label>
        <select id="hist-curso" v-model="filtroCurso" class="input">
          <option value="">Todos los cursos</option>
          <option v-for="c in cursos" :key="c.cursoId" :value="c.cursoId">
            {{ c.cursoNombre }}
          </option>
        </select>
      </div>
    </div>

    <div v-if="cargando" class="estado-carga">
      <AppSpinner size="medium" />
      <p>Cargando historial...</p>
    </div>

    <EmptyState
      v-else-if="!dias.length"
      title="Sin asistencia registrada en este período"
      hint="Probá ampliando el rango de meses."
    />

    <template v-else>
      <div class="kpis">
        <div class="kpi">
          <span class="kpi-valor">{{ totales.total }}</span>
          <span class="kpi-label">Clases</span>
        </div>
        <div class="kpi">
          <span class="kpi-valor presente">{{ totales.presentes }}</span>
          <span class="kpi-label">Presente</span>
        </div>
        <div class="kpi">
          <span class="kpi-valor ausente">{{ totales.ausentes }}</span>
          <span class="kpi-label">Ausente</span>
        </div>
        <div class="kpi">
          <span class="kpi-valor justificado">{{ totales.justificados }}</span>
          <span class="kpi-label">Justificado</span>
        </div>
        <div class="kpi">
          <span
            :class="[
              'kpi-valor',
              totales.porcentaje !== null && totales.porcentaje < UMBRAL_PORCENTAJE
                ? 'ausente'
                : 'primario',
            ]"
            >{{ pct(totales.porcentaje) }}</span
          >
          <span class="kpi-label">Asistencia</span>
        </div>
      </div>

      <div class="grilla-resumen">
        <div class="tarjeta bloque">
          <h3>Por curso</h3>
          <table class="tabla">
            <thead>
              <tr>
                <th scope="col" class="izq">Curso</th>
                <th scope="col">Clases</th>
                <th scope="col">P</th>
                <th scope="col">A</th>
                <th scope="col">J</th>
                <th scope="col">%</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="c in porCurso"
                :key="c.cursoId"
                :class="{ seleccionado: filtroCurso === c.cursoId }"
              >
                <th scope="row" class="izq">
                  <button
                    type="button"
                    class="link-curso"
                    @click="filtroCurso = filtroCurso === c.cursoId ? '' : c.cursoId"
                  >
                    {{ c.cursoNombre }}
                  </button>
                  <span v-if="c.faltasSeguidas >= FALTAS_SEGUIDAS" class="etiqueta-alerta">
                    {{ c.faltasSeguidas }} faltas seguidas
                  </span>
                </th>
                <td>{{ c.total }}</td>
                <td class="presente">{{ c.presentes }}</td>
                <td class="ausente">{{ c.ausentes }}</td>
                <td class="justificado">{{ c.justificados }}</td>
                <td
                  :class="[
                    'pct',
                    { bajo: c.porcentaje !== null && c.porcentaje < UMBRAL_PORCENTAJE },
                  ]"
                >
                  {{ pct(c.porcentaje) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="tarjeta bloque">
          <h3>
            Por mes<span v-if="filtroCurso" class="texto-muted">
              · {{ cursos.find((c) => c.cursoId === filtroCurso)?.cursoNombre }}</span
            >
          </h3>
          <ul class="meses">
            <li v-for="m in porMes" :key="m.mes" class="mes">
              <div class="mes-texto">
                <span>{{ nombreMes(m.mes) }}</span>
                <span class="texto-muted">
                  {{ m.presentes }}P · {{ m.ausentes }}A · {{ m.justificados }}J
                </span>
              </div>
              <div
                class="barra"
                role="img"
                :aria-label="`${nombreMes(m.mes)}: ${pct(m.porcentaje)}`"
              >
                <span
                  :class="[
                    'barra-relleno',
                    { bajo: m.porcentaje !== null && m.porcentaje < UMBRAL_PORCENTAJE },
                  ]"
                  :style="{ width: `${m.porcentaje ?? 0}%` }"
                ></span>
              </div>
              <strong
                :class="[
                  'mes-pct',
                  { bajo: m.porcentaje !== null && m.porcentaje < UMBRAL_PORCENTAJE },
                ]"
              >
                {{ pct(m.porcentaje) }}
              </strong>
            </li>
          </ul>
        </div>
      </div>

      <div class="tarjeta bloque">
        <div class="detalle-cabecera">
          <h3>Clase por clase</h3>
          <select
            v-model="filtroEstado"
            class="input filtro-estado no-print"
            aria-label="Filtrar por estado"
          >
            <option value="">Todos los estados</option>
            <option v-for="(texto, valor) in ESTADOS" :key="valor" :value="valor">
              {{ texto }}
            </option>
          </select>
        </div>

        <p v-if="!detalle.length" class="texto-muted sin-detalle">No hay clases con ese estado.</p>

        <ul v-else class="registros">
          <li
            v-for="d in detallePagina"
            :key="`${d.cursoId}|${d.fecha}`"
            :class="['registro', d.estado]"
          >
            <div class="registro-fecha">
              <span class="fecha-dia">{{ formatearFecha(d.fecha, { day: 'numeric' }) }}</span>
              <span class="fecha-mes">{{
                formatearFecha(d.fecha, { month: 'short', year: '2-digit' })
              }}</span>
            </div>
            <div class="registro-info">
              <span class="registro-curso">{{ d.cursoNombre }}</span>
              <span class="texto-muted registro-horario">
                {{ formatearFecha(d.fecha, { weekday: 'long' }) }}
                <template v-if="d.horaInicio"> · {{ formatearHora(d.horaInicio) }}</template>
              </span>
              <span v-if="d.observacion" class="registro-obs">{{ d.observacion }}</span>
            </div>
            <span :class="['estado-badge', d.estado]">{{ ESTADOS[d.estado] ?? d.estado }}</span>
          </li>
        </ul>

        <AppPagination
          class="no-print"
          :current-page="pagina"
          :total-pages="totalPaginas"
          @page-change="(p) => (pagina = p)"
        />
      </div>
    </template>
  </section>
</template>

<style scoped>
.historial {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.historial-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 1rem;
  flex-wrap: wrap;
}

h2 {
  font-size: 1.125rem;
  font-weight: 700;
}

h3 {
  font-size: 0.9375rem;
  font-weight: 600;
  margin-bottom: 0.75rem;
}

.acciones {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.filtros {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 0.75rem;
  padding: 1rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
}

.estado-carga {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
  padding: 3rem 1rem;
  color: var(--text-muted);
}

.kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 0.75rem;
}

.kpi {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.875rem 1rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
}

.kpi-valor {
  font-size: 1.5rem;
  font-weight: 700;
  line-height: 1.1;
}

.kpi-valor.presente {
  color: var(--success-text);
}

.kpi-valor.ausente {
  color: var(--danger-text);
}

.kpi-valor.justificado {
  color: var(--warning-text);
}

.kpi-valor.primario {
  color: var(--primary-text);
}

.kpi-label {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.grilla-resumen {
  display: grid;
  grid-template-columns: 1.3fr 1fr;
  gap: 1rem;
}

.bloque {
  padding: 1rem 1.25rem;
  min-width: 0;
  overflow-x: auto;
}

.tabla {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8125rem;
}

.tabla th,
.tabla td {
  padding: 0.5rem 0.375rem;
  border-bottom: 1px solid var(--border);
  text-align: center;
}

.tabla thead th {
  color: var(--text-muted);
  font-weight: 600;
}

.tabla .izq {
  text-align: left;
  font-weight: 500;
}

.tabla tr.seleccionado {
  background: var(--primary-soft);
}

.link-curso {
  background: none;
  border: none;
  padding: 0;
  font: inherit;
  color: var(--primary-text);
  cursor: pointer;
  text-align: left;
}

.link-curso:hover {
  text-decoration: underline;
}

.etiqueta-alerta {
  display: inline-block;
  margin-left: 0.375rem;
  padding: 0.0625rem 0.375rem;
  border-radius: 999px;
  font-size: 0.6875rem;
  background: var(--danger-soft);
  color: var(--danger-text);
}

td.presente {
  color: var(--success-text);
}

td.ausente {
  color: var(--danger-text);
}

td.justificado {
  color: var(--warning-text);
}

.pct {
  font-weight: 700;
  color: var(--success-text);
}

.pct.bajo,
.mes-pct.bajo {
  color: var(--danger-text);
}

.meses {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
}

.mes {
  display: grid;
  grid-template-columns: minmax(120px, 1fr) 1.2fr auto;
  align-items: center;
  gap: 0.75rem;
  font-size: 0.8125rem;
}

.mes-texto {
  display: flex;
  flex-direction: column;
}

.mes-texto .texto-muted {
  font-size: 0.75rem;
}

.barra {
  height: 8px;
  border-radius: 999px;
  background: var(--surface-hover);
  overflow: hidden;
}

.barra-relleno {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--success);
}

.barra-relleno.bajo {
  background: var(--danger);
}

.mes-pct {
  min-width: 3rem;
  text-align: right;
  color: var(--success-text);
}

.detalle-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  margin-bottom: 0.75rem;
}

.detalle-cabecera h3 {
  margin-bottom: 0;
}

.filtro-estado {
  width: auto;
  font-size: 0.8125rem;
  padding: 0.375rem 0.625rem;
}

.sin-detalle {
  padding: 1rem 0;
  font-size: 0.875rem;
}

.registros {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.registro {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 1rem;
  align-items: center;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--border);
  border-left: 3px solid transparent;
  border-radius: var(--radius-sm);
}

.registro.presente {
  border-left-color: var(--success);
}

.registro.ausente {
  border-left-color: var(--danger);
}

.registro.justificado {
  border-left-color: var(--warning);
}

.registro-fecha {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 44px;
}

.fecha-dia {
  font-size: 1.125rem;
  font-weight: 700;
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
  min-width: 0;
}

.registro-curso {
  font-size: 0.875rem;
  font-weight: 500;
}

.registro-horario {
  font-size: 0.75rem;
  text-transform: capitalize;
}

.registro-obs {
  font-size: 0.75rem;
  font-style: italic;
  color: var(--text-subtle);
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

@media (max-width: 800px) {
  .grilla-resumen {
    grid-template-columns: 1fr;
  }
}

@media print {
  .bloque {
    break-inside: avoid;
    overflow: visible;
  }

  .grilla-resumen {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
