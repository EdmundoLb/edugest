<script setup>
// "Alumnos en riesgo": alumnos con bajo porcentaje de asistencia o faltas
// seguidas en los últimos 30 días. Se usa en los paneles de admin y docente;
// RLS decide qué alumnos ve cada uno.
import { ref, computed, onMounted } from 'vue'
import AppSpinner from '@/components/AppSpinner.vue'
import { hoyLocal, formatearFecha } from '@/lib/fecha'
import { esFuncionFaltante } from '@/lib/api/reportes'
import {
  alumnosEnRiesgo,
  motivosRiesgo,
  UMBRAL_PORCENTAJE,
  FALTAS_SEGUIDAS,
} from '@/lib/api/alertas'
import { linkWhatsapp, armarMensajeAlerta } from '@/lib/whatsapp'
import { registrarAvisoEnviado, ultimosAvisos } from '@/lib/api/notificaciones'
import { tiempoRelativo } from '@/lib/notificaciones'
import { ultimosSeguimientos } from '@/lib/api/seguimiento'
import { estadoContacto } from '@/lib/seguimiento'

const props = defineProps({
  // El admin manda los avisos a las familias; el docente solo ve la lista.
  conAvisos: { type: Boolean, default: false },
  limite: { type: Number, default: 8 },
})

const cargando = ref(true)
const filas = ref([])
const faltaMigracion = ref(false)
const error = ref(false)
const verTodos = ref(false)
const avisados = ref(new Map()) // alumnoId -> último aviso por WhatsApp (0016)
const seguimientos = ref(new Map()) // alumnoId -> último seguimiento (0018)
const hoy = hoyLocal()

const visibles = computed(() => (verTodos.value ? filas.value : filas.value.slice(0, props.limite)))

