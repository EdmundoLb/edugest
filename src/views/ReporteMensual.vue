<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { cursosDelUsuario } from '@/lib/api/cursos'
import {
  asistenciaMensualCurso,
  resumenPorAlumno,
  resumenPorFecha,
  porcentajeAsistencia,
  esFuncionFaltante,
} from '@/lib/api/reportes'
import { hoyLocal, rangoDelMes, nombreDelMes, formatearFecha } from '@/lib/fecha'
import { descargarCsv, nombreArchivo } from '@/lib/exportar'

const UMBRAL_RIESGO = 75

const route = useRoute()
const router = useRouter()
const { state, esAdmin, rutaInicio } = useAuth()
const toast = useToast()

const cursos = ref([])
const cursoId = ref(null)
const mes = ref(hoyLocal().slice(0, 7)) // "YYYY-MM"

const cargandoCursos = ref(true)
const cargando = ref(false)
const faltaMigracion = ref(false)

const grilla = ref([]) // filas { alumno_id, fecha, estado, observacion }
const porAlumno = ref([]) // filas de resumen_asistencia_por_alumno
const porcentajeMesAnterior = ref(null)

const anioMes = computed(() => {
  const [anio, m] = mes.value.split('-').map(Number)
  return { anio, mes: m }
})
const tituloMes = computed(() => nombreDelMes(anioMes.value.anio, anioMes.value.mes))
const cursoSeleccionado = computed(() => cursos.value.find((c) => c.id === cursoId.value) ?? null)

// Solo los días que tuvieron clase (con algún registro), no los 30 del mes.
const fechasConClase = computed(() => [...new Set(grilla.value.map((r) => r.fecha))].sort())

const celdas = computed(() => {
  const mapa = new Map()
  grilla.value.forEach((r) => mapa.set(`${r.alumno_id}|${r.fecha}`, r))
  return mapa
})

const filas = computed(() =>
  porAlumno.value.map((a) => ({
    ...a,
    porcentaje: a.porcentaje === null ? null : Math.round(Number(a.porcentaje)),
    enRiesgo: a.porcentaje !== null && Number(a.porcentaje) < UMBRAL_RIESGO,
  })),
)

const totales = computed(() => {
  const t = { total: 0, presentes: 0, ausentes: 0, justificados: 0 }
  porAlumno.value.forEach((a) => {
    t.total += Number(a.total)
    t.presentes += Number(a.presentes)
    t.ausentes += Number(a.ausentes)
    t.justificados += Number(a.justificados)
  })
  return { ...t, porcentaje: porcentajeAsistencia(t) }
})

const porcentajePorDia = computed(() =>
  fechasConClase.value.map((f) => {
    const t = { total: 0, presentes: 0, justificados: 0 }
    grilla.value
      .filter((r) => r.fecha === f)
      .forEach((r) => {
        t.total++
        if (r.estado === 'presente') t.presentes++
        if (r.estado === 'justificado') t.justificados++
      })
    return porcentajeAsistencia(t)
  }),
)

const alumnosEnRiesgo = computed(() => filas.value.filter((f) => f.enRiesgo).length)

const variacion = computed(() => {
  if (totales.value.porcentaje === null || porcentajeMesAnterior.value === null) return null
  return totales.value.porcentaje - porcentajeMesAnterior.value
})

const LETRA = { presente: 'P', ausente: 'A', justificado: 'J' }

onMounted(async () => {
  try {
    cursos.value = await cursosDelUsuario({
      esAdmin: esAdmin(),
      profesorId: state.datosUsuario?.id,
    })
  } catch (e) {
    toast.error('No se pudieron cargar los cursos', e)
  } finally {
    cargandoCursos.value = false
  }

  if (/^\d{4}-\d{2}$/.test(route.query.mes ?? '')) mes.value = route.query.mes
  const desdeQuery = cursos.value.find((c) => c.id === route.query.curso)
  if (desdeQuery) cursoId.value = desdeQuery.id
  else if (cursos.value.length === 1) cursoId.value = cursos.value[0].id
})

watch([cursoId, mes], async () => {
  router.replace({ query: { ...route.query, curso: cursoId.value ?? undefined, mes: mes.value } })
  await cargarReporte()
})

