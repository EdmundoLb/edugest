<script setup>
// Resumen de un mes para toda la institución (admin) o para los cursos del
// docente (RLS filtra): porcentaje por curso, comparación con el mes anterior,
// alumnos en riesgo y la tendencia de los últimos meses.
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { cursosDelUsuario } from '@/lib/api/cursos'
import { resumenPorFecha, esFuncionFaltante } from '@/lib/api/reportes'
import { alumnosEnRiesgo, UMBRAL_PORCENTAJE } from '@/lib/api/alertas'
import { resumirFilasPorCursoYMes } from '@/lib/historial'
import { hoyLocal, mesesAnteriores, rangoDeMeses, rangoDelMes, nombreDelMes } from '@/lib/fecha'
import { descargarCsv, nombreArchivo } from '@/lib/exportar'

const MESES_TENDENCIA = 6

const route = useRoute()
const router = useRouter()
const { state, esAdmin, rutaInicio } = useAuth()
const toast = useToast()

const mesActual = hoyLocal().slice(0, 7)
const mes = ref(/^\d{4}-\d{2}$/.test(route.query.mes ?? '') ? route.query.mes : mesActual)

const cargando = ref(false)
const faltaMigracion = ref(false)
const sinAlertas = ref(false)

const cursos = ref([]) // todos los visibles, para detectar los que no registraron nada
const resumen = ref({ cursos: [], institucion: {} })
const riesgo = ref([])

const meses = computed(() => mesesAnteriores(mes.value, MESES_TENDENCIA))
const mesAnterior = computed(() => meses.value[MESES_TENDENCIA - 2])
const tituloMes = computed(() => nombreMes(mes.value))

function nombreMes(m) {
  const [a, n] = m.split('-').map(Number)
  return nombreDelMes(a, n)
}

function mesCorto(m) {
  const [a, n] = m.split('-').map(Number)
  return new Date(a, n - 1, 1).toLocaleDateString('es-ES', { month: 'short', year: '2-digit' })
}

const riesgoPorCurso = computed(() => {
  const mapa = new Map()
  riesgo.value.forEach((r) => mapa.set(r.curso_id, (mapa.get(r.curso_id) ?? 0) + 1))
  return mapa
})

const filas = computed(() =>
  resumen.value.cursos
    .map((c) => {
      const actual = c.meses[mes.value]
      const previo = c.meses[mesAnterior.value]
      return {
        ...c,
        actual,
        variacion:
          actual?.porcentaje != null && previo?.porcentaje != null
            ? actual.porcentaje - previo.porcentaje
            : null,
        enRiesgo: riesgoPorCurso.value.get(c.cursoId) ?? 0,
      }
    })
    .filter((c) => c.actual)
    .sort((a, b) => (a.actual.porcentaje ?? 101) - (b.actual.porcentaje ?? 101)),
)

const cursosSinRegistros = computed(() => {
  const conRegistros = new Set(filas.value.map((f) => f.cursoId))
  return cursos.value.filter((c) => !conRegistros.has(c.id))
})

const totalMes = computed(() => resumen.value.institucion[mes.value] ?? null)
const variacionInstitucional = computed(() => {
  const previo = resumen.value.institucion[mesAnterior.value]
  if (totalMes.value?.porcentaje == null || previo?.porcentaje == null) return null
  return totalMes.value.porcentaje - previo.porcentaje
})
const alumnosEnRiesgoUnicos = computed(() => new Set(riesgo.value.map((r) => r.alumno_id)).size)

onMounted(async () => {
  try {
    cursos.value = await cursosDelUsuario({
      esAdmin: esAdmin(),
      profesorId: state.datosUsuario?.id,
    })
  } catch (e) {
    toast.error('No se pudieron cargar los cursos', e)
  }
})

watch(
  mes,
  async () => {
    router.replace({ query: { ...route.query, mes: mes.value } })
    await cargar()
  },
  { immediate: true },
)

async function cargar() {
  cargando.value = true
  faltaMigracion.value = false
  sinAlertas.value = false
  try {
    const [anio, m] = mes.value.split('-').map(Number)
    const [filasPorFecha, alertas] = await Promise.all([
      resumenPorFecha(rangoDeMeses(meses.value[0], mes.value)),
      alumnosEnRiesgo(rangoDelMes(anio, m)).catch((e) => {
        // Sin 0011 el reporte sigue sirviendo, solo sin la columna de riesgo.
        if (!esFuncionFaltante(e)) throw e
        sinAlertas.value = true
        return []
      }),
    ])
    resumen.value = resumirFilasPorCursoYMes(filasPorFecha)
    riesgo.value = alertas
  } catch (e) {
    resumen.value = { cursos: [], institucion: {} }
    riesgo.value = []
    if (esFuncionFaltante(e)) {
      faltaMigracion.value = true
      console.error(e)
    } else {
      toast.error('No se pudo cargar el resumen del mes', e)
    }
  } finally {
    cargando.value = false
  }
}

