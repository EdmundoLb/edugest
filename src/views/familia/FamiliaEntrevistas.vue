<script setup>
// La familia pide una entrevista con un docente de sus hijos (o con
// administración) eligiendo un horario libre, y ve o cancela las que tiene.
import { ref, computed, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import { listarHijos } from '@/lib/api/familias'
import {
  franjasFuturas,
  reservarEntrevista,
  cancelarEntrevista,
  esEsquemaFaltante,
} from '@/lib/api/seguimiento'
import { MODALIDADES, agruparPorDia, horaLocal } from '@/lib/seguimiento'
import { formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const { state } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const franjas = ref([])
const hijos = ref([])
const cargando = ref(true)
const faltaMigracion = ref(false)
const elegida = ref(null) // franja que se está reservando
const form = ref({ alumnoId: '', motivo: '' })
const reservando = ref(false)

const mias = computed(() => franjas.value.filter((f) => f.reserva?.tutor_id === state.perfil?.id))
const libresPorProfesional = computed(() => {
  const grupos = new Map()
  for (const f of franjas.value.filter((x) => !x.reservada)) {
    if (!grupos.has(f.profesional_id)) {
      grupos.set(f.profesional_id, { nombre: f.profesional_nombre, franjas: [] })
    }
    grupos.get(f.profesional_id).franjas.push(f)
  }
  return [...grupos.values()].map((g) => ({ ...g, dias: agruparPorDia(g.franjas) }))
})

onMounted(cargar)

async function cargar() {
  cargando.value = true
  try {
    const [f, h] = await Promise.all([franjasFuturas(), listarHijos(state.perfil.id)])
    franjas.value = f
    hijos.value = h
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudieron cargar los horarios', e)
  } finally {
    cargando.value = false
  }
}

function elegir(f) {
  elegida.value = f
  form.value = { alumnoId: hijos.value.length === 1 ? hijos.value[0].id : '', motivo: '' }
}

async function reservar() {
  if (!form.value.alumnoId) return
  reservando.value = true
  try {
    await reservarEntrevista({ franjaId: elegida.value.id, ...form.value })
    toast.exito('Entrevista reservada. Te recordamos el día anterior.')
    elegida.value = null
    await cargar()
  } catch (e) {
    toast.error('No se pudo reservar', e)
    await cargar()
  } finally {
    reservando.value = false
  }
}

async function cancelar(f) {
  const ok = await confirmar({
    titulo: '¿Cancelar la entrevista?',
    mensaje: 'Le avisamos al docente y el horario queda libre para otra familia.',
    aceptar: 'Cancelar entrevista',
    cancelar: 'Volver',
    peligro: true,
  })
  if (!ok) return
  try {
    await cancelarEntrevista(f.reserva.id)
    toast.exito('Entrevista cancelada')
    await cargar()
  } catch (e) {
    toast.error('No se pudo cancelar', e)
  }
}

function cuando(f) {
  const texto = formatearFecha(fechaLocalDeTimestamp(f.inicio), {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  })
  return `${texto.charAt(0).toUpperCase() + texto.slice(1)} a las ${horaLocal(f.inicio)}`
}

function diaCorto(fecha) {
  return formatearFecha(fecha, { weekday: 'short', day: 'numeric', month: 'short' })
}
</script>

<template>
  <div class="entrevistas-page">
    <PageHeader
      titulo="Entrevistas"
      subtitulo="Pedí una reunión con un docente"
      volver="/familia"
    />

    <div class="contenedor">
      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="faltaMigracion"
        title="Las entrevistas todavía no están habilitadas"
        hint="La institución tiene que terminar de configurarlas."
      />

      <template v-else>
        <section v-if="mias.length" class="bloque">
          <h2>Tus entrevistas</h2>
          <ul class="lista">
            <li v-for="f in mias" :key="f.id" class="tarjeta mia">
              <div>
                <strong>{{ cuando(f) }}</strong>
                <span class="chico">
                  Con {{ f.profesional_nombre }} · por {{ f.reserva.alumnos?.nombre }}
                </span>
                <span class="texto-muted chico">
                  {{ MODALIDADES[f.modalidad]
                  }}<template v-if="f.lugar"> · {{ f.lugar }}</template> · {{ f.duracion_min }} min
                </span>
              </div>
              <button type="button" class="btn btn-peligro btn-chico" @click="cancelar(f)">
                Cancelar
              </button>
            </li>
          </ul>
        </section>

        <section class="bloque">
          <h2>Pedir una entrevista</h2>

          <EmptyState
            v-if="!libresPorProfesional.length"
            title="No hay horarios libres por ahora"
            hint="Cuando un docente publique horarios, aparecen acá. También podés escribirle a la institución."
          />

          <div v-for="p in libresPorProfesional" :key="p.nombre" class="tarjeta profesional">
            <h3>{{ p.nombre }}</h3>
            <div v-for="d in p.dias" :key="d.fecha" class="dia">
              <span class="dia-nombre">{{ diaCorto(d.fecha) }}</span>
              <div class="horas">
                <button
                  v-for="f in d.franjas"
                  :key="f.id"
                  type="button"
                  :class="[
                    'btn',
                    'btn-chico',
                    elegida?.id === f.id ? 'btn-primario' : 'btn-secundario',
                  ]"
                  :aria-pressed="elegida?.id === f.id"
                  @click="elegir(f)"
                >
                  {{ horaLocal(f.inicio) }}
                </button>
              </div>
            </div>

            <form
              v-if="elegida && elegida.profesional_id === p.franjas[0].profesional_id"
              class="reserva"
              @submit.prevent="reservar"
            >
              <p>
                <strong>{{ cuando(elegida) }}</strong>
                <span class="texto-muted chico">
                  · {{ MODALIDADES[elegida.modalidad]
                  }}<template v-if="elegida.lugar"> · {{ elegida.lugar }}</template>
                </span>
              </p>
              <div class="campo">
                <label for="res-hijo">Por</label>
                <select id="res-hijo" v-model="form.alumnoId" class="input" required>
                  <option value="" disabled>Elegí a tu hijo</option>
                  <option v-for="h in hijos" :key="h.id" :value="h.id">
                    {{ h.nombre }} {{ h.apellido }}
                  </option>
                </select>
              </div>
              <div class="campo">
                <label for="res-motivo">Motivo (opcional)</label>
                <input
                  id="res-motivo"
                  v-model="form.motivo"
                  class="input"
                  type="text"
                  maxlength="500"
                  placeholder="Ej: Quiero hablar sobre sus faltas de las últimas semanas"
                />
              </div>
              <div class="acciones">
                <button type="button" class="btn btn-secundario" @click="elegida = null">
                  Volver
                </button>
                <button
                  type="submit"
                  class="btn btn-primario"
                  :disabled="!form.alumnoId || reservando"
                >
                  {{ reservando ? 'Reservando...' : 'Reservar' }}
                </button>
              </div>
            </form>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.entrevistas-page {
  min-height: calc(100vh - var(--navbar-height));
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.bloque {
  margin-bottom: 1.75rem;
}

.bloque h2 {
  font-size: 1.125rem;
  font-weight: 700;
  margin-bottom: 0.75rem;
}

.chico {
  font-size: 0.8125rem;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.mia {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  padding: 0.875rem 1.125rem;
  border-left: 4px solid var(--success);
}

.mia > div {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.profesional {
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
  padding: 1rem 1.25rem;
  margin-bottom: 0.75rem;
}

.profesional h3 {
  font-size: 1rem;
  font-weight: 700;
}

.dia {
  display: flex;
  align-items: baseline;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.dia-nombre {
  min-width: 6.5rem;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-2);
  text-transform: capitalize;
}

.horas {
  display: flex;
  gap: 0.375rem;
  flex-wrap: wrap;
}

.reserva {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1rem;
  margin-top: 0.25rem;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--surface-2);
}

.acciones {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}
</style>
