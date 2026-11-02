<script setup>
// Calendario escolar (0019): feriados, días sin clases, eventos y exámenes.
// Lo ven todos; el admin carga cualquier cosa y el docente eventos/exámenes
// de sus cursos. Los feriados y días sin clases no cuentan en los reportes.
import { ref, computed, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import {
  listarCalendario,
  crearEntrada,
  eliminarEntrada,
  cursosPropios,
  esEsquemaFaltante,
} from '@/lib/api/calendario'
import { cursosDelUsuario } from '@/lib/api/cursos'
import { TIPOS_CALENDARIO, agruparPorMes, generarIcs } from '@/lib/calendario'
import { descargarArchivo } from '@/lib/exportar'
import { hoyLocal, sumarDias, formatearFecha, nombreDelMes } from '@/lib/fecha'

const { state, esAdmin, esDocente } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const hoy = hoyLocal()
const desde = sumarDias(hoy, -7)
const hasta = sumarDias(hoy, 240)

const entradas = ref([])
const cursos = ref([]) // para el formulario
const misCursos = ref(null) // familia/alumno: Set de cursos que le importan
const cargando = ref(true)
const faltaMigracion = ref(false)
const guardando = ref(false)

const puedeEditar = computed(() => esAdmin() || esDocente())
const tipos = computed(() =>
  Object.entries(TIPOS_CALENDARIO).filter(([, t]) => esAdmin() || !t.sinClases),
)

const vacio = () => ({
  tipo: esAdmin() ? 'feriado' : 'examen',
  titulo: '',
  desde: hoy,
  hasta: '',
  cursoId: '',
})
const form = ref(vacio())
const formValido = computed(
  () =>
    form.value.titulo.trim().length >= 2 &&
    form.value.desde &&
    (!form.value.hasta || form.value.hasta >= form.value.desde) &&
    (esAdmin() || form.value.cursoId),
)

const visibles = computed(() =>
  entradas.value.filter((e) => !misCursos.value || !e.curso_id || misCursos.value.has(e.curso_id)),
)
const porMes = computed(() => agruparPorMes(visibles.value))

onMounted(async () => {
  try {
    const tareas = [listarCalendario({ desde, hasta })]
    if (puedeEditar.value) {
      tareas.push(
        cursosDelUsuario({ esAdmin: esAdmin(), profesorId: state.datosUsuario?.id }).then(
          (c) => (cursos.value = c),
        ),
      )
    } else {
      tareas.push(cursosPropios().then((ids) => (misCursos.value = new Set(ids))))
    }
    const [lista] = await Promise.all(tareas)
    entradas.value = lista
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudo cargar el calendario', e)
  } finally {
    cargando.value = false
  }
})

async function guardar() {
  if (!formValido.value) return
  guardando.value = true
  try {
    await crearEntrada(form.value)
    entradas.value = await listarCalendario({ desde, hasta })
    form.value = { ...vacio(), tipo: form.value.tipo }
    toast.exito('Agregado al calendario')
  } catch (e) {
    toast.error('No se pudo guardar', e)
  } finally {
    guardando.value = false
  }
}

function puedeBorrar(e) {
  return esAdmin() || (esDocente() && e.creado_por === state.user?.id)
}

async function borrar(e) {
  const ok = await confirmar({
    titulo: `¿Quitar "${e.titulo}" del calendario?`,
    aceptar: 'Quitar',
    peligro: true,
  })
  if (!ok) return
  try {
    await eliminarEntrada(e.id)
    entradas.value = entradas.value.filter((x) => x.id !== e.id)
  } catch (err) {
    toast.error('No se pudo quitar', err)
  }
}

function exportar() {
  descargarArchivo(
    'calendario-edugest.ics',
    generarIcs(visibles.value, { nombre: 'EduGest · Calendario escolar' }),
    'text/calendar;charset=utf-8',
  )
}

function rango(e) {
  const corto = { weekday: 'short', day: 'numeric', month: 'short' }
  if (e.desde === e.hasta) return formatearFecha(e.desde, corto)
  return `${formatearFecha(e.desde, corto)} – ${formatearFecha(e.hasta, corto)}`
}

function tituloMes(mes) {
  const [a, m] = mes.split('-').map(Number)
  return nombreDelMes(a, m)
}
</script>

<template>
  <div class="calendario-page">
    <PageHeader
      titulo="Calendario escolar"
      subtitulo="Feriados, días sin clases, eventos y exámenes"
    />

    <div class="contenedor">
      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="faltaMigracion"
        title="El calendario todavía no está habilitado"
        hint="Falta aplicar la migración 0019_calendario_y_tarde.sql."
      />

      <template v-else>
        <form v-if="puedeEditar" class="tarjeta formulario" @submit.prevent="guardar">
          <h2>Agregar al calendario</h2>
          <div class="fila">
            <div class="campo">
              <label for="cal-tipo">Tipo</label>
              <select id="cal-tipo" v-model="form.tipo" class="input">
                <option v-for="[valor, t] in tipos" :key="valor" :value="valor">
                  {{ t.texto }}
                </option>
              </select>
            </div>
            <div class="campo titulo">
              <label for="cal-titulo">Título</label>
              <input
                id="cal-titulo"
                v-model="form.titulo"
                class="input"
                type="text"
                maxlength="150"
                placeholder="Ej: Día de la Independencia"
              />
            </div>
            <div class="campo">
              <label for="cal-desde">Desde</label>
              <input id="cal-desde" v-model="form.desde" class="input" type="date" required />
            </div>
            <div class="campo">
              <label for="cal-hasta">Hasta (opcional)</label>
              <input
                id="cal-hasta"
                v-model="form.hasta"
                class="input"
                type="date"
                :min="form.desde"
              />
            </div>
            <div class="campo">
              <label for="cal-curso">Curso</label>
              <select id="cal-curso" v-model="form.cursoId" class="input">
                <option v-if="esAdmin()" value="">Toda la institución</option>
                <option v-else value="" disabled>Elegí un curso</option>
                <option v-for="c in cursos" :key="c.id" :value="c.id">{{ c.nombre }}</option>
              </select>
            </div>
          </div>
          <div class="acciones">
            <span class="texto-muted chico">
              <template v-if="TIPOS_CALENDARIO[form.tipo]?.sinClases">
                Ese día no se toma lista y no cuenta en los reportes.
              </template>
            </span>
            <button type="submit" class="btn btn-primario" :disabled="!formValido || guardando">
              {{ guardando ? 'Guardando...' : 'Agregar' }}
            </button>
          </div>
        </form>

        <div class="barra">
          <button
            type="button"
            class="btn btn-secundario btn-chico"
            :disabled="!visibles.length"
            @click="exportar"
          >
            Agregar a mi calendario (.ics)
          </button>
        </div>

        <EmptyState
          v-if="!visibles.length"
          title="No hay nada cargado en el calendario"
          hint="Cuando la institución cargue feriados, eventos o exámenes, aparecen acá."
        />

        <section v-for="m in porMes" :key="m.mes" class="mes">
          <h2>{{ tituloMes(m.mes) }}</h2>
          <ul class="lista">
            <li
              v-for="e in m.eventos"
              :key="e.id"
              :class="['tarjeta', 'entrada', e.tipo, { pasada: e.hasta < hoy }]"
            >
              <span class="fecha">{{ rango(e) }}</span>
              <div class="detalle">
                <strong>{{ e.titulo }}</strong>
                <span class="texto-muted chico">
                  {{ TIPOS_CALENDARIO[e.tipo]?.texto }} ·
                  {{ e.cursos?.nombre ?? 'Toda la institución' }}
                </span>
              </div>
              <button
                v-if="puedeBorrar(e)"
                type="button"
                class="quitar"
                :aria-label="`Quitar ${e.titulo}`"
                @click="borrar(e)"
              >
                ✕
              </button>
            </li>
          </ul>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.calendario-page {
  min-height: calc(100vh - var(--navbar-height));
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.formulario {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.25rem;
  margin-bottom: 1.25rem;
}

.formulario h2 {
  font-size: 1.0625rem;
  font-weight: 700;
}

.fila {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 0.75rem;
}

.titulo {
  grid-column: span 2;
}

.acciones {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.chico {
  font-size: 0.8125rem;
}

.barra {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 1rem;
}

.mes {
  margin-bottom: 1.5rem;
}

.mes h2 {
  font-size: 1rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.entrada {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1rem;
  border-left: 4px solid var(--primary);
}

.entrada.feriado,
.entrada.sin_clases {
  border-left-color: var(--danger);
}

.entrada.examen {
  border-left-color: var(--warning);
}

.entrada.pasada {
  opacity: 0.6;
}

.fecha {
  min-width: 9rem;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
  text-transform: capitalize;
}

.detalle {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  flex: 1;
  min-width: 0;
}

.quitar {
  border: none;
  background: none;
  color: var(--text-muted);
  cursor: pointer;
}

@media (max-width: 560px) {
  .titulo {
    grid-column: auto;
  }

  .entrada {
    flex-wrap: wrap;
  }
}
</style>