async function cargarReporte() {
  grilla.value = []
  porAlumno.value = []
  porcentajeMesAnterior.value = null
  if (!cursoId.value || !mes.value) return

  cargando.value = true
  faltaMigracion.value = false
  try {
    const { anio, mes: m } = anioMes.value
    const rango = rangoDelMes(anio, m)
    const anterior = m === 1 ? rangoDelMes(anio - 1, 12) : rangoDelMes(anio, m - 1)

    const [dias, alumnos, mesAnterior] = await Promise.all([
      asistenciaMensualCurso({ cursoId: cursoId.value, ...rango }),
      resumenPorAlumno({ cursoId: cursoId.value, ...rango }),
      resumenPorFecha({ cursoId: cursoId.value, ...anterior }),
    ])
    grilla.value = dias
    porAlumno.value = alumnos

    const t = { total: 0, presentes: 0, justificados: 0 }
    mesAnterior.forEach((r) => {
      t.total += Number(r.total)
      t.presentes += Number(r.presentes)
      t.justificados += Number(r.justificados)
    })
    porcentajeMesAnterior.value = porcentajeAsistencia(t)
  } catch (e) {
    if (esFuncionFaltante(e)) {
      faltaMigracion.value = true
      console.error(e)
    } else {
      toast.error('No se pudo cargar el reporte', e)
    }
  } finally {
    cargando.value = false
  }
}

function diaCorto(fecha) {
  return formatearFecha(fecha, { day: 'numeric' })
}

function diaSemanaCorto(fecha) {
  return formatearFecha(fecha, { weekday: 'short' }).replace('.', '')
}

function exportarCsv() {
  const encabezado = [
    'Apellido',
    'Nombre',
    'CI',
    ...fechasConClase.value.map((f) => formatearFecha(f, { day: '2-digit', month: '2-digit' })),
    'Presentes',
    'Ausentes',
    'Justificados',
    '% Asistencia',
  ]
  const cuerpo = filas.value.map((a) => [
    a.apellido,
    a.nombre,
    a.ci,
    ...fechasConClase.value.map(
      (f) => LETRA[celdas.value.get(`${a.alumno_id}|${f}`)?.estado] ?? '',
    ),
    a.presentes,
    a.ausentes,
    a.justificados,
    a.porcentaje ?? '',
  ])
  const pie = [
    'Asistencia del día (%)',
    '',
    '',
    ...porcentajePorDia.value.map((p) => p ?? ''),
    totales.value.presentes,
    totales.value.ausentes,
    totales.value.justificados,
    totales.value.porcentaje ?? '',
  ]
  descargarCsv(nombreArchivo('asistencia', cursoSeleccionado.value.nombre, mes.value), [
    [`EduGest — ${cursoSeleccionado.value.nombre} — ${tituloMes.value}`],
    ['P = presente, A = ausente, J = justificado'],
    [],
    encabezado,
    ...cuerpo,
    pie,
  ])
  toast.exito('Planilla descargada')
}

function imprimir() {
  window.print()
}
</script>