function pct(valor) {
  return valor == null ? '—' : `${valor}%`
}

function nivel(valor) {
  if (valor == null) return 'sin-dato'
  if (valor < UMBRAL_PORCENTAJE) return 'bajo'
  if (valor < 90) return 'medio'
  return 'alto'
}

function exportarCsv() {
  descargarCsv(nombreArchivo('resumen institucional', mes.value), [
    [`EduGest — Resumen de asistencia — ${tituloMes.value}`],
    [],
    [
      'Curso',
      'Registros',
      'Presentes',
      'Ausentes',
      'Justificados',
      '% Asistencia',
      'Variación (pts)',
      'Alumnos en riesgo',
    ],
    ...filas.value.map((f) => [
      f.cursoNombre,
      f.actual.total,
      f.actual.presentes,
      f.actual.ausentes,
      f.actual.justificados,
      f.actual.porcentaje ?? '',
      f.variacion ?? '',
      sinAlertas.value ? '' : f.enRiesgo,
    ]),
    ...cursosSinRegistros.value.map((c) => [c.nombre, 0, '', '', '', '', '', '']),
    [],
    [`Tendencia (% de asistencia, últimos ${MESES_TENDENCIA} meses)`],
    ['Curso', ...meses.value.map(nombreMes)],
    ['Institución', ...meses.value.map((m) => resumen.value.institucion[m]?.porcentaje ?? '')],
    ...resumen.value.cursos.map((c) => [
      c.cursoNombre,
      ...meses.value.map((m) => c.meses[m]?.porcentaje ?? ''),
    ]),
  ])
  toast.exito('Resumen descargado')
}

function imprimir() {
  window.print()
}
</script>

