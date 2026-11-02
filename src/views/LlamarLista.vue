<script setup>
import PageHeader from '@/components/PageHeader.vue'
import AlumnoAsistenciaFila from '@/components/AlumnoAsistenciaFila.vue'
import ListaUnoPorUno from '@/components/ListaUnoPorUno.vue'
import EmptyState from '@/components/EmptyState.vue'
import AppButton from '@/components/ui/AppButton.vue'
import AppIcon from '@/components/ui/AppIcon.vue'
import AppSegmented from '@/components/ui/AppSegmented.vue'
import AppSkeleton from '@/components/ui/AppSkeleton.vue'
import AppProgressBar from '@/components/ui/AppProgressBar.vue'
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, onBeforeRouteLeave } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { hoyLocal, diaSemanaDeFecha, formatearFecha, formatearHora } from '@/lib/fecha'
import { formatearDias, indiceDia, ordenarPorDia } from '@/lib/dias'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import { esEsquemaFaltante } from '@/lib/api/reportes'
import { justificacionesVigentes } from '@/lib/api/justificaciones'
import { solicitudesPendientesEnFecha } from '@/lib/api/solicitudes'
import { avisosDelDia } from '@/lib/solicitudes'
import { listarCalendario } from '@/lib/api/calendario'
import { diaSinClases } from '@/lib/calendario'
import { useListaOffline } from '@/composables/useListaOffline'
import {
  esErrorDeRed,
  claveLista,
  leerAlumnosCache,
  guardarAlumnosCache,
  leerHorariosCache,
  guardarHorariosCache,
} from '@/lib/listaOffline'
import { contarEstados, resumenCorto } from '@/lib/lista'
import { colorDeCurso } from '@/lib/ui'

const route = useRoute()
const { state } = useAuth()
const toast = useToast()
const confirmar = useConfirm()
const { pendientes, encolar, sincronizar } = useListaOffline()

const loading = ref(true)
const loadingAlumnos = ref(false)
const guardando = ref(false)
const remitiendo = ref(false)

const horarios = ref([])
const cursoId = ref(null)
const fecha = ref(hoyLocal())
const alumnos = ref([])
const avisos = ref(new Map()) // alumnoId -> motivo del aviso pendiente de la familia
const asistencia = ref({})
const observaciones = ref({})
const asistenciaGuardada = ref(false)
const informeRemitido = ref(null)
const busqueda = ref('')
const sinConexion = ref(false) // la lista se armó con la copia guardada en el dispositivo
const diaLibre = ref(null) // feriado o día sin clases del calendario (0019)
const tomarIgual = ref(false)

// Foto de lo último cargado/guardado, para saber si hay cambios sin guardar.
const snapshot = ref('')

const profesorId = computed(() => state.datosUsuario?.id ?? null)

const cursos = computed(() => {
  const vistos = new Set()
  return horarios.value
    .map((h) => h.cursos)
    .filter((c) => c && !vistos.has(c.id) && vistos.add(c.id))
    .sort((a, b) => a.nombre.localeCompare(b.nombre))
})

const cursoSeleccionado = computed(() => cursos.value.find((c) => c.id === cursoId.value) ?? null)

const horariosDelCurso = computed(() =>
  horarios.value.filter((h) => h.cursos?.id === cursoId.value),
)

const horarioDelDia = computed(() => {
  if (!cursoId.value) return null
  const indice = indiceDia(diaSemanaDeFecha(fecha.value))
  return horariosDelCurso.value.find((h) => indiceDia(h.dia_semana) === indice) ?? null
})

const diasDelCurso = computed(() => formatearDias(horariosDelCurso.value.map((h) => h.dia_semana)))

function estadoActual() {
  return JSON.stringify({ a: asistencia.value, o: observaciones.value })
}

// Cambios hechos por el usuario desde la última carga/guardado (para avisar
// antes de perderlos).
const hayCambios = computed(() => alumnos.value.length > 0 && estadoActual() !== snapshot.value)
// Una lista nueva (todos presentes por defecto) también falta guardarla,
// aunque el usuario no haya tocado nada.
const faltaGuardar = computed(
  () => hayCambios.value || (alumnos.value.length > 0 && !asistenciaGuardada.value),
)

const alumnosFiltrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  if (!q) return alumnos.value
  return alumnos.value.filter((a) => `${a.nombre} ${a.apellido}`.toLowerCase().includes(q))
})

const totales = computed(() => contarEstados(alumnos.value, asistencia.value))

// Barra apilada del resumen: cuántos hay en cada estado.
const segmentos = computed(() => [
  { valor: totales.value.presente, tono: 'presente' },
  { valor: totales.value.tarde, tono: 'tarde' },
  { valor: totales.value.justificado, tono: 'justificado' },
  { valor: totales.value.ausente, tono: 'ausente' },
])

const fechaTexto = computed(() => {
  const texto = formatearFecha(fecha.value, { weekday: 'long', day: 'numeric', month: 'long' })
  return fecha.value === hoyLocal()
    ? `Hoy, ${texto}`
    : texto.charAt(0).toUpperCase() + texto.slice(1)
})

// "Lista" (todas las filas) o "Uno por uno" (una tarjeta por alumno). Se
// recuerda en el dispositivo.
const CLAVE_MODO = 'edugest:lista-modo'
const MODOS = [
  { valor: 'lista', texto: 'Lista', icono: 'lista' },
  { valor: 'uno', texto: 'Uno por uno', icono: 'usuario' },
]
const modo = ref(leerModo())
watch(modo, (m) => {
  try {
    localStorage.setItem(CLAVE_MODO, m)
  } catch {
    // Sin almacenamiento (modo privado): no se recuerda, nada más.
  }
})

function leerModo() {
  try {
    return localStorage.getItem(CLAVE_MODO) === 'uno' ? 'uno' : 'lista'
  } catch {
    return 'lista'
  }
}

function marcarAlumno(id, estado) {
  asistencia.value[id] = estado
}

onMounted(async () => {
  window.addEventListener('beforeunload', avisarAlCerrar)
  await cargarHorarios()

  let id = route.query.curso
  if (!id && route.query.horario) {
    id = horarios.value.find((h) => h.id === route.query.horario)?.cursos?.id
  }
  if (id && cursos.value.some((c) => c.id === id)) {
    cursoId.value = id
  } else if (cursos.value.length === 1) {
    cursoId.value = cursos.value[0].id
  }
})

onUnmounted(() => {
  window.removeEventListener('beforeunload', avisarAlCerrar)
})

function avisarAlCerrar(e) {
  if (hayCambios.value) {
    e.preventDefault()
    e.returnValue = ''
  }
}

async function confirmarDescartar() {
  if (!hayCambios.value) return true
  return confirmar({
    titulo: '¿Descartar los cambios?',
    mensaje: 'Hay asistencia marcada que todavía no guardaste. Si seguís, se pierde.',
    aceptar: 'Descartar cambios',
    cancelar: 'Seguir editando',
    peligro: true,
  })
}

onBeforeRouteLeave(confirmarDescartar)

// Los chips de curso y el <input type="date"> no usan v-model directo:
// primero se pregunta si descartar cambios, y si el usuario cancela se vuelve
// el control a su valor anterior.
async function elegirCurso(id) {
  if (id !== cursoId.value && (await confirmarDescartar())) cursoId.value = id
}

async function cambiarFecha(e) {
  const nueva = e.target.value
  if (!nueva) {
    e.target.value = fecha.value
    return
  }
  if (await confirmarDescartar()) {
    fecha.value = nueva
  } else {
    e.target.value = fecha.value
  }
}

async function irAHoy() {
  if (fecha.value !== hoyLocal() && (await confirmarDescartar())) {
    fecha.value = hoyLocal()
  }
}

watch([cursoId, fecha], cargarAlumnos)

async function cargarHorarios() {
  loading.value = true
  try {
    if (!profesorId.value) return
    const { data, error } = await supabase
      .from('horarios')
      .select('id, dia_semana, hora_inicio, hora_fin, turno, cursos (id, nombre)')
      .eq('profesor_id', profesorId.value)
    if (error) {
      const copia = esErrorDeRed(error) && leerHorariosCache(profesorId.value)
      if (!copia) throw error
      horarios.value = copia
      sinConexion.value = true
      return
    }
    horarios.value = ordenarPorDia(data || [])
    guardarHorariosCache(profesorId.value, horarios.value)
  } catch (e) {
    toast.error('No se pudieron cargar tus horarios', e)
  } finally {
    loading.value = false
  }
}

