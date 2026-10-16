<script setup>
import PageHeader from '@/components/PageHeader.vue'
import AlumnoAsistenciaFila from '@/components/AlumnoAsistenciaFila.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, onBeforeRouteLeave } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { supabase } from '@/lib/supabase'
import { hoyLocal, diaSemanaDeFecha, formatearFecha, formatearHora } from '@/lib/fecha'
import { formatearDias, indiceDia, ordenarPorDia } from '@/lib/dias'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'

const route = useRoute()
const { state } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const loading = ref(true)
const loadingAlumnos = ref(false)
const guardando = ref(false)
const remitiendo = ref(false)

const horarios = ref([])
const cursoId = ref(null)
const fecha = ref(hoyLocal())
const alumnos = ref([])
const asistencia = ref({})
const observaciones = ref({})
const asistenciaGuardada = ref(false)
const informeRemitido = ref(null)
const busqueda = ref('')

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

const totales = computed(() => {
  const t = { presente: 0, ausente: 0, justificado: 0 }
  alumnos.value.forEach((a) => t[asistencia.value[a.id]]++)
  return t
})

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

// El <select> y el <input type="date"> no usan v-model directo: primero se
// pregunta si descartar cambios, y si el usuario cancela se vuelve el control
// a su valor anterior.
async function cambiarCurso(e) {
  const nuevo = e.target.value
  if (await confirmarDescartar()) {
    cursoId.value = nuevo
  } else {
    e.target.value = cursoId.value ?? ''
  }
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
    if (error) throw error
    horarios.value = ordenarPorDia(data || [])
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
  snapshot.value = estadoActual()

  const horario = horarioDelDia.value
  if (!horario) return

  loadingAlumnos.value = true
  try {
    const [inscripciones, existente, informe] = await Promise.all([
      supabase
        .from('inscripciones')
        .select('alumnos (id, nombre, apellido)')
        .eq('curso_id', cursoId.value),
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
    ])
    if (inscripciones.error) throw inscripciones.error
    if (existente.error) throw existente.error

    alumnos.value = (inscripciones.data || [])
      .map((i) => i.alumnos)
      .filter(Boolean)
      .sort((a, b) => a.apellido.localeCompare(b.apellido) || a.nombre.localeCompare(b.nombre))

    const previos = new Map((existente.data || []).map((r) => [r.alumno_id, r]))
    asistenciaGuardada.value = previos.size > 0

    const nuevaAsistencia = {}
    const nuevasObservaciones = {}
    alumnos.value.forEach((a) => {
      // Primera pasada de lista: todos presentes por defecto.
      nuevaAsistencia[a.id] = previos.get(a.id)?.estado ?? 'presente'
      nuevasObservaciones[a.id] = previos.get(a.id)?.observacion ?? ''
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

    const { error } = await supabase
      .from('asistencia')
      .upsert(registros, { onConflict: 'horario_id,alumno_id,fecha' })
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
    <PageHeader
      titulo="Llamar lista"
      subtitulo="Registrá la asistencia del día"
      volver="/ProfesorDashboard"
    />

    <div class="page-content">
      <div v-if="loading" class="estado-carga">
        <AppSpinner size="large" />
        <p>Cargando tus cursos...</p>
      </div>

      <div v-else-if="cursos.length === 0" class="aviso">
        <p>No tenés cursos asignados todavía.</p>
        <span>Pedile a administración que te asigne un horario.</span>
      </div>

      <template v-else>
        <section class="filtros" aria-label="Curso y fecha">
          <div class="campo">
            <label for="curso">Curso</label>
            <select
              id="curso"
              :value="cursoId ?? ''"
              :disabled="loadingAlumnos || guardando"
              @change="cambiarCurso"
            >
              <option value="" disabled>Elegí un curso</option>
              <option v-for="c in cursos" :key="c.id" :value="c.id">{{ c.nombre }}</option>
            </select>
          </div>

          <div class="campo">
            <label for="fecha">Fecha</label>
            <div class="fecha-fila">
              <input
                id="fecha"
                type="date"
                :value="fecha"
                :max="hoyLocal()"
                :disabled="loadingAlumnos || guardando"
                @change="cambiarFecha"
              />
              <button
                type="button"
                class="btn-hoy"
                :disabled="fecha === hoyLocal()"
                @click="irAHoy"
              >
                Hoy
              </button>
            </div>
          </div>
        </section>

        <p v-if="cursoSeleccionado" class="curso-info">
          <span>Días de clase:</span>
          <span v-for="chip in diasDelCurso" :key="chip" class="dia-chip">{{ chip }}</span>
          <span v-if="horarioDelDia" class="hora">
            · {{ formatearHora(horarioDelDia.hora_inicio) }}–{{
              formatearHora(horarioDelDia.hora_fin)
            }}
          </span>
        </p>

        <div v-if="!cursoSeleccionado" class="aviso">
          <p>Elegí un curso para empezar.</p>
        </div>

        <div v-else-if="loadingAlumnos" class="estado-carga">
          <AppSpinner size="large" />
          <p>Cargando alumnos...</p>
        </div>

        <div v-else-if="!horarioDelDia" class="aviso">
          <p>
            {{ cursoSeleccionado.nombre }} no tiene clase el
            {{ formatearFecha(fecha, { weekday: 'long', day: 'numeric', month: 'long' }) }}.
          </p>
          <span>Elegí otra fecha. Días de clase: {{ diasDelCurso.join(', ') }}</span>
        </div>

        <div v-else-if="alumnos.length === 0" class="aviso">
          <p>Este curso no tiene alumnos inscriptos.</p>
        </div>

        <template v-else>
          <section class="resumen" aria-label="Resumen">
            <div class="contadores" aria-live="polite">
              <span class="contador"
                ><strong>{{ alumnos.length }}</strong> alumnos</span
              >
              <span class="contador presente"
                ><strong>{{ totales.presente }}</strong> presentes</span
              >
              <span class="contador ausente"
                ><strong>{{ totales.ausente }}</strong> ausentes</span
              >
              <span class="contador justificado"
                ><strong>{{ totales.justificado }}</strong> justificados</span
              >
            </div>
            <div class="acciones-rapidas">
              <button type="button" class="btn-chico" @click="marcarTodos('presente')">
                Todos presentes
              </button>
              <button type="button" class="btn-chico" @click="marcarTodos('ausente')">
                Todos ausentes
              </button>
            </div>
          </section>

          <input
            v-if="alumnos.length > 8"
            v-model="busqueda"
            type="search"
            class="buscador"
            placeholder="Buscar alumno..."
            aria-label="Buscar alumno"
          />

          <div class="lista">
            <AlumnoAsistenciaFila
              v-for="alumno in alumnosFiltrados"
              :key="alumno.id"
              v-model:estado="asistencia[alumno.id]"
              v-model:observacion="observaciones[alumno.id]"
              :alumno="alumno"
              :deshabilitado="guardando"
            />
            <p v-if="alumnosFiltrados.length === 0" class="sin-resultados">
              Ningún alumno coincide con “{{ busqueda }}”.
            </p>
          </div>

          <div class="barra-guardar">
            <div class="barra-estado">
              <span v-if="faltaGuardar" class="pendiente">● Sin guardar</span>
              <span v-else-if="informeRemitido" class="ok">
                ✓ Guardada y remitida a administración
              </span>
              <span v-else class="ok">✓ Asistencia guardada</span>
            </div>
            <div class="barra-acciones">
              <button
                v-if="!faltaGuardar"
                type="button"
                class="btn-secundario"
                :disabled="remitiendo"
                @click="remitirInforme"
              >
                <AppSpinner v-if="remitiendo" size="small" />
                {{ informeRemitido ? 'Volver a remitir' : 'Remitir a administración' }}
              </button>
              <button
                type="button"
                class="btn-primario"
                :disabled="guardando || !faltaGuardar"
                @click="guardarAsistencia"
              >
                <AppSpinner v-if="guardando" size="small" variant="light" />
                {{ guardando ? 'Guardando...' : 'Guardar asistencia' }}
              </button>
            </div>
          </div>
        </template>
      </template>
    </div>
  </div>
</template>

<style scoped>
.lista-page {
  min-height: calc(100vh - var(--navbar-height));
}

.page-content {
  max-width: 900px;
  margin: 0 auto;
  padding: 1.5rem 1.5rem 0;
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
  padding: 2.5rem 1.5rem;
  text-align: center;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  color: var(--text-2);
}

.aviso span {
  display: block;
  margin-top: 0.375rem;
  font-size: 0.875rem;
  color: var(--text-muted);
}

.filtros {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  padding: 1rem;
  margin-bottom: 0.75rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
}

.campo {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  min-width: 0;
}

.campo label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
}

.campo select,
.campo input,
.buscador {
  width: 100%;
  padding: 0.625rem 0.875rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-sm);
  background: var(--surface);
  color: var(--text);
  font-size: 0.9375rem;
}

.campo select:focus,
.campo input:focus,
.buscador:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: var(--focus-ring);
}

.fecha-fila {
  display: flex;
  gap: 0.5rem;
}

.btn-hoy {
  flex-shrink: 0;
  padding: 0 1rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--text);
  font-weight: 600;
  cursor: pointer;
}

