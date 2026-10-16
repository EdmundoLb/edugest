<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useToast } from '@/composables/useToast'
import { listarCursos, crearCurso } from '@/lib/api/admin'

const router = useRouter()
const toast = useToast()

const cargando = ref(true)
const cursos = ref([])
const busqueda = ref('')

const formAbierto = ref(false)
const nuevo = ref({ nombre: '', descripcion: '' })
const guardando = ref(false)

const cursosFiltrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  return q ? cursos.value.filter((c) => c.nombre.toLowerCase().includes(q)) : cursos.value
})

const totales = computed(() => ({
  alumnos: cursos.value.reduce((n, c) => n + c.cantidadAlumnos, 0),
  sinHorario: cursos.value.filter((c) => c.cantidadHorarios === 0).length,
}))

onMounted(cargar)

async function cargar() {
  cargando.value = true
  try {
    cursos.value = await listarCursos()
  } catch (e) {
    toast.error('No se pudieron cargar los cursos', e)
  } finally {
    cargando.value = false
  }
}

async function guardarNuevo() {
  if (!nuevo.value.nombre.trim()) return
  guardando.value = true
  try {
    const { id } = await crearCurso(nuevo.value)
    toast.exito('Curso creado. Ahora agregale horarios y alumnos.')
    router.push(`/admin/cursos/${id}`)
  } catch (e) {
    toast.error('No se pudo crear el curso', e)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <div>
    <PageHeader
      titulo="Gestión de cursos"
      subtitulo="Cursos, horarios y alumnos inscriptos"
      volver="/admin"
    >
      <button type="button" class="btn btn-primario" @click="formAbierto = !formAbierto">
        {{ formAbierto ? 'Cancelar' : '+ Nuevo curso' }}
      </button>
    </PageHeader>

    <div class="contenedor">
      <form v-if="formAbierto" class="tarjeta form-nuevo" @submit.prevent="guardarNuevo">
        <h2>Nuevo curso</h2>
        <div class="form-grid">
          <div class="campo">
            <label for="nombre">Nombre *</label>
            <input
              id="nombre"
              v-model="nuevo.nombre"
              class="input"
              required
              maxlength="120"
              placeholder="Ej: (1º) Primer Curso-BTI"
            />
          </div>
          <div class="campo">
            <label for="descripcion">Descripción</label>
            <input
              id="descripcion"
              v-model="nuevo.descripcion"
              class="input"
              maxlength="250"
              placeholder="Ej: Bachillerato Técnico en Informática"
            />
          </div>
        </div>
        <div class="form-acciones">
          <button
            type="submit"
            class="btn btn-primario"
            :disabled="guardando || !nuevo.nombre.trim()"
          >
            <AppSpinner v-if="guardando" size="small" variant="light" />
            Crear curso
          </button>
        </div>
      </form>

      <div v-if="cargando" class="estado-carga">
        <AppSpinner size="large" />
      </div>

      <template v-else>
        <div class="barra">
          <p class="texto-muted">
            {{ cursos.length }} cursos · {{ totales.alumnos }} inscripciones
            <span v-if="totales.sinHorario" class="alerta">
              · {{ totales.sinHorario }} sin horario (no aparecen para tomar lista)
            </span>
          </p>
          <input
            v-model="busqueda"
            type="search"
            class="input buscador"
            placeholder="Buscar curso..."
            aria-label="Buscar curso"
          />
        </div>

        <EmptyState
          v-if="cursosFiltrados.length === 0"
          :title="cursos.length ? 'Ningún curso coincide con la búsqueda' : 'Todavía no hay cursos'"
          :hint="cursos.length ? '' : 'Creá el primero con “Nuevo curso”.'"
        />

        <div v-else class="grilla">
          <router-link
            v-for="c in cursosFiltrados"
            :key="c.id"
            :to="`/admin/cursos/${c.id}`"
            class="tarjeta curso"
          >
            <h3>{{ c.nombre }}</h3>
            <p v-if="c.descripcion" class="descripcion">{{ c.descripcion }}</p>
            <div class="chips">
              <span class="chip">{{ c.cantidadAlumnos }} alumnos</span>
              <span :class="['chip', { advertencia: c.cantidadHorarios === 0 }]">
                {{ c.cantidadHorarios === 0 ? 'Sin horarios' : `${c.cantidadHorarios} horarios` }}
              </span>
            </div>
          </router-link>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.form-nuevo {
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}

.form-nuevo h2 {
  font-size: 1rem;
  margin-bottom: 1rem;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.form-acciones {
  display: flex;
  justify-content: flex-end;
  margin-top: 1rem;
}

.estado-carga {
  display: flex;
  justify-content: center;
  padding: 4rem 1rem;
}

.barra {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 1rem;
  font-size: 0.875rem;
}

.alerta {
  color: var(--warning-text);
  font-weight: 600;
}

.buscador {
  max-width: 280px;
}

.grilla {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(270px, 1fr));
  gap: 0.75rem;
}

.curso {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  padding: 1.125rem 1.25rem;
  color: inherit;
  text-decoration: none;
  transition:
    border-color 0.15s,
    box-shadow 0.15s;
}

.curso:hover {
  border-color: var(--primary-border);
  box-shadow: var(--shadow);
}

.curso h3 {
  font-size: 1rem;
  font-weight: 700;
}

.descripcion {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
  margin-top: auto;
  padding-top: 0.5rem;
}

.chip {
  padding: 0.125rem 0.625rem;
  border-radius: 999px;
  background: var(--primary-soft);
  color: var(--primary-text);
  font-size: 0.75rem;
  font-weight: 600;
}

.chip.advertencia {
  background: var(--warning-soft);
  color: var(--warning-text);
}

@media (max-width: 600px) {
  .form-grid {
    grid-template-columns: 1fr;
  }

  .buscador {
    max-width: none;
  }
}
</style>