async function cargarAlumnos() {
  alumnos.value = []
  asistencia.value = {}
  observaciones.value = {}
  informeRemitido.value = null
  asistenciaGuardada.value = false
  busqueda.value = ''
  diaLibre.value = null
  tomarIgual.value = false
  snapshot.value = estadoActual()

  const horario = horarioDelDia.value
  if (!horario) return

  loadingAlumnos.value = true
  try {
    const [inscripciones, existente, informe, calendario] = await Promise.all([
      inscriptosEnFecha(),
      supabase
        .from('asistencia')
        .select('alumno_id, estado, observacion')
        .eq('horario_id', horario.id)
        .eq('fecha', fecha.value),
      supabase
        .from('informes_asistencia')
        .select('*')
        .eq('horario_id', horario.id)
        .eq('fecha', fecha.value)
        .maybeSingle(),
      // Sin 0019 (o sin red) no hay calendario: se toma lista igual.
      listarCalendario({ desde: fecha.value, hasta: fecha.value }).catch(() => []),
    ])
    if (esErrorDeRed(inscripciones.error) || esErrorDeRed(existente.error)) {
      cargarSinConexion(horario)
      return
    }
    sinConexion.value = false
    diaLibre.value = diaSinClases(calendario, fecha.value, cursoId.value)
    if (inscripciones.error) throw inscripciones.error
    if (existente.error) throw existente.error

    alumnos.value = (inscripciones.data || [])
      .map((i) => i.alumnos)
      .filter(Boolean)
      .sort((a, b) => a.apellido.localeCompare(b.apellido) || a.nombre.localeCompare(b.nombre))

    guardarAlumnosCache(cursoId.value, alumnos.value)

    const previos = new Map((existente.data || []).map((r) => [r.alumno_id, r]))
    asistenciaGuardada.value = previos.size > 0

    // Alumnos con una justificación vigente (certificado, permiso) para hoy.
    const justificados = new Map(
      (await justificacionesDelDia(alumnos.value.map((a) => a.id))).map((j) => [
        j.alumno_id,
        j.motivo,
      ]),
    )

    avisos.value = await avisosFamiliaDelDia(alumnos.value.map((a) => a.id))

    const nuevaAsistencia = {}
    const nuevasObservaciones = {}
    alumnos.value.forEach((a) => {
      const previo = previos.get(a.id)
      if (previo) {
        nuevaAsistencia[a.id] = previo.estado
        nuevasObservaciones[a.id] = previo.observacion ?? ''
      } else if (justificados.has(a.id)) {
        nuevaAsistencia[a.id] = 'justificado'
        nuevasObservaciones[a.id] = `Justificado: ${justificados.get(a.id)}`
      } else {
        // Primera pasada de lista: todos presentes por defecto.
        nuevaAsistencia[a.id] = 'presente'
        nuevasObservaciones[a.id] = ''
      }
    })
    asistencia.value = nuevaAsistencia
    observaciones.value = nuevasObservaciones
    informeRemitido.value = informe.data ?? null

    snapshot.value = estadoActual()
  } catch (e) {
    toast.error('No se pudieron cargar los alumnos', e)
  } finally {
    loadingAlumnos.value = false
  }
}

// Inscriptos que corresponden a la fecha elegida: los activos, y los dados
// de baja después de esa fecha (para poder corregir una lista vieja). Sin la
// migración 0012 no hay bajas: se traen todos.
async function inscriptosEnFecha() {
  const consulta = () =>
    supabase
      .from('inscripciones')
      .select('alumnos (id, nombre, apellido)')
      .eq('curso_id', cursoId.value)
  const respuesta = await consulta().or(`activa.eq.true,fecha_baja.gt.${fecha.value}`)
  if (respuesta.error && esEsquemaFaltante(respuesta.error)) return consulta()
  return respuesta
}

