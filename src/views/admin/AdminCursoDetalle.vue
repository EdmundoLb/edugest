<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import { formatearHora } from '@/lib/fecha'
import { indiceDia, ordenarPorDia } from '@/lib/dias'
import { esFuncionFaltante } from '@/lib/api/reportes'
import { parsearCsv, filasAAlumnos } from '@/lib/csv'
import {
  DIAS_SEMANA,
  TURNOS,
  obtenerCurso,
  actualizarCurso,
  eliminarCurso,
  listarHorariosDeCurso,
  crearHorarios,
  actualizarHorario,
  eliminarHorario,
  listarProfesores,
  listarInscriptos,
  buscarAlumnos,
  alumnosPorCi,
  inscribir,
  desinscribir,
  crearAlumno,
} from '@/lib/api/admin'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const confirmar = useConfirm()

const cursoId = computed(() => route.params.id)

const cargando = ref(true)
const curso = ref(null)
const horarios = ref([])
const profesores = ref([])
const inscriptos = ref([])
const pestana = ref('horarios')

// ---------- Carga ----------

onMounted(cargarTodo)

async function cargarTodo() {
  cargando.value = true
  try {
    const [c, h, p, i] = await Promise.all([
      obtenerCurso(cursoId.value),
      listarHorariosDeCurso(cursoId.value),
      listarProfesores(),
      listarInscriptos(cursoId.value),
    ])
    curso.value = c
    horarios.value = ordenarPorDia(h)
    profesores.value = p
    inscriptos.value = i
  } catch (e) {
    toast.error('No se pudo cargar el curso', e)
  } finally {
    cargando.value = false
  }
}

async function recargarHorarios() {
  horarios.value = ordenarPorDia(await listarHorariosDeCurso(cursoId.value))
}

async function recargarInscriptos() {
  inscriptos.value = await listarInscriptos(cursoId.value)
}

function nombreDia(valor) {
  return DIAS_SEMANA[indiceDia(valor)]?.texto ?? valor
}

function nombreProfesor(p) {
  return p ? `${p.apellido}, ${p.nombre}` : 'Sin docente'
}

// ---------- Datos del curso ----------

const editando = ref(false)
const formCurso = ref({ nombre: '', descripcion: '' })
const guardandoCurso = ref(false)

function empezarEdicion() {
  formCurso.value = { nombre: curso.value.nombre, descripcion: curso.value.descripcion ?? '' }
  editando.value = true
}

async function guardarCurso() {
  if (!formCurso.value.nombre.trim()) return
  guardandoCurso.value = true
  try {
    await actualizarCurso(cursoId.value, formCurso.value)
    curso.value = { ...curso.value, ...formCurso.value }
    editando.value = false
    toast.exito('Curso actualizado')
  } catch (e) {
    toast.error('No se pudo guardar el curso', e)
  } finally {
    guardandoCurso.value = false
  }
}

async function borrarCurso() {
  const ok = await confirmar({
    titulo: `¿Eliminar “${curso.value.nombre}”?`,
    mensaje:
      horarios.value.length || inscriptos.value.length
        ? `Tiene ${horarios.value.length} horarios y ${inscriptos.value.length} alumnos inscriptos. ` +
          'Si ya hay asistencia registrada no se va a poder eliminar.'
        : 'El curso no tiene horarios ni alumnos.',
    aceptar: 'Eliminar curso',
    peligro: true,
  })
  if (!ok) return
  try {
    await eliminarCurso(cursoId.value)
    toast.exito('Curso eliminado')
    router.push('/admin/cursos')
  } catch (e) {
    toast.error(
      e?.code === '23503'
        ? 'No se puede eliminar: el curso tiene horarios o asistencia registrada. Quitá primero sus horarios'
        : 'No se pudo eliminar el curso',
      e?.code === '23503' ? undefined : e,
    )
  }
}

// ---------- Horarios ----------

const formHorario = ref({
  dias: ['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes'],
  horaInicio: '07:15',
  horaFin: '11:15',
  turno: 'Matutino',
  profesorId: '',
})
const guardandoHorario = ref(false)

