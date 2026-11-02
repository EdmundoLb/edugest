<script setup>
// Inicio del portal de familias: una tarjeta por hijo vinculado con la
// asistencia de hoy y del mes, y el teléfono al que la institución avisa.
import { ref, computed, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { listarHijos, actualizarTelefono, esEsquemaFaltante } from '@/lib/api/familias'
import { asistenciaDeAlumno } from '@/lib/api/historial'
import { UMBRAL_PORCENTAJE, FALTAS_SEGUIDAS } from '@/lib/api/alertas'
import { normalizarRegistro, combinarPorDia } from '@/lib/historial'
import { resumirHijo } from '@/lib/familia'
import { hoyLocal, rangoDelMes, nombreDelMes, formatearFecha } from '@/lib/fecha'

const { state } = useAuth()
const toast = useToast()

const ESTADOS = { presente: 'Presente', ausente: 'Ausente', justificado: 'Justificado' }

const hoy = hoyLocal()
const [anio, mes] = hoy.split('-').map(Number)
const nombreMes = nombreDelMes(anio, mes)

const cargando = ref(true)
const faltaMigracion = ref(false)
const hijos = ref([])
const resumenes = ref({}) // alumnoId -> resumirHijo(...) | 'error'

const telefono = ref(state.perfil?.telefono || '')
const guardandoTelefono = ref(false)
const telefonoCambiado = computed(() => telefono.value.trim() !== (state.perfil?.telefono || ''))

const saludo = computed(() => (state.perfil?.nombre ? `Hola, ${state.perfil.nombre}` : 'Hola'))

onMounted(cargar)

async function cargar() {
  cargando.value = true
  try {
    hijos.value = await listarHijos(state.perfil.id)
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudieron cargar tus hijos', e)
  } finally {
    cargando.value = false
  }
  await Promise.all(hijos.value.map((h) => cargarResumen(h.id)))
}

async function cargarResumen(alumnoId) {
  try {
    const filas = await asistenciaDeAlumno(alumnoId, rangoDelMes(anio, mes))
    const dias = combinarPorDia(filas.map(normalizarRegistro))
    resumenes.value = { ...resumenes.value, [alumnoId]: resumirHijo(dias, hoy) }
  } catch (e) {
    console.error(e)
    resumenes.value = { ...resumenes.value, [alumnoId]: 'error' }
  }
}

function necesitaAtencion(r) {
  return (
    r.faltasSeguidas >= FALTAS_SEGUIDAS ||
    (r.total >= 3 && r.porcentaje !== null && r.porcentaje < UMBRAL_PORCENTAJE)
  )
}

async function guardarTelefono() {
  guardandoTelefono.value = true
  try {
    await actualizarTelefono(state.perfil.id, telefono.value)
    state.perfil.telefono = telefono.value.trim() || null
    toast.exito('Teléfono actualizado')
  } catch (e) {
    toast.error('No se pudo guardar el teléfono', e)
  } finally {
    guardandoTelefono.value = false
  }
}
</script>

<template>
  <div class="familia-page">
    <PageHeader titulo="Mis hijos" :subtitulo="`Asistencia de ${nombreMes}`" />

    <div class="contenedor">
      <div class="bienvenida">
        <h2>{{ saludo }}</h2>
        <p class="texto-muted">
          Acá ves cómo viene la asistencia de tus hijos. Entrá a cada uno para ver el detalle clase
          por clase.
        </p>
      </div>

      <div v-if="cargando" class="cargando">
        <AppSpinner size="medium" />
      </div>

      <EmptyState
        v-else-if="faltaMigracion"
        title="El portal de familias todavía no está habilitado"
        hint="La institución tiene que terminar de configurarlo. Probá de nuevo más tarde."
      />

      <div v-else-if="!hijos.length" class="sin-hijos tarjeta">
        <EmptyState
          title="Todavía no vinculaste a ningún alumno"
          hint="Pedile a la institución el código de vinculación de tu hijo y cargalo acá."
        />
        <router-link to="/familia/vincular" class="btn btn-primario">Vincular alumno</router-link>
      </div>

      <div v-else class="grilla-hijos">
        <article v-for="h in hijos" :key="h.id" class="tarjeta hijo">
          <header class="hijo-cabecera">
            <div class="avatar" aria-hidden="true">{{ h.nombre.charAt(0).toUpperCase() }}</div>
            <div>
              <h3>{{ h.nombre }} {{ h.apellido }}</h3>
              <span v-if="h.parentesco" class="texto-muted chico">{{ h.parentesco }}</span>
            </div>
          </header>

          <div v-if="!resumenes[h.id]" class="cargando chico"><AppSpinner size="small" /></div>

          <p v-else-if="resumenes[h.id] === 'error'" class="texto-muted chico">
            No se pudo cargar la asistencia.
          </p>

          <template v-else>
            <section class="hoy" aria-label="Asistencia de hoy">
              <h4>Hoy</h4>
              <ul v-if="resumenes[h.id].hoy.length" class="hoy-lista">
                <li v-for="c in resumenes[h.id].hoy" :key="c.cursoId">
                  <span>{{ c.cursoNombre }}</span>
                  <span :class="['estado', c.estado]">{{ ESTADOS[c.estado] || c.estado }}</span>
                </li>
              </ul>
              <p v-else class="texto-muted chico">Todavía no hay asistencia cargada hoy.</p>
            </section>

            <dl class="numeros">
              <div>
                <dt>Asistencia del mes</dt>
                <dd>
                  {{ resumenes[h.id].porcentaje === null ? '—' : `${resumenes[h.id].porcentaje}%` }}
                </dd>
              </div>
              <div>
                <dt>Faltas</dt>
                <dd class="ausente">{{ resumenes[h.id].ausentes }}</dd>
              </div>
              <div>
                <dt>Justificadas</dt>
                <dd>{{ resumenes[h.id].justificados }}</dd>
              </div>
            </dl>

            <p v-if="necesitaAtencion(resumenes[h.id])" class="atencion" role="status">
              <template v-if="resumenes[h.id].faltasSeguidas >= FALTAS_SEGUIDAS">
                Tiene {{ resumenes[h.id].faltasSeguidas }} faltas seguidas sin justificar.
              </template>
              <template v-else>
                La asistencia del mes está por debajo del {{ UMBRAL_PORCENTAJE }}%.
              </template>
              Si hay un motivo, comunicate con la institución.
            </p>

            <p v-if="resumenes[h.id].ultimaClase" class="texto-muted chico">
              Última clase registrada:
              {{ formatearFecha(resumenes[h.id].ultimaClase, { day: 'numeric', month: 'long' }) }}
            </p>
          </template>

          <router-link :to="`/familia/hijo/${h.id}`" class="btn btn-secundario btn-chico ver">
            Ver historial completo
          </router-link>
        </article>
      </div>

      <section v-if="!cargando && !faltaMigracion" class="tarjeta contacto">
        <h2>Tu teléfono para avisos</h2>
        <p class="texto-muted chico">
          Si sos el contacto principal de un alumno, la institución te avisa a este número (por
          ejemplo, por WhatsApp). Cargalo con el código de país.
        </p>
        <form class="contacto-form" @submit.prevent="guardarTelefono">
          <input
            v-model="telefono"
            class="input"
            type="tel"
            placeholder="Ej: +595 981 123456"
            aria-label="Tu teléfono"
            autocomplete="tel"
          />
          <button
            type="submit"
            class="btn btn-primario"
            :disabled="!telefonoCambiado || guardandoTelefono"
          >
            {{ guardandoTelefono ? 'Guardando...' : 'Guardar' }}
          </button>
        </form>
      </section>
    </div>
  </div>
</template>

<style scoped>
.familia-page {
  min-height: calc(100vh - var(--navbar-height));
}

.bienvenida {
  margin-bottom: 1.5rem;
}

.bienvenida h2 {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.bienvenida p,
.chico {
  font-size: 0.875rem;
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.cargando.chico {
  padding: 1rem 0;
}

.sin-hijos {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 1.5rem;
}

.grilla-hijos {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.25rem;
}

.hijo {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.25rem;
}

.hijo-cabecera {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.hijo-cabecera h3 {
  font-size: 1.0625rem;
  font-weight: 700;
}

.avatar {
  display: grid;
  place-items: center;
  width: 2.75rem;
  height: 2.75rem;
  border-radius: 50%;
  background: var(--primary-soft-strong);
  color: var(--primary-text);
  font-weight: 700;
  font-size: 1.125rem;
  flex-shrink: 0;
}

.hoy h4 {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-muted);
  margin-bottom: 0.375rem;
}

.hoy-lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.hoy-lista li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
}

.estado {
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
}

.estado.presente {
  background: var(--success-soft);
  color: var(--success-text);
}

.estado.ausente {
  background: var(--danger-soft);
  color: var(--danger-text);
}

.estado.justificado {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.numeros {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
  padding: 0.75rem;
  border-radius: var(--radius);
  background: var(--surface-2);
}

.numeros div {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.numeros dt {
  font-size: 0.6875rem;
  color: var(--text-muted);
}

.numeros dd {
  font-size: 1.25rem;
  font-weight: 700;
}

.numeros dd.ausente {
  color: var(--danger-text);
}

.atencion {
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--warning-border);
  border-left: 4px solid var(--warning);
  border-radius: var(--radius-sm);
  background: var(--warning-soft);
  font-size: 0.8125rem;
}

.ver {
  margin-top: auto;
  align-self: flex-start;
}

.contacto {
  margin-top: 1.5rem;
  padding: 1.25rem;
  max-width: 560px;
}

.contacto h2 {
  font-size: 1.0625rem;
  font-weight: 700;
  margin-bottom: 0.25rem;
}

.contacto-form {
  display: flex;
  gap: 0.5rem;
  margin-top: 0.75rem;
}

@media (max-width: 480px) {
  .contacto-form {
    flex-direction: column;
  }
}
</style>