async function justificacionesDelDia(alumnoIds) {
  try {
    return await justificacionesVigentes({ alumnoIds, cursoId: cursoId.value, fecha: fecha.value })
  } catch (e) {
    // Sin 0012 no hay justificaciones: la lista se toma igual.
    if (!esEsquemaFaltante(e)) toast.error('No se pudieron consultar las justificaciones', e)
    return []
  }
}

// Avisos de la familia todavía sin aprobar para esta fecha (si ya se aprobaron
// son justificaciones y premarcan 'justificado'). Sin 0014: ninguno.
async function avisosFamiliaDelDia(alumnoIds) {
  try {
    const pendientes = await solicitudesPendientesEnFecha({ alumnoIds, fecha: fecha.value })
    return avisosDelDia(pendientes, { fecha: fecha.value, cursoId: cursoId.value })
  } catch (e) {
    if (!esEsquemaFaltante(e)) console.error(e)
    return new Map()
  }
}

// Sin red: la lista sale de la última copia guardada en el dispositivo. Si
// ya había una lista pendiente de enviar para ese día, se retoma esa.
function cargarSinConexion(horario) {
  const copia = leerAlumnosCache(cursoId.value)
  sinConexion.value = true
  if (!copia?.length) {
    toast.error(
      'Sin conexión, y este curso nunca se abrió en este dispositivo. Conectate una vez para poder tomar lista offline.',
    )
    return
  }
  const pendiente = pendientes.value.find(
    (p) => claveLista(p.horarioId, p.fecha) === claveLista(horario.id, fecha.value),
  )
  const previos = new Map((pendiente?.registros ?? []).map((r) => [r.alumno_id, r]))
  alumnos.value = copia
  asistencia.value = Object.fromEntries(
    copia.map((a) => [a.id, previos.get(a.id)?.estado ?? 'presente']),
  )
  observaciones.value = Object.fromEntries(
    copia.map((a) => [a.id, previos.get(a.id)?.observacion ?? '']),
  )
  asistenciaGuardada.value = Boolean(pendiente)
  snapshot.value = estadoActual()
}

function guardarSinConexion(entrada) {
  encolar(entrada)
  sinConexion.value = true
  asistenciaGuardada.value = true
  snapshot.value = estadoActual()
  toast.info(
    'Sin conexión: la lista quedó guardada en este dispositivo y se envía sola cuando vuelva internet.',
  )
}

async function guardarAsistencia() {
  if (!horarioDelDia.value || alumnos.value.length === 0) return

  guardando.value = true
  try {
    const registros = alumnos.value.map((alumno) => ({
      horario_id: horarioDelDia.value.id,
      alumno_id: alumno.id,
      fecha: fecha.value,
      estado: asistencia.value[alumno.id] || 'presente',
      observacion: observaciones.value[alumno.id]?.trim() || null,
    }))

    const entrada = {
      horarioId: horarioDelDia.value.id,
      fecha: fecha.value,
      cursoNombre: cursoSeleccionado.value?.nombre ?? '',
      registros,
    }
    if (!navigator.onLine) {
      guardarSinConexion(entrada)
      return
    }
    const { error } = await supabase
      .from('asistencia')
      .upsert(registros, { onConflict: 'horario_id,alumno_id,fecha' })
    if (esErrorDeRed(error)) {
      guardarSinConexion(entrada)
      return
    }
    if (error) throw error

    asistenciaGuardada.value = true
    snapshot.value = estadoActual()
    toast.exito(
      informeRemitido.value
        ? 'Asistencia actualizada. Volvé a remitir el informe para que administración vea los cambios.'
        : 'Asistencia guardada',
    )
  } catch (e) {
    toast.error('No se pudo guardar la asistencia', e)
  } finally {
    guardando.value = false
  }
}