const errorHorario = computed(() => {
  const f = formHorario.value
  if (!f.dias.length) return 'Elegí al menos un día'
  if (!f.horaInicio || !f.horaFin) return 'Completá el horario'
  if (f.horaFin <= f.horaInicio) return 'La hora de fin tiene que ser posterior a la de inicio'
  if (!f.profesorId) return 'Elegí el docente'
  const repetidos = f.dias.filter((d) =>
    horarios.value.some(
      (h) =>
        indiceDia(h.dia_semana) === indiceDia(d) && formatearHora(h.hora_inicio) === f.horaInicio,
    ),
  )
  if (repetidos.length) {
    return `Ya existe un horario a las ${f.horaInicio} el ${repetidos.map(nombreDia).join(', ')}`
  }
  return ''
})

async function agregarHorarios() {
  if (errorHorario.value) return
  guardandoHorario.value = true
  const f = formHorario.value
  try {
    await crearHorarios(
      f.dias.map((dia) => ({
        curso_id: cursoId.value,
        profesor_id: f.profesorId,
        dia_semana: dia,
        hora_inicio: f.horaInicio,
        hora_fin: f.horaFin,
        turno: f.turno,
      })),
    )
    await recargarHorarios()
    toast.exito(f.dias.length > 1 ? `${f.dias.length} horarios agregados` : 'Horario agregado')
  } catch (e) {
    toast.error('No se pudieron agregar los horarios', e)
  } finally {
    guardandoHorario.value = false
  }
}

async function cambiarDocente(horario, profesorId) {
  try {
    await actualizarHorario(horario.id, { profesor_id: profesorId })
    await recargarHorarios()
    toast.exito('Docente actualizado')
  } catch (e) {
    toast.error('No se pudo cambiar el docente', e)
  }
}

const docenteParaTodos = ref('')

async function asignarDocenteATodos() {
  if (!docenteParaTodos.value) return
  try {
    await Promise.all(
      horarios.value.map((h) => actualizarHorario(h.id, { profesor_id: docenteParaTodos.value })),
    )
    await recargarHorarios()
    docenteParaTodos.value = ''
    toast.exito('Docente asignado a todos los horarios')
  } catch (e) {
    toast.error('No se pudo asignar el docente', e)
  }
}

async function quitarHorario(h) {
  const ok = await confirmar({
    titulo: `¿Quitar el horario del ${nombreDia(h.dia_semana)}?`,
    mensaje: `${formatearHora(h.hora_inicio)}–${formatearHora(h.hora_fin)}. Si ya tiene asistencia registrada no se va a poder quitar.`,
    aceptar: 'Quitar horario',
    peligro: true,
  })
  if (!ok) return
  try {
    await eliminarHorario(h.id)
    await recargarHorarios()
    toast.exito('Horario quitado')
  } catch (e) {
    toast.error(
      e?.code === '23503'
        ? 'Ese horario ya tiene asistencia registrada y no se puede quitar. Podés cambiarle el docente'
        : 'No se pudo quitar el horario',
      e?.code === '23503' ? undefined : e,
    )
  }
}

// ---------- Alumnos ----------

const filtroInscriptos = ref('')
const inscriptosFiltrados = computed(() => {
  const q = filtroInscriptos.value.trim().toLowerCase()
  if (!q) return inscriptos.value
  return inscriptos.value.filter((a) =>
    `${a.nombre} ${a.apellido} ${a.ci}`.toLowerCase().includes(q),
  )
})
const idsInscriptos = computed(() => new Set(inscriptos.value.map((a) => a.id)))

// Buscar alumno existente
const textoBusqueda = ref('')
const resultados = ref([])
const buscando = ref(false)
let temporizador = null

watch(textoBusqueda, (texto) => {
  clearTimeout(temporizador)
  if (texto.trim().length < 2) {
    resultados.value = []
    return
  }
  temporizador = setTimeout(async () => {
    buscando.value = true
    try {
      resultados.value = await buscarAlumnos(texto)
    } catch (e) {
      toast.error('No se pudo buscar', e)
    } finally {
      buscando.value = false
    }
  }, 300)
})

async function inscribirExistente(alumno) {
  try {
    await inscribir([alumno.id], cursoId.value)
    await recargarInscriptos()
    toast.exito(`${alumno.nombre} ${alumno.apellido} inscripto`)
  } catch (e) {
    toast.error('No se pudo inscribir', e)
  }
}

