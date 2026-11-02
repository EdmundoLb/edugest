<script setup>
// Formulario para publicar un comunicado. El admin elige cualquier
// audiencia; un docente, un curso que dicta o un alumno de ese curso (la
// policy de comunicados lo vuelve a validar en la base).
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { cursosDelUsuario } from '@/lib/api/cursos'
import { listarInscriptos } from '@/lib/api/admin'
import { publicarComunicado } from '@/lib/api/comunicados'
import { TIPOS_COMUNICADO, AUDIENCIAS, validarComunicado } from '@/lib/comunicados'
import { hoyLocal } from '@/lib/fecha'

const router = useRouter()
const { state, esAdmin } = useAuth()
const toast = useToast()

const form = ref({
  tipo: 'aviso',
  audiencia: esAdmin() ? 'institucion' : 'curso',
  cursoId: '',
  alumnoId: '',
  titulo: '',
  cuerpo: '',
  opciones: ['', ''],
  fechaLimite: '',
})

const cursos = ref([])
const alumnos = ref([])
const publicando = ref(false)
const error = ref('')

const audiencias = computed(() =>
  Object.entries(AUDIENCIAS).filter(([valor]) => esAdmin() || valor !== 'institucion'),
)
const necesitaCurso = computed(() => form.value.audiencia !== 'institucion')

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
  () => [form.value.audiencia, form.value.cursoId],
  async ([audiencia, cursoId]) => {
    form.value.alumnoId = ''
    alumnos.value = []
    if (audiencia !== 'alumno' || !cursoId) return
    try {
      alumnos.value = (await listarInscriptos(cursoId)).filter((a) => a.activa)
    } catch (e) {
      toast.error('No se pudieron cargar los alumnos del curso', e)
    }
  },
)

function agregarOpcion() {
  if (form.value.opciones.length < 6) form.value.opciones.push('')
}

function quitarOpcion(i) {
  form.value.opciones.splice(i, 1)
}

async function publicar() {
  error.value = validarComunicado(form.value) ?? ''
  if (error.value) return
  publicando.value = true
  try {
    const { id } = await publicarComunicado(form.value)
    toast.exito('Comunicado publicado')
    router.push(`/comunicados/${id}`)
  } catch (e) {
    toast.error('No se pudo publicar el comunicado', e)
  } finally {
    publicando.value = false
  }
}
</script>