async function remitirInforme() {
  if (!horarioDelDia.value || !profesorId.value) return

  remitiendo.value = true
  try {
    const { data, error } = await supabase
      .from('informes_asistencia')
      .upsert(
        {
          horario_id: horarioDelDia.value.id,
          fecha: fecha.value,
          profesor_id: profesorId.value,
          estado: 'pendiente',
          creado_at: new Date().toISOString(),
        },
        { onConflict: 'horario_id,fecha' },
      )
      .select()
      .single()
    if (error) throw error

    informeRemitido.value = data
    toast.exito('Informe remitido a administración')
  } catch (e) {
    toast.error('No se pudo remitir el informe', e)
  } finally {
    remitiendo.value = false
  }
}

function marcarTodos(estado) {
  alumnos.value.forEach((a) => {
    asistencia.value[a.id] = estado
  })
}
</script>

<template>
  <div class="lista-page">
    <PageHeader titulo="Llamar lista" :subtitulo="fechaTexto" volver="/ProfesorDashboard" />

    <div class="page-content">
      <div v-if="loading" class="cargando" aria-busy="true" aria-label="Cargando tus cursos">
        <div class="chips">
          <AppSkeleton v-for="n in 3" :key="n" forma="bloque" ancho="140px" alto="44px" />
        </div>
        <AppSkeleton v-for="n in 6" :key="`f${n}`" forma="bloque" alto="64px" />
      </div>

      <EmptyState
        v-else-if="cursos.length === 0"
        icono="cursos"
        title="Todavía no tenés cursos asignados"
        hint="Pedile a administración que te asigne un horario."
      />

      <template v-else>
        <section class="controles" aria-label="Curso y fecha">
          <div class="chips" role="radiogroup" aria-label="Curso">
            <button
              v-for="c in cursos"
              :key="c.id"
              type="button"
              role="radio"
              :aria-checked="c.id === cursoId"
              :class="[
                'chip-curso',
                `chip-curso--${colorDeCurso(c.id)}`,
                { activo: c.id === cursoId },
              ]"
              :disabled="loadingAlumnos || guardando"
              @click="elegirCurso(c.id)"
            >
              <span class="chip-punto" aria-hidden="true" />
              {{ c.nombre }}
            </button>
          </div>

          <div class="fecha-fila">
            <label class="sr-only" for="fecha">Fecha</label>
            <input
              id="fecha"
              type="date"
              class="input fecha"
              :value="fecha"
              :max="hoyLocal()"
              :disabled="loadingAlumnos || guardando"
              @change="cambiarFecha"
            />
            <AppButton
              variante="secundario"
              :disabled="fecha === hoyLocal() || loadingAlumnos || guardando"
              @click="irAHoy"
            >
              Hoy
            </AppButton>
          </div>
        </section>

        <div v-if="sinConexion || pendientes.length" class="aviso-offline" role="status">
          <AppIcon nombre="sin-conexion" :tamano="20" />
          <div class="aviso-offline-texto">
            <span v-if="sinConexion">
              Sin conexión: estás usando la última copia de tus cursos. Lo que guardes queda en este
              dispositivo.
            </span>
            <span v-if="pendientes.length">
              {{
                pendientes.length === 1
                  ? 'Hay 1 lista guardada sin conexión esperando para enviarse.'
                  : `Hay ${pendientes.length} listas guardadas sin conexión esperando para enviarse.`
              }}
            </span>
          </div>
          <AppButton
            v-if="pendientes.length"
            variante="secundario"
            tamano="sm"
            icono="enviar"
            @click="sincronizar()"
          >
            Enviar ahora
          </AppButton>
        </div>

        <p v-if="cursoSeleccionado" class="curso-info">
          <span v-if="horarioDelDia" class="hora">
            <AppIcon nombre="reloj" :tamano="15" />
            {{ formatearHora(horarioDelDia.hora_inicio) }}–{{
              formatearHora(horarioDelDia.hora_fin)
            }}
          </span>
          <span class="dias">
            Días de clase:
            <span v-for="chip in diasDelCurso" :key="chip" class="dia-chip">{{ chip }}</span>
          </span>
        </p>

        <EmptyState
          v-if="!cursoSeleccionado"
          icono="lista"
          title="Elegí un curso para empezar"
          hint="Tocá uno de tus cursos arriba."
        />

        <div
          v-else-if="loadingAlumnos"
          class="cargando"
          aria-busy="true"
          aria-label="Cargando alumnos"
        >
          <AppSkeleton forma="bloque" alto="88px" />
          <AppSkeleton v-for="n in 6" :key="n" forma="bloque" alto="64px" />
        </div>

        <EmptyState
          v-else-if="!horarioDelDia"
          icono="calendario"
          :title="`${cursoSeleccionado.nombre} no tiene clase ese día`"
          :hint="`Elegí otra fecha. Días de clase: ${diasDelCurso.join(', ')}.`"
        />

        <EmptyState
          v-else-if="diaLibre && !tomarIgual"
          icono="calendario"
          :title="`No hay clases: ${diaLibre.titulo}`"
          hint="Está marcado en el calendario escolar. Ese día no cuenta en los reportes."
        >
          <template #action>
            <AppButton variante="secundario" @click="tomarIgual = true">
              Tomar lista igual
            </AppButton>
          </template>
        </EmptyState>

        <EmptyState
          v-else-if="alumnos.length === 0"
          icono="alumnos"
          :title="
            sinConexion
              ? 'Sin conexión y sin una copia de este curso'
              : 'Este curso no tiene alumnos inscriptos'
          "
          :hint="sinConexion ? 'Conectate una vez para poder tomar lista sin internet.' : ''"
        />

        <template v-else>
          <section class="resumen" aria-label="Resumen">
            <div class="resumen-cabecera">
              <div class="contadores" aria-live="polite">
                <span class="contador"
                  ><strong class="num">{{ alumnos.length }}</strong> alumnos</span
                >
                <span class="contador contador--presente"
                  ><strong class="num">{{ totales.presente }}</strong> presentes</span
                >
                <span class="contador contador--ausente"
                  ><strong class="num">{{ totales.ausente }}</strong> ausentes</span
                >
                <span v-if="totales.tarde" class="contador contador--tarde"
                  ><strong class="num">{{ totales.tarde }}</strong> tarde</span
                >
                <span v-if="totales.justificado" class="contador contador--justificado"
                  ><strong class="num">{{ totales.justificado }}</strong> justificados</span
                >
              </div>
              <AppSegmented
                v-model="modo"
                :opciones="MODOS"
                nombre="modo-lista"
                etiqueta="Forma de tomar lista"
                tamano="sm"
              />
            </div>
            <AppProgressBar
              :segmentos="segmentos"
              :alto="8"
              etiqueta="Distribución de la asistencia"
            />
          </section>

          <ListaUnoPorUno
            v-if="modo === 'uno'"
            :key="`${cursoId}-${fecha}`"
            :alumnos="alumnos"
            :asistencia="asistencia"
            :avisos="avisos"
            :deshabilitado="guardando"
            @marcar="marcarAlumno"
            @ver-lista="modo = 'lista'"
          />

          <template v-else>
            <div class="herramientas">
              <div v-if="alumnos.length > 8" class="buscador">
                <AppIcon nombre="buscar" :tamano="18" />
                <input
                  v-model="busqueda"
                  type="search"
                  placeholder="Buscar alumno…"
                  aria-label="Buscar alumno"
                />
              </div>
              <div class="acciones-rapidas">
                <AppButton
                  variante="fantasma"
                  tamano="sm"
                  icono="check"
                  :disabled="guardando"
                  @click="marcarTodos('presente')"
                >
                  Todos presentes
                </AppButton>
                <AppButton
                  variante="fantasma"
                  tamano="sm"
                  icono="cerrar"
                  :disabled="guardando"
                  @click="marcarTodos('ausente')"
                >
                  Todos ausentes
                </AppButton>
              </div>
            </div>
            <p class="ayuda">Tocá a un alumno para alternar entre presente y ausente.</p>

            <div class="lista">
              <AlumnoAsistenciaFila
                v-for="alumno in alumnosFiltrados"
                :key="alumno.id"
                v-model:estado="asistencia[alumno.id]"
                v-model:observacion="observaciones[alumno.id]"
                :alumno="alumno"
                :aviso="avisos.get(alumno.id) ?? ''"
                :deshabilitado="guardando"
              />
              <EmptyState
                v-if="alumnosFiltrados.length === 0"
                compacto
                icono="buscar"
                :title="`Ningún alumno coincide con “${busqueda}”`"
              />
            </div>
          </template>

          <div class="barra-guardar">
            <div class="barra-estado">
              <span v-if="faltaGuardar" class="pendiente">
                <span class="punto" aria-hidden="true" /> Sin guardar
              </span>
              <span v-else-if="informeRemitido" class="ok">
                <AppIcon nombre="check-circulo" :tamano="16" /> Guardada y remitida
              </span>
              <span v-else class="ok">
                <AppIcon nombre="check-circulo" :tamano="16" /> Asistencia guardada
              </span>
            </div>
            <div class="barra-acciones">
              <AppButton
                v-if="!faltaGuardar"
                variante="secundario"
                icono="enviar"
                :cargando="remitiendo"
                @click="remitirInforme"
              >
                {{ informeRemitido ? 'Volver a remitir' : 'Remitir a administración' }}
              </AppButton>
              <AppButton
                v-else
                icono="check"
                :cargando="guardando"
                :disabled="guardando"
                @click="guardarAsistencia"
              >
                {{ guardando ? 'Guardando…' : 'Guardar' }}
                <span v-if="!guardando" class="resumen-boton num"
                  >· {{ resumenCorto(totales) }}</span
                >
              </AppButton>
            </div>
          </div>
        </template>
      </template>
    </div>
  </div>