async function quitarAlumno(alumno) {
  const ok = await confirmar({
    titulo: `¿Quitar a ${alumno.nombre} ${alumno.apellido} del curso?`,
    mensaje: 'Deja de aparecer en la lista del curso. Su asistencia ya registrada se conserva.',
    aceptar: 'Quitar del curso',
    peligro: true,
  })
  if (!ok) return
  try {
    await desinscribir(alumno.inscripcionId)
    await recargarInscriptos()
    toast.exito('Alumno quitado del curso')
  } catch (e) {
    toast.error('No se pudo quitar al alumno', e)
  }
}

// Alta de alumno nuevo
const formAlumno = ref({ nombre: '', apellido: '', ci: '', telefonoPadre: '' })
const creandoAlumno = ref(false)
const faltaMigracionAlta = ref(false)

async function crearEInscribir() {
  const f = formAlumno.value
  if (!f.nombre.trim() || !f.apellido.trim() || !f.ci.trim()) return
  creandoAlumno.value = true
  try {
    const alumnoId = await crearAlumno({ ...f, ci: f.ci.replace(/[.\s]/g, '') })
    await inscribir([alumnoId], cursoId.value)
    await recargarInscriptos()
    formAlumno.value = { nombre: '', apellido: '', ci: '', telefonoPadre: '' }
    toast.exito('Alumno dado de alta e inscripto')
  } catch (e) {
    if (esFuncionFaltante(e)) faltaMigracionAlta.value = true
    else toast.error('No se pudo dar de alta al alumno', e)
  } finally {
    creandoAlumno.value = false
  }
}

// Importación desde CSV
const importacion = ref(null) // { filas: [{...alumno, estado}], faltan }
const importando = ref(false)
const progreso = ref({ hechos: 0, total: 0 })

async function leerArchivo(evento) {
  const archivo = evento.target.files?.[0]
  evento.target.value = ''
  if (!archivo) return
  try {
    const { alumnos, faltan } = filasAAlumnos(parsearCsv(await archivo.text()))
    if (faltan.length) {
      importacion.value = { filas: [], faltan, nombreArchivo: archivo.name }
      return
    }
    const existentes = await alumnosPorCi([...new Set(alumnos.map((a) => a.ci).filter(Boolean))])
    const porCi = new Map(existentes.map((a) => [a.ci, a]))
    const vistos = new Set()
    const filas = alumnos.map((a) => {
      let estado
      const existente = porCi.get(a.ci)
      if (!a.nombre || !a.apellido || !a.ci) estado = 'incompleto'
      else if (vistos.has(a.ci)) estado = 'repetido'
      else if (existente && idsInscriptos.value.has(existente.id)) estado = 'ya-inscripto'
      else if (existente) estado = 'existente'
      else estado = 'nuevo'
      if (a.ci) vistos.add(a.ci)
      return { ...a, estado, alumnoId: existente?.id ?? null }
    })
    importacion.value = { filas, faltan: [], nombreArchivo: archivo.name }
  } catch (e) {
    toast.error('No se pudo leer el archivo', e)
  }
}

const ESTADO_IMPORT = {
  nuevo: 'Se crea e inscribe',
  existente: 'Ya existe: se inscribe',
  'ya-inscripto': 'Ya está en el curso',
  incompleto: 'Faltan datos: se omite',
  repetido: 'CI repetida: se omite',
}

const resumenImportacion = computed(() => {
  const r = { nuevo: 0, existente: 0, omitidos: 0 }
  importacion.value?.filas.forEach((f) => {
    if (f.estado === 'nuevo') r.nuevo++
    else if (f.estado === 'existente') r.existente++
    else r.omitidos++
  })
  return r
})

async function confirmarImportacion() {
  const aProcesar = importacion.value.filas.filter(
    (f) => f.estado === 'nuevo' || f.estado === 'existente',
  )
  if (!aProcesar.length) return
  importando.value = true
  progreso.value = { hechos: 0, total: aProcesar.length }
  const errores = []
  const ids = []
  for (const f of aProcesar) {
    try {
      ids.push(f.alumnoId ?? (await crearAlumno(f)))
    } catch (e) {
      if (esFuncionFaltante(e)) {
        faltaMigracionAlta.value = true
        break
      }
      console.error(e)
      errores.push(`${f.apellido}, ${f.nombre} (CI ${f.ci})`)
    }
    progreso.value.hechos++
  }
  try {
    await inscribir(ids, cursoId.value)
    await recargarInscriptos()
    if (errores.length) {
      toast.error(
        `Se inscribieron ${ids.length}. Fallaron ${errores.length}: ${errores.join('; ')}`,
      )
    } else {
      toast.exito(`${ids.length} alumnos inscriptos`)
      importacion.value = null
    }
  } catch (e) {
    toast.error('No se pudieron inscribir los alumnos', e)
  } finally {
    importando.value = false
  }
}
</script>