<template>
  <div class="reporte-page">
    <PageHeader
      titulo="Reporte mensual"
      subtitulo="Asistencia por curso, alumno por alumno"
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

    <div class="page-content">
      <section class="filtros no-print" aria-label="Filtros">
        <div class="campo">
          <label for="curso">Curso</label>
          <select id="curso" v-model="cursoId" :disabled="cargandoCursos">
            <option :value="null" disabled>
              {{ cargandoCursos ? 'Cargando...' : 'Elegí un curso' }}
            </option>
            <option v-for="c in cursos" :key="c.id" :value="c.id">{{ c.nombre }}</option>
          </select>
        </div>
        <div class="campo">
          <label for="mes">Mes</label>
          <input id="mes" v-model="mes" type="month" :max="hoyLocal().slice(0, 7)" />
        </div>
      </section>

      <!-- Encabezado que solo aparece al imprimir -->
      <div v-if="cursoSeleccionado" class="encabezado-impresion">
        <img src="@/images/edugest-logo.png" alt="" class="logo-edugest" />
        <div>
          <strong>EduGest</strong>
          <span>Reporte de asistencia — {{ cursoSeleccionado.nombre }} — {{ tituloMes }}</span>
        </div>
      </div>

      <div v-if="faltaMigracion" class="aviso aviso-error">
        <strong>Falta aplicar la migración de reportes.</strong>
        <p>
          Pegá <code>supabase/migrations/0008_reportes.sql</code> en el SQL Editor de Supabase y
          ejecutala. Mientras tanto podés usar la pantalla de Reportes.
        </p>
      </div>

      <EmptyState
        v-else-if="!cursoId && !cargandoCursos"
        title="Elegí un curso y un mes"
        hint="Vas a ver la asistencia de cada alumno día por día, con totales y porcentaje."
      />

      <div v-else-if="cargando || cargandoCursos" class="estado-carga">
        <AppSpinner size="large" />
        <p>Armando el reporte...</p>
      </div>

      <EmptyState v-else-if="!filas.length" title="Este curso no tiene alumnos inscriptos" />

      <template v-else>
        <section class="kpis" aria-label="Resumen del mes">
          <div class="kpi">
            <span class="kpi-valor">{{ fechasConClase.length }}</span>
            <span class="kpi-label">Clases registradas</span>
          </div>
          <div class="kpi">
            <span class="kpi-valor">
              {{ totales.porcentaje === null ? '—' : `${totales.porcentaje}%` }}
            </span>
            <span class="kpi-label">
              Asistencia del curso
              <span
                v-if="variacion !== null"
                :class="['variacion', variacion >= 0 ? 'sube' : 'baja']"
                :title="`Mes anterior: ${porcentajeMesAnterior}%`"
              >
                {{ variacion >= 0 ? '▲' : '▼' }} {{ Math.abs(variacion) }} pts
              </span>
            </span>
          </div>
          <div class="kpi">
            <span class="kpi-valor ausente">{{ totales.ausentes }}</span>
            <span class="kpi-label">Ausencias</span>
          </div>
          <div class="kpi">
            <span class="kpi-valor justificado">{{ totales.justificados }}</span>
            <span class="kpi-label">Justificadas</span>
          </div>
          <div class="kpi">
            <span :class="['kpi-valor', { ausente: alumnosEnRiesgo > 0 }]">
              {{ alumnosEnRiesgo }}
            </span>
            <span class="kpi-label">Alumnos bajo {{ UMBRAL_RIESGO }}%</span>
          </div>
        </section>

        <p v-if="!fechasConClase.length" class="sin-clases">
          No hay asistencia registrada en {{ tituloMes.toLowerCase() }} para este curso.
        </p>

        <div class="tabla-scroll">
          <table class="tabla">
            <caption class="sr-only">
              Asistencia de
              {{
                cursoSeleccionado?.nombre
              }}
              en
              {{
                tituloMes
              }}
            </caption>
            <thead>
              <tr>
                <th scope="col" class="col-alumno">Alumno</th>
                <th v-for="f in fechasConClase" :key="f" scope="col" class="col-dia">
                  <span class="dia-semana">{{ diaSemanaCorto(f) }}</span>
                  <span>{{ diaCorto(f) }}</span>
                </th>
                <th scope="col" class="col-total">P</th>
                <th scope="col" class="col-total">A</th>
                <th scope="col" class="col-total">J</th>
                <th scope="col" class="col-total">%</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="a in filas" :key="a.alumno_id" :class="{ riesgo: a.enRiesgo }">
                <th scope="row" class="col-alumno">
                  <span class="apellido">{{ a.apellido }}</span
                  >, {{ a.nombre }}
                  <span
                    v-if="a.activa === false"
                    class="badge-baja"
                    :title="a.fecha_baja ? `Baja desde ${formatearFecha(a.fecha_baja)}` : undefined"
                    >baja</span
                  >
                </th>
                <td
                  v-for="f in fechasConClase"
                  :key="f"
                  :class="['celda', celdas.get(`${a.alumno_id}|${f}`)?.estado]"
                  :title="celdas.get(`${a.alumno_id}|${f}`)?.observacion || undefined"
                >
                  {{ LETRA[celdas.get(`${a.alumno_id}|${f}`)?.estado] ?? '·' }}
                  <span v-if="celdas.get(`${a.alumno_id}|${f}`)?.observacion" class="obs-marca"
                    >*</span
                  >
                </td>
                <td class="col-total">{{ a.presentes }}</td>
                <td class="col-total">{{ a.ausentes }}</td>
                <td class="col-total">{{ a.justificados }}</td>
                <td class="col-total porcentaje">
                  {{ a.porcentaje === null ? '—' : `${a.porcentaje}%` }}
                </td>
              </tr>
            </tbody>
            <tfoot v-if="fechasConClase.length">
              <tr>
                <th scope="row" class="col-alumno">Asistencia del día</th>
                <td v-for="(p, i) in porcentajePorDia" :key="fechasConClase[i]" class="celda-pie">
                  {{ p === null ? '—' : `${p}%` }}
                </td>
                <td class="col-total">{{ totales.presentes }}</td>
                <td class="col-total">{{ totales.ausentes }}</td>
                <td class="col-total">{{ totales.justificados }}</td>
                <td class="col-total porcentaje">
                  {{ totales.porcentaje === null ? '—' : `${totales.porcentaje}%` }}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>

        <p class="leyenda">
          <span class="chip presente">P</span> presente <span class="chip ausente">A</span> ausente
          <span class="chip justificado">J</span> justificado <span class="chip">·</span> sin
          registro · <span class="obs-marca">*</span> tiene observación (pasá el mouse para verla) ·
          % = presentes / (clases − justificadas). Filas resaltadas: menos de {{ UMBRAL_RIESGO }}%.
        </p>
      </template>
    </div>
  </div>