</template>

<style scoped>
.page-content {
  max-width: 900px;
  margin: 0 auto;
  padding: var(--sp-4) var(--sp-6) 0;
}

.cargando {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}

.controles {
  display: flex;
  flex-direction: column;
  gap: var(--sp-3);
  margin-bottom: var(--sp-3);
}

.chips {
  display: flex;
  gap: var(--sp-2);
  overflow-x: auto;
  margin: 0 calc(var(--sp-6) * -1);
  padding: 2px var(--sp-6) var(--sp-1);
  scrollbar-width: none;
}

.chips::-webkit-scrollbar {
  display: none;
}

.chip-curso {
  --color: var(--curso-1);
  display: inline-flex;
  flex-shrink: 0;
  align-items: center;
  gap: var(--sp-2);
  min-height: 44px;
  padding: 0 var(--sp-4);
  border: 1px solid var(--border);
  border-radius: var(--radius-full);
  background: var(--surface);
  color: var(--text-2);
  font-size: var(--fs-sm);
  font-weight: var(--fw-semibold);
  white-space: nowrap;
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out);
}

.chip-curso:hover:not(:disabled) {
  border-color: var(--border-strong);
  color: var(--text);
}

.chip-curso:focus-visible {
  outline: 2px solid var(--primary-text);
  outline-offset: 2px;
}