<template>
  <div class="reporte-page">
    <PageHeader
      titulo="Resumen institucional"
      :subtitulo="esAdmin() ? 'Todos los cursos, mes a mes' : 'Tus cursos, mes a mes'"
      :volver="rutaInicio()"
    >
      <button
        type="button"
        class="btn btn-secundario"
        :disabled="!filas.length"
        @click="exportarCsv"
      >
        Descargar Excel
      </button>
      <button type="button" class="btn btn-primario" :disabled="!filas.length" @click="imprimir">
        Imprimir / PDF
      </button>
    </PageHeader>

    <div class="contenedor">
      <section class="filtros tarjeta no-print" aria-label="Filtros">
        <div class="campo">
          <label for="mes">Mes</label>
          <input id="mes" v-model="mes" class="input" type="month" :max="mesActual" />
        </div>
        <p class="texto-muted ayuda">
          % = presentes / (registros − justificados). Cursos ordenados del más bajo al más alto.
        </p>
      </section>

      <div class="encabezado-impresion">
        <img src="@/images/edugest-logo.png" alt="" class="logo-edugest" />
        <div>
          <strong>EduGest</strong>
          <span>Resumen de asistencia — {{ tituloMes }}</span>
        </div>
      </div>

      <div v-if="faltaMigracion" class="aviso aviso-error">
        <strong>Falta aplicar la migración de reportes.</strong>
        <p>
          Pegá <code>supabase/migrations/0008_reportes.sql</code> en el SQL Editor de Supabase y
          ejecutala.
        </p>
      </div>

      <div v-else-if="cargando" class="estado-carga">
        <AppSpinner size="large" />
        <p>Armando el resumen...</p>
      </div>

      <template v-else>
        <section class="kpis" aria-label="Totales del mes">
          <div class="kpi">
            <span :class="['kpi-valor', nivel(totalMes?.porcentaje)]">{{
              pct(totalMes?.porcentaje)
            }}</span>
            <span class="kpi-label">
              Asistencia de {{ tituloMes.toLowerCase() }}
              <span
                v-if="variacionInstitucional !== null"
                :class="['variacion', variacionInstitucional >= 0 ? 'sube' : 'baja']"
              >
                {{ variacionInstitucional >= 0 ? '▲' : '▼' }}
                {{ Math.abs(variacionInstitucional) }} pts
              </span>
            </span>
          </div>
          <div class="kpi">
            <span class="kpi-valor">{{ totalMes?.total ?? 0 }}</span>
            <span class="kpi-label">Registros de asistencia</span>
          </div>
          <div class="kpi">
            <span class="kpi-valor bajo">{{ totalMes?.ausentes ?? 0 }}</span>
            <span class="kpi-label">Ausencias sin justificar</span>
          </div>
          <div class="kpi">
            <span class="kpi-valor medio">{{ totalMes?.justificados ?? 0 }}</span>
            <span class="kpi-label">Justificadas</span>
          </div>
          <div v-if="!sinAlertas" class="kpi">
            <span :class="['kpi-valor', { bajo: alumnosEnRiesgoUnicos > 0 }]">{{
              alumnosEnRiesgoUnicos
            }}</span>
            <span class="kpi-label">Alumnos en riesgo</span>
          </div>
          <div class="kpi">
            <span :class="['kpi-valor', { medio: cursosSinRegistros.length > 0 }]">{{
              cursosSinRegistros.length
            }}</span>
            <span class="kpi-label">Cursos sin registros</span>
          </div>
        </section>

        <section class="tarjeta bloque">
          <h2>Cursos en {{ tituloMes.toLowerCase() }}</h2>
          <p v-if="!filas.length" class="texto-muted">
            No hay asistencia registrada en {{ tituloMes.toLowerCase() }}.
          </p>
          <div v-else class="tabla-scroll">
            <table class="tabla">
              <thead>
                <tr>
                  <th scope="col" class="izq">Curso</th>
                  <th scope="col">Registros</th>
                  <th scope="col">P</th>
                  <th scope="col">A</th>
                  <th scope="col">J</th>
                  <th scope="col">%</th>
                  <th scope="col">vs. mes anterior</th>
                  <th v-if="!sinAlertas" scope="col">En riesgo</th>
                  <th scope="col" class="no-print"><span class="sr-only">Detalle</span></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="f in filas" :key="f.cursoId">
                  <th scope="row" class="izq">{{ f.cursoNombre }}</th>
                  <td>{{ f.actual.total }}</td>
                  <td class="presente">{{ f.actual.presentes }}</td>
                  <td class="ausente">{{ f.actual.ausentes }}</td>
                  <td class="justificado">{{ f.actual.justificados }}</td>
                  <td>
                    <span :class="['pct', nivel(f.actual.porcentaje)]">{{
                      pct(f.actual.porcentaje)
                    }}</span>
                  </td>
                  <td>
                    <span
                      v-if="f.variacion !== null"
                      :class="['variacion', f.variacion >= 0 ? 'sube' : 'baja']"
                    >
                      {{ f.variacion >= 0 ? '▲' : '▼' }} {{ Math.abs(f.variacion) }} pts
                    </span>
                    <span v-else class="texto-muted">—</span>
                  </td>
                  <td v-if="!sinAlertas" :class="{ ausente: f.enRiesgo > 0 }">{{ f.enRiesgo }}</td>
                  <td class="no-print">
                    <router-link
                      :to="`/Reportes/mensual?curso=${f.cursoId}&mes=${mes}`"
                      class="btn btn-secundario btn-chico"
                    >
                      Ver planilla
                    </router-link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <p v-if="cursosSinRegistros.length" class="sin-registros">
            <strong>Sin asistencia registrada este mes:</strong>
            {{ cursosSinRegistros.map((c) => c.nombre).join(', ') }}
          </p>
        </section>

        <section v-if="resumen.cursos.length" class="tarjeta bloque">
          <h2>Tendencia de los últimos {{ MESES_TENDENCIA }} meses</h2>
          <div class="tabla-scroll">
            <table class="tabla tendencia">
              <thead>
                <tr>
                  <th scope="col" class="izq">Curso</th>
                  <th v-for="m in meses" :key="m" scope="col" :class="{ actual: m === mes }">
                    {{ mesCorto(m) }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr class="fila-institucion">
                  <th scope="row" class="izq">{{ esAdmin() ? 'Institución' : 'Tus cursos' }}</th>
                  <td v-for="m in meses" :key="m">
                    <span :class="['celda-pct', nivel(resumen.institucion[m]?.porcentaje)]">
                      {{ pct(resumen.institucion[m]?.porcentaje) }}
                    </span>
                  </td>
                </tr>
                <tr v-for="c in resumen.cursos" :key="c.cursoId">
                  <th scope="row" class="izq">{{ c.cursoNombre }}</th>
                  <td v-for="m in meses" :key="m">
                    <router-link
                      v-if="c.meses[m]"
                      :to="`/Reportes/mensual?curso=${c.cursoId}&mes=${m}`"
                      :class="['celda-pct', nivel(c.meses[m].porcentaje)]"
                      :title="`${c.meses[m].total} registros · ${c.meses[m].ausentes} ausencias`"
                    >
                      {{ pct(c.meses[m].porcentaje) }}
                    </router-link>
                    <span v-else class="celda-pct sin-dato">—</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="leyenda texto-muted">
            <span class="celda-pct alto">≥ 90%</span>
            <span class="celda-pct medio">{{ UMBRAL_PORCENTAJE }}–89%</span>
            <span class="celda-pct bajo">&lt; {{ UMBRAL_PORCENTAJE }}%</span>
            Tocá una celda para ver la planilla de ese mes.
          </p>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.reporte-page {
  min-height: calc(100vh - var(--navbar-height));
}

.filtros {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 1rem;
  padding: 1rem;
  margin-bottom: 1.25rem;
}

.filtros .campo {
  flex: 0 1 220px;
}

.ayuda {
  flex: 1 1 260px;
  font-size: 0.8125rem;
}

.encabezado-impresion {
  display: none;
}

.estado-carga {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 4rem 1rem;
  color: var(--text-muted);
}

.aviso {
  padding: 1.25rem;
  border-radius: var(--radius);
  border: 1px solid var(--border);
}

.aviso-error {
  background: var(--danger-soft);
  border-color: var(--danger-border);
  color: var(--danger-text);
}

.aviso p {
  margin-top: 0.25rem;
  color: var(--text-2);
}

.kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}

