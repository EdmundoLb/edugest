<script setup>
// Constancia de asistencia imprimible de un alumno en un período. La pueden
// emitir el personal, la familia del alumno o el propio alumno: RLS decide
// si se ven los datos. "Tarde" cuenta como presente.
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { asistenciaDeAlumno } from '@/lib/api/historial'
import { normalizarRegistro, combinarPorDia, contar, resumirPorCurso } from '@/lib/historial'
import { hoyLocal, formatearFecha } from '@/lib/fecha'

const route = useRoute()
const router = useRouter()
const { state } = useAuth()
const toast = useToast()

const hoy = hoyLocal()
const esFecha = (v) => /^\d{4}-\d{2}-\d{2}$/.test(v ?? '')

const desde = ref(esFecha(route.query.desde) ? route.query.desde : `${hoy.slice(0, 4)}-01-01`)
const hasta = ref(esFecha(route.query.hasta) ? route.query.hasta : hoy)

const alumno = ref(null)
const dias = ref([])
const cargando = ref(true)

const totales = computed(() => contar(dias.value))
const porCurso = computed(() => resumirPorCurso(dias.value))
const emisor = computed(() => {
  const p = state.perfil
  return p ? `${p.nombre ?? ''} ${p.apellido ?? ''}`.trim() : ''
})

const larga = (f) => formatearFecha(f, { day: 'numeric', month: 'long', year: 'numeric' })
const pct = (v) => (v === null || v === undefined ? '—' : `${v}%`)

watch(
  [() => route.params.id, desde, hasta],
  async () => {
    if (desde.value > hasta.value) [desde.value, hasta.value] = [hasta.value, desde.value]
    router.replace({ query: { desde: desde.value, hasta: hasta.value } })
    await cargar()
  },
  { immediate: true },
)

function imprimir() {
  window.print()
}