<template>
  <div>
    <PageHeader
      :titulo="curso?.nombre ?? 'Curso'"
      :subtitulo="curso?.descripcion ?? ''"
      volver="/admin/cursos"
    >
      <template v-if="curso">
        <router-link :to="`/Reportes/mensual?curso=${curso.id}`" class="btn btn-secundario">
          Ver reporte
        </router-link>
        <button type="button" class="btn btn-secundario" @click="empezarEdicion">Editar</button>
        <button type="button" class="btn btn-peligro" @click="borrarCurso">Eliminar</button>
      </template>
    </PageHeader>

    <div class="contenedor">
      <div v-if="cargando" class="estado-carga"><AppSpinner size="large" /></div>

      <p v-else-if="!curso" class="texto-muted">No se encontró el curso.</p>

      <template v-else>
        <form v-if="editando" class="tarjeta bloque" @submit.prevent="guardarCurso">
          <div class="grid-2">
            <div class="campo">
              <label for="c-nombre">Nombre *</label>
              <input id="c-nombre" v-model="formCurso.nombre" class="input" required />
            </div>
            <div class="campo">
              <label for="c-desc">Descripción</label>
              <input id="c-desc" v-model="formCurso.descripcion" class="input" />
            </div>
          </div>
          <div class="acciones">
            <button type="button" class="btn btn-secundario" @click="editando = false">
              Cancelar
            </button>
            <button type="submit" class="btn btn-primario" :disabled="guardandoCurso">
              Guardar
            </button>
          </div>
        </form>

        <div class="pestanas" role="tablist">
          <button
            type="button"
            role="tab"
            :aria-selected="pestana === 'horarios'"
            :class="{ activa: pestana === 'horarios' }"
            @click="pestana = 'horarios'"
          >
            Horarios <span class="contador">{{ horarios.length }}</span>
          </button>
          <button
            type="button"
            role="tab"
            :aria-selected="pestana === 'alumnos'"
            :class="{ activa: pestana === 'alumnos' }"
            @click="pestana = 'alumnos'"
          >
            Alumnos <span class="contador">{{ inscriptos.length }}</span>
          </button>
        </div>

        <!-- ================= HORARIOS ================= -->
        <section v-if="pestana === 'horarios'" role="tabpanel">
          <div class="tarjeta bloque">
            <h2>Horarios del curso</h2>
            <p v-if="!horarios.length" class="texto-muted">
              Este curso no tiene horarios: los docentes no lo van a ver para tomar lista.
            </p>
            <div v-else class="tabla-scroll">
              <table class="tabla">
                <thead>
                  <tr>
                    <th>Día</th>
                    <th>Horario</th>
                    <th>Turno</th>
                    <th>Docente</th>
                    <th><span class="sr-only">Acciones</span></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="h in horarios" :key="h.id">
                    <td>{{ nombreDia(h.dia_semana) }}</td>
                    <td>{{ formatearHora(h.hora_inicio) }}–{{ formatearHora(h.hora_fin) }}</td>
                    <td>{{ h.turno }}</td>
                    <td>
                      <select
                        class="input input-chico"
                        :value="h.profesor_id ?? ''"
                        :aria-label="`Docente del ${nombreDia(h.dia_semana)}`"
                        @change="cambiarDocente(h, $event.target.value)"
                      >
                        <option v-for="p in profesores" :key="p.id" :value="p.id">
                          {{ nombreProfesor(p) }}
                        </option>
                      </select>
                    </td>
                    <td class="col-acciones">
                      <button
                        type="button"
                        class="btn btn-peligro btn-chico"
                        @click="quitarHorario(h)"
                      >
                        Quitar
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div v-if="horarios.length > 1" class="todos-docente">
              <label for="docente-todos">Asignar un docente a todos los horarios:</label>
              <select id="docente-todos" v-model="docenteParaTodos" class="input input-chico">
                <option value="">Elegí docente...</option>
                <option v-for="p in profesores" :key="p.id" :value="p.id">
                  {{ nombreProfesor(p) }}
                </option>
              </select>
              <button
                type="button"
                class="btn btn-secundario btn-chico"
                :disabled="!docenteParaTodos"
                @click="asignarDocenteATodos"
              >
                Aplicar
              </button>
            </div>
          </div>

          <form class="tarjeta bloque" @submit.prevent="agregarHorarios">
            <h2>Agregar horario</h2>
            <fieldset class="dias">
              <legend>Días</legend>
              <label v-for="d in DIAS_SEMANA" :key="d.valor" class="dia">
                <input v-model="formHorario.dias" type="checkbox" :value="d.valor" />
                {{ d.texto }}
              </label>
            </fieldset>
            <div class="grid-4">
              <div class="campo">
                <label for="h-inicio">Desde</label>
                <input id="h-inicio" v-model="formHorario.horaInicio" type="time" class="input" />
              </div>
              <div class="campo">
                <label for="h-fin">Hasta</label>
                <input id="h-fin" v-model="formHorario.horaFin" type="time" class="input" />
              </div>
              <div class="campo">
                <label for="h-turno">Turno</label>
                <select id="h-turno" v-model="formHorario.turno" class="input">
                  <option v-for="t in TURNOS" :key="t" :value="t">{{ t }}</option>
                </select>
              </div>
              <div class="campo">
                <label for="h-docente">Docente</label>
                <select id="h-docente" v-model="formHorario.profesorId" class="input">
                  <option value="" disabled>Elegí docente</option>
                  <option v-for="p in profesores" :key="p.id" :value="p.id">
                    {{ nombreProfesor(p) }}
                  </option>
                </select>
              </div>
            </div>
            <p v-if="errorHorario" class="error-form">{{ errorHorario }}</p>
            <div class="acciones">
              <button
                type="submit"
                class="btn btn-primario"
                :disabled="!!errorHorario || guardandoHorario"
              >
                <AppSpinner v-if="guardandoHorario" size="small" variant="light" />
                Agregar
                {{
                  formHorario.dias.length > 1 ? `${formHorario.dias.length} horarios` : 'horario'
                }}
              </button>
            </div>
          </form>
        </section>

        <!-- ================= ALUMNOS ================= -->
        <section v-else role="tabpanel">
          <div v-if="faltaMigracionAlta" class="aviso-error bloque">
            <strong>Falta aplicar la migración 0009.</strong>
            Para dar de alta alumnos nuevos, pegá
            <code>supabase/migrations/0009_gestion_cursos.sql</code> en el SQL Editor de Supabase.
            Inscribir alumnos que ya existen funciona igual.
          </div>

          <div class="grid-2 alta">
            <div class="tarjeta bloque">
              <h2>Inscribir alumno existente</h2>
              <input
                v-model="textoBusqueda"
                type="search"
                class="input"
                placeholder="Buscar por nombre, apellido o CI"
                aria-label="Buscar alumno para inscribir"
              />
              <p v-if="buscando" class="texto-muted chico">Buscando...</p>
              <ul v-else-if="resultados.length" class="resultados">
                <li v-for="a in resultados" :key="a.id">
                  <span>
                    <strong>{{ a.apellido }}</strong
                    >, {{ a.nombre }}
                    <span class="texto-muted"> · CI {{ a.ci }}</span>
                  </span>
                  <span v-if="idsInscriptos.has(a.id)" class="texto-muted chico">Ya inscripto</span>
                  <button
                    v-else
                    type="button"
                    class="btn btn-secundario btn-chico"
                    @click="inscribirExistente(a)"
                  >
                    Inscribir
                  </button>
                </li>
              </ul>
              <p v-else-if="textoBusqueda.trim().length >= 2" class="texto-muted chico">
                No se encontró. Dalo de alta como alumno nuevo.
              </p>
            </div>

            <form class="tarjeta bloque" @submit.prevent="crearEInscribir">
              <h2>Alumno nuevo</h2>
              <div class="grid-2">
                <div class="campo">
                  <label for="a-nombre">Nombres *</label>
                  <input id="a-nombre" v-model="formAlumno.nombre" class="input" required />
                </div>
                <div class="campo">
                  <label for="a-apellido">Apellidos *</label>
                  <input id="a-apellido" v-model="formAlumno.apellido" class="input" required />
                </div>
                <div class="campo">
                  <label for="a-ci">CI *</label>
                  <input
                    id="a-ci"
                    v-model="formAlumno.ci"
                    class="input"
                    required
                    inputmode="numeric"
                  />
                </div>
                <div class="campo">
                  <label for="a-tel">Teléfono del padre/tutor</label>
                  <input
                    id="a-tel"
                    v-model="formAlumno.telefonoPadre"
                    class="input"
                    type="tel"
                    placeholder="+595 9xx xxx xxx"
                  />
                </div>
              </div>
              <div class="acciones">
                <button type="submit" class="btn btn-primario" :disabled="creandoAlumno">
                  <AppSpinner v-if="creandoAlumno" size="small" variant="light" />
                  Dar de alta e inscribir
                </button>
              </div>
            </form>
          </div>

          <div class="tarjeta bloque">
            <div class="fila-titulo">
              <h2>Importar desde planilla</h2>
              <label class="btn btn-secundario btn-chico">
                Elegir archivo CSV
                <input type="file" accept=".csv,text/csv" class="sr-only" @change="leerArchivo" />
              </label>
            </div>
            <p class="texto-muted chico">
              En Excel: Archivo → Guardar como → CSV. Columnas obligatorias:
              <strong>Nombre</strong>, <strong>Apellido</strong>, <strong>CI</strong>. Opcional:
              <strong>Telefono padre</strong>. Antes de importar vas a ver qué se va a hacer con
              cada fila.
            </p>

            <div v-if="importacion" class="importacion">
              <p v-if="importacion.faltan.length" class="error-form">
                El archivo “{{ importacion.nombreArchivo }}” no tiene las columnas:
                {{ importacion.faltan.join(', ') }}.
              </p>
              <template v-else>
                <p class="chico">
                  <strong>{{ importacion.nombreArchivo }}</strong
                  >: {{ resumenImportacion.nuevo }} nuevos,
                  {{ resumenImportacion.existente }} existentes a inscribir,
                  {{ resumenImportacion.omitidos }} se omiten.
                </p>
                <div class="tabla-scroll vista-previa">
                  <table class="tabla">
                    <thead>
                      <tr>
                        <th>Apellido</th>
                        <th>Nombre</th>
                        <th>CI</th>
                        <th>Resultado</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        v-for="(f, i) in importacion.filas"
                        :key="i"
                        :class="`estado-${f.estado}`"
                      >
                        <td>{{ f.apellido }}</td>
                        <td>{{ f.nombre }}</td>
                        <td>{{ f.ci }}</td>
                        <td class="estado-import">{{ ESTADO_IMPORT[f.estado] }}</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div class="acciones">
                  <button
                    type="button"
                    class="btn btn-secundario"
                    :disabled="importando"
                    @click="importacion = null"
                  >
                    Cancelar
                  </button>
                  <button
                    type="button"
                    class="btn btn-primario"
                    :disabled="
                      importando || !(resumenImportacion.nuevo + resumenImportacion.existente)
                    "
                    @click="confirmarImportacion"
                  >
                    <AppSpinner v-if="importando" size="small" variant="light" />
                    {{
                      importando
                        ? `Procesando ${progreso.hechos}/${progreso.total}...`
                        : `Importar ${resumenImportacion.nuevo + resumenImportacion.existente} alumnos`
                    }}
                  </button>
                </div>
              </template>
            </div>
          </div>

          <div class="tarjeta bloque">
            <div class="fila-titulo">
              <h2>Inscriptos ({{ inscriptos.length }})</h2>
              <input
                v-if="inscriptos.length > 8"
                v-model="filtroInscriptos"
                type="search"
                class="input buscador"
                placeholder="Filtrar..."
                aria-label="Filtrar inscriptos"
              />
            </div>
            <p v-if="!inscriptos.length" class="texto-muted">
              Todavía no hay alumnos en este curso.
            </p>
            <ul v-else class="inscriptos">
              <li v-for="a in inscriptosFiltrados" :key="a.id">
                <router-link :to="`/Estudiantes/${a.id}`" class="nombre-alumno">
                  <strong>{{ a.apellido }}</strong
                  >, {{ a.nombre }}
                </router-link>
                <span class="texto-muted chico">CI {{ a.ci }}</span>
                <span v-if="!a.telefono_padre" class="sin-tel chico">Sin teléfono del padre</span>
                <button
                  type="button"
                  class="btn btn-peligro btn-chico quitar"
                  @click="quitarAlumno(a)"
                >
                  Quitar
                </button>
              </li>
            </ul>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.estado-carga {
  display: flex;
  justify-content: center;
  padding: 4rem 1rem;
}