function hace30Dias() {
  const d = new Date()
  d.setDate(d.getDate() - 30)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

onMounted(async () => {
  try {
    filas.value = await alumnosEnRiesgo({ desde: hace30Dias(), hasta: hoyLocal() })
    if (props.conAvisos) cargarAvisados()
    cargarSeguimientos()
  } catch (e) {
    if (esFuncionFaltante(e)) faltaMigracion.value = true
    else {
      console.error(e)
      error.value = true
    }
  } finally {
    cargando.value = false
  }
})

async function cargarSeguimientos() {
  try {
    seguimientos.value = await ultimosSeguimientos([
      ...new Set(filas.value.map((f) => f.alumno_id)),
    ])
  } catch (e) {
    // Sin 0018 no hay bitácora: no se muestra el estado del contacto.
    console.error(e)
    seguimientos.value = null
  }
}

async function cargarAvisados() {
  try {
    avisados.value = await ultimosAvisos([...new Set(filas.value.map((f) => f.alumno_id))])
  } catch (e) {
    // Sin 0016 no hay registro de avisos: se muestra la lista igual.
    console.error(e)
  }
}

// Abrir el link no garantiza que se haya mandado, pero deja constancia de
// que se intentó avisar (antes no quedaba ningún registro).
async function registrarAviso(f) {
  avisados.value = new Map(avisados.value).set(f.alumno_id, new Date().toISOString())
  try {
    await registrarAvisoEnviado({ alumnoId: f.alumno_id, motivo: 'alerta' })
  } catch (e) {
    console.error(e)
  }
}

function linkAviso(f) {
  return linkWhatsapp(
    f.telefono_padre,
    armarMensajeAlerta({
      alumno: f,
      curso: f.curso_nombre,
      porcentaje: f.porcentaje === null ? null : Number(f.porcentaje),
      faltasSeguidas: Number(f.faltas_seguidas),
    }),
  )
}
</script>

<template>
  <section class="panel-riesgo tarjeta" aria-labelledby="titulo-riesgo">
    <header class="cabecera">
      <h2 id="titulo-riesgo">
        Alumnos en riesgo
        <span v-if="filas.length" class="badge">{{ filas.length }}</span>
      </h2>
      <span class="criterio">
        Últimos 30 días · menos de {{ UMBRAL_PORCENTAJE }}% o {{ FALTAS_SEGUIDAS }}+ faltas seguidas
      </span>
    </header>

    <div v-if="cargando" class="centro"><AppSpinner size="small" /></div>

    <p v-else-if="faltaMigracion" class="texto-muted chico">
      Para ver alertas falta aplicar
      <code>supabase/migrations/0011_alertas_inasistencia.sql</code> en Supabase.
    </p>

    <p v-else-if="error" class="texto-muted chico">No se pudieron cargar las alertas.</p>

    <p v-else-if="!filas.length" class="ok">✓ Ningún alumno en riesgo en los últimos 30 días.</p>

    <template v-else>
      <ul class="lista">
        <li v-for="f in visibles" :key="`${f.alumno_id}|${f.curso_id}`">
          <div class="datos">
            <router-link :to="`/Estudiantes/${f.alumno_id}`" class="nombre">
              {{ f.apellido }}, {{ f.nombre }}
            </router-link>
            <span class="curso">{{ f.curso_nombre }}</span>
            <router-link
              v-if="seguimientos"
              :to="`/Estudiantes/${f.alumno_id}#seguimiento`"
              :class="['contacto', estadoContacto(seguimientos.get(f.alumno_id), hoy).nivel]"
            >
              {{ estadoContacto(seguimientos.get(f.alumno_id), hoy).texto }}
            </router-link>
            <span class="motivos">
              <span v-for="m in motivosRiesgo(f)" :key="m" class="motivo">{{ m }}</span>
              <span v-if="f.ultima_falta" class="texto-muted">
                · última falta
                {{ formatearFecha(f.ultima_falta, { day: 'numeric', month: 'short' }) }}
              </span>
            </span>
          </div>
          <template v-if="conAvisos">
            <a
              v-if="linkAviso(f)"
              :href="linkAviso(f)"
              target="_blank"
              rel="noopener"
              class="btn btn-secundario btn-chico whatsapp"
              @click="registrarAviso(f)"
            >
              Avisar al padre
            </a>
            <span v-if="avisados.get(f.alumno_id)" class="avisado">
              Avisado {{ tiempoRelativo(avisados.get(f.alumno_id)) }}
            </span>
            <span v-else class="sin-tel">Sin teléfono</span>
          </template>
        </li>
      </ul>
      <button
        v-if="filas.length > limite"
        type="button"
        class="btn btn-secundario btn-chico ver-todos"
        @click="verTodos = !verTodos"
      >
        {{ verTodos ? 'Ver menos' : `Ver los ${filas.length}` }}
      </button>
    </template>
  </section>
</template>

<style scoped>
.contacto {
  align-self: flex-start;
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  text-decoration: none;
}

.contacto.sin-contacto {
  background: var(--danger-soft);
  color: var(--danger-text);
}

.contacto.revisar {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.contacto.contactado {
  background: var(--success-soft);
  color: var(--success-text);
}

.avisado {
  font-size: 0.75rem;
  color: var(--success-text);
  white-space: nowrap;
}

.panel-riesgo {
  padding: 1.25rem;
}

.cabecera {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.25rem 1rem;
  margin-bottom: 0.75rem;
}

h2 {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1rem;
  font-weight: 700;
}

.badge {
  padding: 0 0.5rem;
  border-radius: 999px;
  background: var(--danger-soft);
  color: var(--danger-text);
  font-size: 0.75rem;
}

.criterio,
.chico {
  font-size: 0.75rem;
  color: var(--text-muted);
}

.centro {
  display: flex;
  justify-content: center;
  padding: 1rem;
}

.ok {
  font-size: 0.875rem;
  color: var(--success-text);
}

.lista {
  list-style: none;
}

.lista li {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.625rem 0;
  border-bottom: 1px solid var(--border);
}

.lista li:last-child {
  border-bottom: none;
}

.datos {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  flex: 1;
  min-width: 0;
}

.nombre {
  font-weight: 600;
  font-size: 0.9375rem;
  color: var(--text);
  text-decoration: none;
}

.nombre:hover {
  color: var(--primary-text);
  text-decoration: underline;
}

.curso {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.motivos {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.375rem;
  font-size: 0.75rem;
}

.motivo {
  padding: 0.0625rem 0.5rem;
  border-radius: 999px;
  background: var(--danger-soft);
  color: var(--danger-text);
  font-weight: 600;
}

.whatsapp {
  flex-shrink: 0;
  border-color: var(--success-border);
  color: var(--whatsapp-text);
}

.whatsapp:hover {
  background: var(--whatsapp-soft) !important;
}

.sin-tel {
  flex-shrink: 0;
  font-size: 0.75rem;
  color: var(--warning-text);
}

.ver-todos {
  margin-top: 0.75rem;
}
</style>
