<script setup>
// Agenda de entrevistas del docente o del admin (0018): publica horarios
// libres y ve quién reservó cada uno. Las familias de sus alumnos los ven en
// /familia/entrevistas; la base avisa a cada parte al reservar o cancelar y
// el día anterior.
import { ref, computed, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import {
  franjasFuturas,
  crearFranjas,
  eliminarFranja,
  cancelarEntrevista,
  esEsquemaFaltante,
} from '@/lib/api/seguimiento'
import { MODALIDADES, franjasConsecutivas, agruparPorDia, horaLocal } from '@/lib/seguimiento'
import { linkWhatsapp } from '@/lib/whatsapp'
import { hoyLocal, sumarDias, formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const { state } = useAuth()
const toast = useToast()
const confirmar = useConfirm()

const franjas = ref([])
const cargando = ref(true)
const faltaMigracion = ref(false)
const publicando = ref(false)

const form = ref({
  fecha: sumarDias(hoyLocal(), 1),
  hora: '08:00',
  cantidad: 4,
  duracion: 20,
  modalidad: 'presencial',
  lugar: '',
})

const porDia = computed(() => agruparPorDia(franjas.value))
const reservadas = computed(() => franjas.value.filter((f) => f.reserva).length)

onMounted(cargar)

async function cargar() {
  cargando.value = true
  try {
    franjas.value = await franjasFuturas({ profesionalId: state.perfil.id })
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudo cargar la agenda', e)
  } finally {
    cargando.value = false
  }
}

async function publicar() {
  const inicios = franjasConsecutivas(form.value)
  if (new Date(inicios[0]) <= new Date()) {
    toast.error('Elegí una fecha y hora futuras')
    return
  }
  publicando.value = true
  try {
    await crearFranjas(inicios, form.value)
    toast.exito(
      inicios.length === 1 ? 'Horario publicado' : `${inicios.length} horarios publicados`,
    )
    await cargar()
  } catch (e) {
    toast.error(
      e?.code === '23505'
        ? 'Ya tenés un horario publicado a esa hora'
        : 'No se pudieron publicar los horarios',
      e?.code === '23505' ? undefined : e,
    )
  } finally {
    publicando.value = false
  }
}

async function quitar(f) {
  const ok = await confirmar({
    titulo: f.reserva ? '¿Cancelar la entrevista y borrar el horario?' : '¿Borrar este horario?',
    mensaje: f.reserva ? 'Le avisamos a la familia que se canceló.' : '',
    aceptar: f.reserva ? 'Cancelar entrevista' : 'Borrar',
    peligro: true,
  })
  if (!ok) return
  try {
    if (f.reserva) await cancelarEntrevista(f.reserva.id)
    await eliminarFranja(f.id)
    franjas.value = franjas.value.filter((x) => x.id !== f.id)
    toast.exito(f.reserva ? 'Entrevista cancelada' : 'Horario borrado')
  } catch (e) {
    toast.error('No se pudo cancelar', e)
  }
}

function linkFamilia(f) {
  return linkWhatsapp(
    f.reserva?.tutor_telefono,
    `Hola ${f.reserva?.tutor_nombre ?? ''}, le escribo por la entrevista sobre ` +
      `${f.reserva?.alumnos?.nombre ?? 'su hijo'} del ` +
      `${formatearFecha(fechaLocalDeTimestamp(f.inicio), { day: 'numeric', month: 'long' })} a las ${horaLocal(f.inicio)}.`,
  )
}

function tituloDia(fecha) {
  const texto = formatearFecha(fecha, { weekday: 'long', day: 'numeric', month: 'long' })
  return texto.charAt(0).toUpperCase() + texto.slice(1)
}
</script>

<template>
  <div class="agenda-page">
    <PageHeader titulo="Entrevistas" subtitulo="Horarios para que las familias pidan una reunión" />

    <div class="contenedor">
      <EmptyState
        v-if="faltaMigracion"
        title="Función no habilitada"
        hint="Falta aplicar la migración 0018_seguimiento_y_entrevistas.sql."
      />

      <template v-else>
        <form class="tarjeta formulario" @submit.prevent="publicar">
          <h2>Publicar horarios</h2>
          <div class="fila">
            <div class="campo">
              <label for="ent-fecha">Día</label>
              <input
                id="ent-fecha"
                v-model="form.fecha"
                class="input"
                type="date"
                :min="hoyLocal()"
                required
              />
            </div>
            <div class="campo">
              <label for="ent-hora">Desde</label>
              <input id="ent-hora" v-model="form.hora" class="input" type="time" required />
            </div>
            <div class="campo">
              <label for="ent-cantidad">Cantidad</label>
              <input
                id="ent-cantidad"
                v-model.number="form.cantidad"
                class="input"
                type="number"
                min="1"
                max="16"
                required
              />
            </div>
            <div class="campo">
              <label for="ent-duracion">Minutos c/u</label>
              <select id="ent-duracion" v-model.number="form.duracion" class="input">
                <option v-for="m in [10, 15, 20, 30, 45, 60]" :key="m" :value="m">{{ m }}</option>
              </select>
            </div>
            <div class="campo">
              <label for="ent-modalidad">Modalidad</label>
              <select id="ent-modalidad" v-model="form.modalidad" class="input">
                <option v-for="(texto, valor) in MODALIDADES" :key="valor" :value="valor">
                  {{ texto }}
                </option>
              </select>
            </div>
            <div class="campo lugar">
              <label for="ent-lugar">Lugar o link (opcional)</label>
              <input
                id="ent-lugar"
                v-model="form.lugar"
                class="input"
                type="text"
                maxlength="200"
                placeholder="Ej: Sala de profesores / link de Meet"
              />
            </div>
          </div>
          <div class="acciones">
            <span class="texto-muted chico">
              Se publican {{ form.cantidad }} horarios seguidos de {{ form.duracion }} minutos.
            </span>
            <button type="submit" class="btn btn-primario" :disabled="publicando">
              {{ publicando ? 'Publicando...' : 'Publicar' }}
            </button>
          </div>
        </form>

        <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

        <EmptyState
          v-else-if="!franjas.length"
          title="No tenés horarios publicados"
          hint="Publicá algunos y las familias de tus alumnos van a poder reservar una entrevista."
        />

        <template v-else>
          <p class="resumen texto-muted">
            {{ franjas.length }} horarios próximos · {{ reservadas }} reservados
          </p>
          <section v-for="d in porDia" :key="d.fecha" class="dia">
            <h3>{{ tituloDia(d.fecha) }}</h3>
            <ul class="lista">
              <li
                v-for="f in d.franjas"
                :key="f.id"
                :class="['tarjeta', 'franja', { reservada: f.reserva }]"
              >
                <div class="hora">
                  <strong>{{ horaLocal(f.inicio) }}</strong>
                  <span class="texto-muted chico">{{ f.duracion_min }} min</span>
                </div>
                <div class="detalle">
                  <template v-if="f.reserva">
                    <strong>
                      {{ f.reserva.alumnos?.nombre }} {{ f.reserva.alumnos?.apellido }}
                    </strong>
                    <span class="chico">Con {{ f.reserva.tutor_nombre }}</span>
                    <span v-if="f.reserva.motivo" class="texto-muted chico">
                      «{{ f.reserva.motivo }}»
                    </span>
                  </template>
                  <span v-else class="libre">Libre</span>
                  <span class="texto-muted chico">
                    {{ MODALIDADES[f.modalidad]
                    }}<template v-if="f.lugar"> · {{ f.lugar }}</template>
                  </span>
                </div>
                <div class="botones">
                  <a
                    v-if="f.reserva && linkFamilia(f)"
                    :href="linkFamilia(f)"
                    target="_blank"
                    rel="noopener"
                    class="btn btn-secundario btn-chico"
                    >WhatsApp</a
                  >
                  <button type="button" class="btn btn-peligro btn-chico" @click="quitar(f)">
                    {{ f.reserva ? 'Cancelar' : 'Borrar' }}
                  </button>
                </div>
              </li>
            </ul>
          </section>
        </template>
      </template>
    </div>
  </div>
</template>

<style scoped>
.agenda-page {
  min-height: calc(100vh - var(--navbar-height));
}

.formulario {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.25rem;
  margin-bottom: 1.5rem;
}

.formulario h2 {
  font-size: 1.0625rem;
  font-weight: 700;
}

.fila {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
  gap: 0.75rem;
}

.lugar {
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

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.resumen {
  margin-bottom: 1rem;
  font-size: 0.875rem;
}

.dia {
  margin-bottom: 1.25rem;
}

.dia h3 {
  font-size: 0.9375rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.franja {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1rem;
}

.franja.reservada {
  border-left: 4px solid var(--success);
}

.hora {
  display: flex;
  flex-direction: column;
  min-width: 3.5rem;
}

.hora strong {
  font-size: 1.0625rem;
}

.detalle {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  flex: 1;
  min-width: 0;
}

.libre {
  color: var(--text-muted);
  font-weight: 600;
}

.botones {
  display: flex;
  gap: 0.375rem;
}

@media (max-width: 560px) {
  .lugar {
    grid-column: auto;
  }

  .franja {
    flex-wrap: wrap;
  }
}
</style>