.bloque {
  padding: 1.25rem;
  margin-bottom: 1rem;
}

.bloque h2 {
  font-size: 1rem;
  font-weight: 700;
  margin-bottom: 0.875rem;
}

.grid-2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.grid-4 {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
}

.alta {
  gap: 1rem;
  align-items: start;
}

.alta > .bloque {
  margin-bottom: 1rem;
}

.acciones {
  display: flex;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1rem;
}

.pestanas {
  display: flex;
  gap: 0.25rem;
  margin-bottom: 1rem;
  border-bottom: 1px solid var(--border);
}

.pestanas button {
  padding: 0.625rem 1rem;
  border: none;
  border-bottom: 2px solid transparent;
  background: none;
  color: var(--text-muted);
  font-size: 0.9375rem;
  font-weight: 600;
  cursor: pointer;
  margin-bottom: -1px;
}

.pestanas button.activa {
  color: var(--primary-text);
  border-bottom-color: var(--primary);
}

.contador {
  margin-left: 0.25rem;
  padding: 0 0.5rem;
  border-radius: 999px;
  background: var(--surface-hover);
  font-size: 0.75rem;
}

.tabla-scroll {
  overflow-x: auto;
}

.tabla {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.tabla th,
.tabla td {
  padding: 0.5rem 0.625rem;
  border-bottom: 1px solid var(--border);
  text-align: left;
  white-space: nowrap;
}

.tabla th {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.col-acciones {
  text-align: right !important;
}

.input-chico {
  padding: 0.375rem 0.5rem;
  font-size: 0.8125rem;
  width: auto;
  min-width: 180px;
}

.todos-docente {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1rem;
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.dias {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 1rem;
  border: none;
}

.dias legend {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
  margin-bottom: 0.375rem;
}

.dia {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  border: 1px solid var(--border-strong);
  border-radius: 999px;
  font-size: 0.875rem;
  cursor: pointer;
}

.dia:has(input:checked) {
  background: var(--primary-soft);
  border-color: var(--primary-border);
  color: var(--primary-text);
}

.dia input {
  accent-color: var(--primary);
}

.error-form {
  margin-top: 0.75rem;
  font-size: 0.8125rem;
  color: var(--danger-text);
}

.aviso-error {
  padding: 1rem 1.25rem;
  border: 1px solid var(--danger-border);
  border-radius: var(--radius);
  background: var(--danger-soft);
  color: var(--text);
  font-size: 0.875rem;
}

.chico {
  font-size: 0.8125rem;
}

.resultados,
.inscriptos {
  list-style: none;
  margin-top: 0.5rem;
}

.resultados li,
.inscriptos li {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--border);
  font-size: 0.875rem;
}

.resultados li > span:first-child {
  flex: 1;
}

.resultados li:last-child,
.inscriptos li:last-child {
  border-bottom: none;
}

.nombre-alumno {
  color: var(--text);
  text-decoration: none;
}

.nombre-alumno:hover {
  color: var(--primary-text);
  text-decoration: underline;
}

.sin-tel {
  color: var(--warning-text);
}

.quitar {
  margin-left: auto;
}

.fila-titulo {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 0.5rem;
}

.fila-titulo h2 {
  margin-bottom: 0;
}

.buscador {
  max-width: 240px;
}

.importacion {
  margin-top: 1rem;
}

.vista-previa {
  max-height: 320px;
  overflow-y: auto;
  margin-top: 0.5rem;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
}

.estado-nuevo .estado-import {
  color: var(--success-text);
  font-weight: 600;
}

.estado-existente .estado-import {
  color: var(--primary-text);
  font-weight: 600;
}

.estado-incompleto,
.estado-repetido,
.estado-ya-inscripto {
  color: var(--text-subtle);
}

@media (max-width: 760px) {
  .grid-2,
  .grid-4 {
    grid-template-columns: 1fr;
  }

  .inscriptos li {
    flex-wrap: wrap;
  }
}
</style>