.btn-hoy:disabled {
  opacity: 0.45;
  cursor: default;
}

.curso-info {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.375rem;
  margin-bottom: 1.25rem;
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.dia-chip {
  padding: 0.125rem 0.5rem;
  background: var(--primary-soft);
  border-radius: var(--radius-sm);
  color: var(--primary-text);
  font-weight: 600;
}

.resumen {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}

.contadores {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.contador {
  padding: 0.25rem 0.625rem;
  border-radius: 999px;
  background: var(--surface-hover);
  font-size: 0.8125rem;
  color: var(--text-2);
}

.contador.presente {
  background: var(--success-soft);
  color: var(--success-text);
}

.contador.ausente {
  background: var(--danger-soft);
  color: var(--danger-text);
}

.contador.justificado {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.acciones-rapidas {
  display: flex;
  gap: 0.5rem;
}

.btn-chico {
  padding: 0.375rem 0.75rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-sm);
  background: var(--surface);
  color: var(--text-2);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}

.btn-chico:hover {
  background: var(--surface-hover);
}

.buscador {
  margin-bottom: 0.75rem;
}

.lista {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.sin-resultados {
  padding: 1.5rem;
  text-align: center;
  color: var(--text-muted);
}

.barra-guardar {
  position: sticky;
  bottom: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin: 1rem -1.5rem 0;
  padding: 0.875rem 1.5rem;
  background: var(--surface);
  border-top: 1px solid var(--border);
  box-shadow: 0 -4px 14px rgba(15, 23, 42, 0.06);
}

.barra-estado {
  font-size: 0.875rem;
  font-weight: 600;
}

.pendiente {
  color: var(--warning-text);
}

.ok {
  color: var(--success-text);
}

.barra-acciones {
  display: flex;
  gap: 0.5rem;
  margin-left: auto;
}

.btn-primario,
.btn-secundario {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.6875rem 1.25rem;
  border-radius: var(--radius-sm);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
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
  border: 1px solid var(--primary-border);
  background: var(--primary-soft);
  color: var(--primary-text);
}

.btn-primario:disabled,
.btn-secundario:disabled {
  opacity: 0.5;
  cursor: default;
}

@media (max-width: 600px) {
  .page-content {
    padding: 1rem 1rem 0;
  }

  .filtros {
    grid-template-columns: 1fr;
  }

  .barra-guardar {
    margin: 1rem -1rem 0;
    padding: 0.75rem 1rem;
  }

  .barra-acciones,
  .barra-acciones button {
    flex: 1;
    justify-content: center;
  }
}
</style>