async function cargar() {
  cargando.value = true
  try {
    const [{ data, error }, filas] = await Promise.all([
      supabase
        .from('alumnos')
        .select('id, nombre, apellido, ci')
        .eq('id', route.params.id)
        .maybeSingle(),
      asistenciaDeAlumno(route.params.id, { desde: desde.value, hasta: hasta.value }),
    ])
    if (error) throw error
    alumno.value = data
    dias.value = combinarPorDia(filas.map(normalizarRegistro))
  } catch (e) {
    toast.error('No se pudo armar la constancia', e)
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="constancia-page">
    <div class="contenedor">
      <div class="controles no-print">
        <button type="button" class="btn btn-secundario btn-chico" @click="router.back()">
          ← Volver
        </button>
        <div class="campo">
          <label for="con-desde">Desde</label>
          <input id="con-desde" v-model="desde" class="input" type="date" :max="hoy" />
        </div>
        <div class="campo">
          <label for="con-hasta">Hasta</label>
          <input id="con-hasta" v-model="hasta" class="input" type="date" :max="hoy" />
        </div>
        <button
          type="button"
          class="btn btn-primario"
          :disabled="cargando || !alumno"
          @click="imprimir"
        >
          Imprimir / guardar PDF
        </button>
      </div>

      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="!alumno"
        title="No encontramos a este alumno"
        hint="O no tenés permiso para ver su asistencia."
      />

      <article v-else class="tarjeta documento">
        <header class="encabezado">
          <img src="@/images/edugest-logo.png" alt="" class="logo" />
          <div>
            <p class="institucion">EduGest</p>
            <h1>Constancia de asistencia</h1>
          </div>
        </header>

        <p class="texto">
          Se deja constancia de que <strong>{{ alumno.nombre }} {{ alumno.apellido }}</strong
          >, C.I. <strong>{{ alumno.ci }}</strong
          >, registra la siguiente asistencia entre el {{ larga(desde) }} y el {{ larga(hasta) }}:
        </p>

        <table class="tabla">
          <thead>
            <tr>
              <th scope="col" class="izq">Curso</th>
              <th scope="col">Clases</th>
              <th scope="col">Presente</th>
              <th scope="col">Tarde</th>
              <th scope="col">Ausente</th>
              <th scope="col">Justificado</th>
              <th scope="col">Asistencia</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in porCurso" :key="c.cursoId">
              <th scope="row" class="izq">{{ c.cursoNombre }}</th>
              <td>{{ c.total }}</td>
              <td>{{ c.presentes - c.tardes }}</td>
              <td>{{ c.tardes }}</td>
              <td>{{ c.ausentes }}</td>
              <td>{{ c.justificados }}</td>
              <td>
                <strong>{{ pct(c.porcentaje) }}</strong>
              </td>
            </tr>
            <tr v-if="!porCurso.length">
              <td colspan="7" class="vacio">Sin clases registradas en el período.</td>
            </tr>
          </tbody>
          <tfoot v-if="porCurso.length > 1">
            <tr>
              <th scope="row" class="izq">Total</th>
              <td>{{ totales.total }}</td>
              <td>{{ totales.presentes - totales.tardes }}</td>
              <td>{{ totales.tardes }}</td>
              <td>{{ totales.ausentes }}</td>
              <td>{{ totales.justificados }}</td>
              <td>
                <strong>{{ pct(totales.porcentaje) }}</strong>
              </td>
            </tr>
          </tfoot>
        </table>

        <p class="nota">
          Asistencia = días presentes (incluidas las llegadas tarde) sobre las clases dictadas, sin
          contar las faltas justificadas. No se cuentan feriados ni días sin clases.
        </p>

        <p class="texto">
          Se extiende la presente el {{ larga(hoy)
          }}<template v-if="emisor"> a pedido de {{ emisor }}</template
          >, a los efectos que corresponda.
        </p>

        <div class="firmas">
          <div class="firma">Firma</div>
          <div class="firma">Sello de la institución</div>
        </div>

        <p class="pie">
          Documento generado por el sistema EduGest. Para tener validez oficial debe llevar firma y
          sello de la institución.
        </p>
      </article>
    </div>
  </div>
</template>

<style scoped>
.constancia-page {
  min-height: calc(100vh - var(--navbar-height));
}

.controles {
  display: flex;
  align-items: flex-end;
  gap: 0.75rem;
  flex-wrap: wrap;
  margin-bottom: 1.25rem;
}

.controles .campo {
  width: 160px;
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.documento {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  max-width: 820px;
  margin: 0 auto;
  padding: 2.5rem;
}

.encabezado {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding-bottom: 1rem;
  border-bottom: 2px solid var(--border-strong);
}

.logo {
  width: 64px;
  height: auto;
}

.institucion {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.encabezado h1 {
  font-size: 1.5rem;
  font-weight: 800;
}

.texto {
  line-height: 1.7;
}

.tabla {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9375rem;
}

.tabla th,
.tabla td {
  padding: 0.5rem 0.625rem;
  border-bottom: 1px solid var(--border);
  text-align: center;
}

.tabla .izq {
  text-align: left;
}

.tabla thead th {
  font-size: 0.75rem;
  text-transform: uppercase;
  color: var(--text-muted);
}

.tabla tfoot th,
.tabla tfoot td {
  border-top: 2px solid var(--border-strong);
  font-weight: 700;
}

.vacio {
  color: var(--text-muted);
}

.nota,
.pie {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.firmas {
  display: flex;
  justify-content: space-around;
  gap: 2rem;
  margin-top: 3rem;
}

.firma {
  width: 220px;
  padding-top: 0.5rem;
  border-top: 1px solid var(--text);
  text-align: center;
  font-size: 0.875rem;
}

@media print {
  .contenedor {
    padding: 0;
  }

  .documento {
    border: none;
    box-shadow: none;
    padding: 0;
  }
}

@media (max-width: 560px) {
  .documento {
    padding: 1.25rem;
  }

  .tabla {
    font-size: 0.8125rem;
  }
}
</style>