.kpi {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 1rem 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
}

.kpi-valor {
  font-size: 1.75rem;
  font-weight: 700;
  line-height: 1.1;
}

.kpi-valor.alto {
  color: var(--success-text);
}

.kpi-valor.medio {
  color: var(--warning-text);
}

.kpi-valor.bajo {
  color: var(--danger-text);
}

.kpi-label {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.variacion {
  margin-left: 0.25rem;
  font-weight: 700;
  white-space: nowrap;
}

.variacion.sube {
  color: var(--success-text);
}

.variacion.baja {
  color: var(--danger-text);
}

.bloque {
  padding: 1.25rem;
  margin-bottom: 1.25rem;
}

.bloque h2 {
  font-size: 1.0625rem;
  font-weight: 700;
  margin-bottom: 0.875rem;
}

.tabla-scroll {
  overflow-x: auto;
}

.tabla {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8125rem;
}

.tabla th,
.tabla td {
  padding: 0.5rem 0.5rem;
  border-bottom: 1px solid var(--border);
  text-align: center;
  white-space: nowrap;
}

.tabla thead th {
  background: var(--surface-2);
  color: var(--text-muted);
  font-weight: 600;
}

.tabla thead th.actual {
  color: var(--primary-text);
}

.tabla .izq {
  text-align: left;
  font-weight: 500;
  white-space: normal;
  min-width: 180px;
}

td.presente {
  color: var(--success-text);
}

td.ausente {
  color: var(--danger-text);
  font-weight: 600;
}

td.justificado {
  color: var(--warning-text);
}

.pct {
  font-weight: 700;
}

.pct.alto {
  color: var(--success-text);
}

.pct.medio {
  color: var(--warning-text);
}

.pct.bajo {
  color: var(--danger-text);
}

.sin-registros {
  margin-top: 0.875rem;
  padding: 0.75rem 1rem;
  border-radius: var(--radius-sm);
  background: var(--warning-soft);
  font-size: 0.8125rem;
  color: var(--text-2);
}

.fila-institucion th,
.fila-institucion td {
  background: var(--surface-2);
  font-weight: 700;
}

.celda-pct {
  display: inline-block;
  min-width: 3.25rem;
  padding: 0.25rem 0.375rem;
  border-radius: var(--radius-sm);
  font-weight: 600;
  text-decoration: none;
}

.celda-pct.alto {
  background: var(--success-soft);
  color: var(--success-text);
}

.celda-pct.medio {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.celda-pct.bajo {
  background: var(--danger-soft);
  color: var(--danger-text);
}

.celda-pct.sin-dato {
  color: var(--text-subtle);
}

a.celda-pct:hover {
  outline: 2px solid var(--primary-border);
}

.leyenda {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.75rem;
  font-size: 0.75rem;
}

@media print {
  .reporte-page :deep(.page-header) {
    display: none;
  }

  .contenedor {
    max-width: none;
    padding: 0;
  }

  .encabezado-impresion {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .encabezado-impresion img {
    width: 48px;
    height: 48px;
    object-fit: contain;
  }

  .encabezado-impresion div {
    display: flex;
    flex-direction: column;
  }

  .bloque {
    break-inside: avoid;
  }
}
</style>