<template>
  <div class="nuevo-page">
    <PageHeader titulo="Nuevo comunicado" volver="/comunicados" />

    <div class="contenedor">
      <form class="tarjeta formulario" @submit.prevent="publicar">
        <fieldset class="tipos">
          <legend>Tipo</legend>
          <label
            v-for="(t, valor) in TIPOS_COMUNICADO"
            :key="valor"
            :class="['tipo', { activo: form.tipo === valor }]"
          >
            <input v-model="form.tipo" type="radio" name="tipo" :value="valor" class="sr-only" />
            <strong>{{ t.texto }}</strong>
            <span class="texto-muted">{{ t.ayuda }}</span>
          </label>
        </fieldset>

        <div class="fila">
          <div class="campo">
            <label for="com-audiencia">Para</label>
            <select id="com-audiencia" v-model="form.audiencia" class="input">
              <option v-for="[valor, texto] in audiencias" :key="valor" :value="valor">
                {{ texto }}
              </option>
            </select>
          </div>
          <div v-if="necesitaCurso" class="campo">
            <label for="com-curso">Curso</label>
            <select id="com-curso" v-model="form.cursoId" class="input">
              <option value="" disabled>Elegí un curso</option>
              <option v-for="c in cursos" :key="c.id" :value="c.id">{{ c.nombre }}</option>
            </select>
          </div>
          <div v-if="form.audiencia === 'alumno'" class="campo">
            <label for="com-alumno">Alumno</label>
            <select id="com-alumno" v-model="form.alumnoId" class="input" :disabled="!form.cursoId">
              <option value="" disabled>
                {{ form.cursoId ? 'Elegí un alumno' : 'Primero elegí el curso' }}
              </option>
              <option v-for="a in alumnos" :key="a.id" :value="a.id">
                {{ a.apellido }}, {{ a.nombre }}
              </option>
            </select>
          </div>
        </div>

        <div class="campo">
          <label for="com-titulo">Título</label>
          <input
            id="com-titulo"
            v-model="form.titulo"
            class="input"
            type="text"
            maxlength="150"
            placeholder="Ej: Salida educativa al museo"
          />
        </div>

        <div class="campo">
          <label for="com-cuerpo">Texto</label>
          <textarea
            id="com-cuerpo"
            v-model="form.cuerpo"
            class="input"
            rows="7"
            maxlength="5000"
            placeholder="Escribí el comunicado tal como lo va a leer la familia."
          />
        </div>

        <div v-if="form.tipo === 'encuesta'" class="campo">
          <label>Opciones de respuesta</label>
          <div v-for="(_, i) in form.opciones" :key="i" class="opcion">
            <input
              v-model="form.opciones[i]"
              class="input"
              type="text"
              maxlength="80"
              :placeholder="`Opción ${i + 1}`"
              :aria-label="`Opción ${i + 1}`"
            />
            <button
              v-if="form.opciones.length > 2"
              type="button"
              class="btn btn-secundario btn-chico"
              :aria-label="`Quitar opción ${i + 1}`"
              @click="quitarOpcion(i)"
            >
              ✕
            </button>
          </div>
          <button
            v-if="form.opciones.length < 6"
            type="button"
            class="btn btn-secundario btn-chico agregar"
            @click="agregarOpcion"
          >
            Agregar opción
          </button>
        </div>

        <div v-else-if="form.tipo !== 'aviso'" class="campo">
          <label>Respuestas que va a ver la familia</label>
          <p class="texto-muted chico">{{ TIPOS_COMUNICADO[form.tipo].opciones.join(' · ') }}</p>
        </div>

        <div v-if="form.tipo !== 'aviso'" class="campo limite">
          <label for="com-limite">Responder hasta (opcional)</label>
          <input
            id="com-limite"
            v-model="form.fechaLimite"
            class="input"
            type="date"
            :min="hoyLocal()"
          />
        </div>

        <p v-if="error" class="error" role="alert">{{ error }}</p>

        <div class="acciones">
          <router-link to="/comunicados" class="btn btn-secundario">Cancelar</router-link>
          <button type="submit" class="btn btn-primario" :disabled="publicando">
            {{ publicando ? 'Publicando...' : 'Publicar' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
.nuevo-page {
  min-height: calc(100vh - var(--navbar-height));
}

.formulario {
  display: flex;
  flex-direction: column;
  gap: 1.125rem;
  max-width: 760px;
  padding: 1.5rem;
}

.tipos {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 0.625rem;
  border: none;
}

.tipos legend {
  margin-bottom: 0.5rem;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
}

.tipo {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0.75rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  cursor: pointer;
  font-size: 0.8125rem;
}

.tipo strong {
  font-size: 0.9375rem;
}

.tipo.activo {
  border-color: var(--primary);
  background: var(--primary-soft);
  box-shadow: var(--focus-ring);
}

.fila {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 0.75rem;
}

textarea.input {
  resize: vertical;
  font-family: inherit;
  line-height: 1.5;
}

.opcion {
  display: flex;
  gap: 0.5rem;
}

.agregar {
  align-self: flex-start;
}

.limite {
  max-width: 240px;
}

.chico {
  font-size: 0.8125rem;
}

.error {
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--danger-border);
  border-radius: var(--radius-sm);
  background: var(--danger-soft);
  color: var(--danger-text);
  font-size: 0.875rem;
}

.acciones {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}
</style>