.chip-curso.activo {
  border-color: var(--color);
  background: color-mix(in srgb, var(--color) 12%, var(--surface));
  color: var(--text);
}

.chip-curso:disabled {
  cursor: default;
}

.chip-curso--2 {
  --color: var(--curso-2);
}

.chip-curso--3 {
  --color: var(--curso-3);
}

.chip-curso--4 {
  --color: var(--curso-4);
}

.chip-curso--5 {
  --color: var(--curso-5);
}

.chip-curso--6 {
  --color: var(--curso-6);
}

.chip-curso--7 {
  --color: var(--curso-7);
}

.chip-curso--8 {
  --color: var(--curso-8);
}

.chip-punto {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--color);
}

.fecha-fila {
  display: flex;
  gap: var(--sp-2);
  max-width: 360px;
}

.fecha {
  flex: 1;
}

.aviso-offline {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--sp-2) var(--sp-3);
  margin-bottom: var(--sp-4);
  padding: var(--sp-3) var(--sp-4);
  border: 1px solid var(--warning-border);
  border-radius: var(--radius-lg);
  background: var(--warning-soft);
  color: var(--warning-text);
  font-size: var(--fs-sm);
}

.aviso-offline-texto {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-width: 200px;
}

.curso-info {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--sp-2) var(--sp-4);
  margin-bottom: var(--sp-4);
  font-size: var(--fs-sm);
  color: var(--text-muted);
}

.hora,
.dias {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-1);
}