</template>

<style scoped>
.reporte-page {
  min-height: calc(100vh - var(--navbar-height));
}

.page-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1.5rem;
}

.btn {
  padding: 0.5625rem 1rem;
  border-radius: var(--radius-sm);
  font-size: 0.875rem;
  font-weight: 600;
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

.btn-primario:hover:not(:disabled) {
  background: var(--primary-hover);
}

.btn-secundario {
  border: 1px solid var(--border-strong);
  background: var(--surface);
  color: var(--text);
}

.btn-secundario:hover:not(:disabled) {
  background: var(--surface-hover);
}

.filtros {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  padding: 1rem;
  margin-bottom: 1.25rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
}

.campo {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  flex: 1 1 240px;
}

.campo label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
}

.campo select,
.campo input {
  padding: 0.625rem 0.875rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-sm);
  background: var(--surface);
  color: var(--text);
  font-size: 0.9375rem;
}

.campo select:focus,
.campo input:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: var(--focus-ring);
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
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
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

.kpi-valor.ausente {
  color: var(--danger-text);
}

.kpi-valor.justificado {
  color: var(--warning-text);
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

.sin-clases {
  margin-bottom: 1rem;
  color: var(--text-muted);
}

.tabla-scroll {
  overflow-x: auto;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
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
  position: sticky;
  top: 0;
  background: var(--surface-2);
  color: var(--text-muted);
  font-weight: 600;
}

.col-alumno {
  position: sticky;
  left: 0;
  z-index: 1;
  min-width: 200px;
  text-align: left !important;
  background: var(--surface);
  font-weight: 400;
}

thead .col-alumno {
  z-index: 2;
  background: var(--surface-2);
}

.apellido {
  font-weight: 600;
}

.badge-baja {
  margin-left: 0.375rem;
  padding: 0 0.375rem;
  border-radius: 999px;
  font-size: 0.6875rem;
  background: var(--surface-hover);
  color: var(--text-muted);
}

.col-dia {
  min-width: 34px;
  line-height: 1.2;
}

.col-dia span {
  display: block;
}

.dia-semana {
  font-size: 0.6875rem;
  font-weight: 500;
  text-transform: capitalize;
}

.col-total {
  font-weight: 600;
  background: var(--surface-2);
}

.celda {
  font-weight: 700;
  color: var(--text-subtle);
}

.celda.presente {
  color: var(--success-text);
}

.celda.ausente {
  color: var(--danger-text);
  background: var(--danger-soft);
}

.celda.justificado {
  color: var(--warning-text);
  background: var(--warning-soft);
}

.obs-marca {
  color: var(--primary-text);
  font-weight: 700;
}

tr.riesgo .col-alumno,
tr.riesgo .porcentaje {
  color: var(--danger-text);
}

tr.riesgo .col-alumno {
  box-shadow: inset 3px 0 0 var(--danger);
}

tfoot th,
tfoot td {
  border-bottom: none;
  background: var(--surface-2);
  font-weight: 600;
}

.celda-pie {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.leyenda {
  margin-top: 0.75rem;
  font-size: 0.75rem;
  color: var(--text-muted);
  line-height: 2;
}

.chip {
  display: inline-block;
  min-width: 20px;
  margin-left: 0.5rem;
  border-radius: 4px;
  text-align: center;
  font-weight: 700;
  background: var(--surface-hover);
}

.chip.presente {
  color: var(--success-text);
  background: var(--success-soft);
}

.chip.ausente {
  color: var(--danger-text);
  background: var(--danger-soft);
}

.chip.justificado {
  color: var(--warning-text);
  background: var(--warning-soft);
}

@media (max-width: 600px) {
  .page-content {
    padding: 1rem;
  }

  .col-alumno {
    min-width: 150px;
  }
}

@media print {
  .reporte-page :deep(.page-header) {
    display: none;
  }

  .page-content {
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

  .kpis {
    grid-template-columns: repeat(5, 1fr);
  }

  .kpi {
    padding: 0.5rem 0.75rem;
  }

  .kpi-valor {
    font-size: 1.25rem;
  }

  .tabla-scroll {
    overflow: visible;
    border: none;
  }

  .tabla {
    font-size: 0.6875rem;
  }

  .tabla th,
  .tabla td {
    padding: 0.25rem;
    border: 1px solid #ccc;
  }

  .col-alumno {
    position: static;
    min-width: 0;
  }

  .tabla thead th {
    position: static;
  }

  * {
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
}
</style>
