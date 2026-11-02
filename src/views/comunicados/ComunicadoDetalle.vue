<script setup>
// Detalle de un comunicado enviado: texto, resumen de respuestas y estado
// de cada familia, con recordatorio por WhatsApp a las que faltan.
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useToast } from '@/composables/useToast'
import { useConfirm } from '@/composables/useConfirm'
import {
  obtenerComunicado,
  destinatariosDeComunicado,
  eliminarComunicado,
} from '@/lib/api/comunicados'
import { TIPOS_COMUNICADO, AUDIENCIAS, resumirRespuestas } from '@/lib/comunicados'
import { linkWhatsapp, armarMensajeRecordatorioComunicado } from '@/lib/whatsapp'
import { formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const confirmar = useConfirm()

const comunicado = ref(null)
const destinatarios = ref([])
const cargando = ref(true)
const filtro = ref('todos')

const requiereRespuesta = computed(() => Boolean(comunicado.value?.opciones))
const resumen = computed(() =>
  resumirRespuestas(destinatarios.value, comunicado.value?.opciones ?? []),
)
const filtrados = computed(() => {
  if (filtro.value === 'sin-leer') return destinatarios.value.filter((d) => !d.leido_at)
  if (filtro.value === 'sin-responder') return destinatarios.value.filter((d) => !d.respuesta)
  return destinatarios.value
})
const destino = computed(() => {
  const c = comunicado.value
  if (!c) return ''
  if (c.audiencia === 'curso') return c.cursos?.nombre
  if (c.audiencia === 'alumno') return `${c.alumnos?.nombre} ${c.alumnos?.apellido}`
  return AUDIENCIAS.institucion
})

onMounted(async () => {
  try {
    const [c, d] = await Promise.all([
      obtenerComunicado(route.params.id),
      destinatariosDeComunicado(route.params.id),
    ])
    comunicado.value = c
    destinatarios.value = d
  } catch (e) {
    toast.error('No se pudo cargar el comunicado', e)
  } finally {
    cargando.value = false
  }
})

function pendiente(d) {
  return requiereRespuesta.value ? !d.respuesta : !d.leido_at
}

function linkRecordatorio(d) {
  return linkWhatsapp(
    d.telefono,
    armarMensajeRecordatorioComunicado({
      titulo: comunicado.value.titulo,
      alumnoNombre: d.alumno_nombre,
      requiereRespuesta: requiereRespuesta.value,
    }),
  )
}

function fechaCorta(timestamp) {
  return formatearFecha(fechaLocalDeTimestamp(timestamp), { day: 'numeric', month: 'short' })
}

async function eliminar() {
  const ok = await confirmar({
    titulo: '¿Eliminar este comunicado?',
    mensaje: 'Las familias dejan de verlo y se pierden las lecturas y respuestas registradas.',
    aceptar: 'Eliminar',
    peligro: true,
  })
  if (!ok) return
  try {
    await eliminarComunicado(comunicado.value.id)
    toast.exito('Comunicado eliminado')
    router.push('/comunicados')
  } catch (e) {
    toast.error('No se pudo eliminar', e)
  }
}
</script>

<template>
  <div class="detalle-page">
    <PageHeader titulo="Comunicado" :subtitulo="comunicado?.titulo" volver="/comunicados" />

    <div class="contenedor">
      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="!comunicado"
        title="No encontramos este comunicado"
        hint="Puede que se haya eliminado."
      />

      <template v-else>
        <section class="tarjeta contenido">
          <div class="meta">
            <span class="tipo" :class="comunicado.tipo">
              {{ TIPOS_COMUNICADO[comunicado.tipo]?.texto }}
            </span>
            <span class="texto-muted chico">
              Para: {{ destino }} · {{ comunicado.autor_nombre }} ·
              {{ fechaCorta(comunicado.created_at) }}
              <template v-if="comunicado.fecha_limite">
                · responder hasta el
                {{ formatearFecha(comunicado.fecha_limite, { day: 'numeric', month: 'long' }) }}
              </template>
            </span>
          </div>
          <h2>{{ comunicado.titulo }}</h2>
          <p class="texto">{{ comunicado.cuerpo }}</p>
          <button type="button" class="btn btn-peligro btn-chico eliminar" @click="eliminar">
            Eliminar comunicado
          </button>
        </section>

        <section class="numeros">
          <div class="tarjeta numero">
            <strong>{{ resumen.total }}</strong>
            <span>familias</span>
          </div>
          <div class="tarjeta numero">
            <strong>{{ resumen.leidos }}</strong>
            <span>lo leyeron</span>
          </div>
          <div v-for="(cantidad, opcion) in resumen.porOpcion" :key="opcion" class="tarjeta numero">
            <strong>{{ cantidad }}</strong>
            <span>{{ opcion }}</span>
          </div>
          <div v-if="requiereRespuesta" class="tarjeta numero pendiente">
            <strong>{{ resumen.sinResponder }}</strong>
            <span>sin responder</span>
          </div>
        </section>

        <section class="tarjeta familias">
          <div class="familias-cabecera">
            <h3>Familias</h3>
            <div class="filtros" role="group" aria-label="Filtrar familias">
              <button
                v-for="[valor, texto] in [
                  ['todos', 'Todas'],
                  ['sin-leer', 'Sin leer'],
                  ...(requiereRespuesta ? [['sin-responder', 'Sin responder']] : []),
                ]"
                :key="valor"
                type="button"
                :class="['btn', 'btn-chico', filtro === valor ? 'btn-primario' : 'btn-secundario']"
                :aria-pressed="filtro === valor"
                @click="filtro = valor"
              >
                {{ texto }}
              </button>
            </div>
          </div>

          <p v-if="!destinatarios.length" class="texto-muted chico">
            Ninguna familia vinculada al portal recibió este comunicado. Generá códigos de
            vinculación desde el perfil de cada alumno.
          </p>

          <ul v-else class="lista">
            <li v-for="d in filtrados" :key="d.id" class="familia">
              <div class="familia-datos">
                <strong>{{ d.alumno_nombre }}</strong>
                <span class="texto-muted chico">{{ d.tutor_nombre }}</span>
              </div>
              <div class="familia-estado">
                <span v-if="d.respuesta" class="estado respondido">{{ d.respuesta }}</span>
                <span v-else-if="d.leido_at" class="estado leido">
                  Leído el {{ fechaCorta(d.leido_at) }}
                </span>
                <span v-else class="estado sin-leer">Sin leer</span>
                <a
                  v-if="pendiente(d) && linkRecordatorio(d)"
                  :href="linkRecordatorio(d)"
                  target="_blank"
                  rel="noopener"
                  class="btn btn-secundario btn-chico"
                  >Recordar por WhatsApp</a
                >
              </div>
            </li>
            <li v-if="!filtrados.length" class="texto-muted chico">
              No hay familias en este filtro.
            </li>
          </ul>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.detalle-page {
  min-height: calc(100vh - var(--navbar-height));
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.contenido {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1.25rem 1.5rem;
}

.meta {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  flex-wrap: wrap;
}

.contenido h2 {
  font-size: 1.25rem;
  font-weight: 700;
}

.texto {
  white-space: pre-line;
  line-height: 1.55;
}

.eliminar {
  align-self: flex-start;
}

.chico {
  font-size: 0.8125rem;
}

.tipo {
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  font-size: 0.6875rem;
  font-weight: 700;
  text-transform: uppercase;
  background: var(--primary-soft);
  color: var(--primary-text);
}

.tipo.autorizacion,
.tipo.citacion {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.numeros {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 0.75rem;
  margin: 1.25rem 0;
}

.numero {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  padding: 0.875rem 1rem;
}

.numero strong {
  font-size: 1.5rem;
}

.numero span {
  font-size: 0.8125rem;
  color: var(--text-muted);
}

.numero.pendiente strong {
  color: var(--warning-text);
}

.familias {
  padding: 1.25rem;
}

.familias-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  margin-bottom: 0.75rem;
}

.familias-cabecera h3 {
  font-size: 1.0625rem;
  font-weight: 700;
}

.filtros {
  display: flex;
  gap: 0.375rem;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
}

.familia {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  padding: 0.625rem 0;
  border-bottom: 1px solid var(--border);
}

.familia:last-child {
  border-bottom: none;
}

.familia-datos {
  display: flex;
  flex-direction: column;
}

.familia-estado {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.estado {
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
}

.estado.respondido {
  background: var(--success-soft);
  color: var(--success-text);
}

.estado.leido {
  background: var(--primary-soft);
  color: var(--primary-text);
}

.estado.sin-leer {
  background: var(--warning-soft);
  color: var(--warning-text);
}
</style>