.hora {
  color: var(--text-2);
  font-weight: var(--fw-semibold);
}

.dia-chip {
  padding: 0.0625rem 0.5rem;
  border-radius: var(--radius-sm);
  background: var(--primary-soft);
  color: var(--primary-text);
  font-size: var(--fs-xs);
  font-weight: var(--fw-semibold);
}

.resumen {
  display: flex;
  flex-direction: column;
  gap: var(--sp-3);
  margin-bottom: var(--sp-4);
  padding: var(--sp-4);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--surface);
}

.resumen-cabecera {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-3);
}

.contadores {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-2);
}

.contador {
  padding: 0.1875rem 0.625rem;
  border-radius: var(--radius-full);
  background: var(--surface-hover);
  color: var(--text-2);
  font-size: var(--fs-sm);
}

.contador--presente {
  background: var(--estado-presente-suave);
  color: var(--estado-presente-texto);
}

.contador--ausente {
  background: var(--estado-ausente-suave);
  color: var(--estado-ausente-texto);
}

.contador--tarde {
  background: var(--estado-tarde-suave);
  color: var(--estado-tarde-texto);
}

.contador--justificado {
  background: var(--estado-justificado-suave);
  color: var(--estado-justificado-texto);
}

.herramientas {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-2);
  margin-bottom: var(--sp-2);
}

.buscador {
  display: flex;
  flex: 1;
  align-items: center;
  gap: var(--sp-2);
  min-width: 220px;
  max-width: 360px;
  height: 40px;
  padding: 0 var(--sp-3);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-md);
  background: var(--surface);
  color: var(--text-subtle);
}

.buscador:focus-within {
  border-color: var(--primary);
  box-shadow: var(--focus-ring);
}

.buscador input {
  flex: 1;
  min-width: 0;
  border: none;
  background: transparent;
  color: var(--text);
  font-size: var(--fs-base);
  outline: none;
}

.acciones-rapidas {
  display: flex;
  gap: var(--sp-1);
  margin-left: auto;
}

.ayuda {
  margin-bottom: var(--sp-3);
  font-size: var(--fs-xs);
  color: var(--text-subtle);
}

.lista {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}

/* Fija abajo dentro de la vista (sticky, no fixed): en celular queda arriba
   de la barra de navegación inferior. */
.barra-guardar {
  position: sticky;
  bottom: var(--inferior-fijo, 0px);
  z-index: 5;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-3);
  margin: var(--sp-5) calc(var(--sp-6) * -1) 0;
  padding: var(--sp-3) var(--sp-6);
  border-top: 1px solid var(--border);
  background: color-mix(in srgb, var(--surface) 92%, transparent);
  backdrop-filter: saturate(1.6) blur(14px);
  -webkit-backdrop-filter: saturate(1.6) blur(14px);
}

.barra-estado {
  font-size: var(--fs-sm);
  font-weight: var(--fw-semibold);
}

.barra-estado > span {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
}

.pendiente {
  color: var(--warning-text);
}

.punto {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--warning);
  animation: latido 1.6s var(--ease-out) infinite;
}

@keyframes latido {
  50% {
    opacity: 0.35;
  }
}

.ok {
  color: var(--success-text);
}

.barra-acciones {
  display: flex;
  gap: var(--sp-2);
  margin-left: auto;
}

.resumen-boton {
  font-weight: var(--fw-medium);
  opacity: 0.85;
}

@media (max-width: 600px) {
  .page-content {
    padding: var(--sp-3) var(--sp-4) 0;
  }

  .chips {
    margin: 0 calc(var(--sp-4) * -1);
    padding: 2px var(--sp-4) var(--sp-1);
  }

  .fecha-fila {
    max-width: none;
  }

  .resumen-cabecera > :deep(.segmentado) {
    display: grid;
    grid-template-columns: 1fr 1fr;
    width: 100%;
  }

  .barra-guardar {
    margin: var(--sp-4) calc(var(--sp-4) * -1) 0;
    padding: var(--sp-3) var(--sp-4);
  }

  .barra-acciones,
  .barra-acciones > * {
    flex: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .punto {
    animation: none;
  }
}
</style>
