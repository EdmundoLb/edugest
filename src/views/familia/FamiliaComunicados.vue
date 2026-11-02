<script setup>
// Bandeja de comunicados de la familia: al abrir uno queda el acuse de
// lectura; las autorizaciones, encuestas y citaciones se responden por hijo.
import { ref, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useAuth } from '@/stores/auth'
import { useToast } from '@/composables/useToast'
import { useComunicadosNoLeidos } from '@/composables/useComunicadosNoLeidos'
import { bandejaFamilia, marcarLeido, responder, esEsquemaFaltante } from '@/lib/api/comunicados'
import { TIPOS_COMUNICADO, agruparBandeja, vencido } from '@/lib/comunicados'
import { hoyLocal, formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const { state } = useAuth()
const toast = useToast()
const { refrescar } = useComunicadosNoLeidos()

const hoy = hoyLocal()
const comunicados = ref([])
const abierto = ref(null)
const cargando = ref(true)
const faltaMigracion = ref(false)
const respondiendo = ref(null)

onMounted(async () => {
  try {
    comunicados.value = agruparBandeja(await bandejaFamilia(state.perfil.id))
  } catch (e) {
    if (esEsquemaFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudieron cargar los comunicados', e)
  } finally {
    cargando.value = false
  }
})

async function alternar(c) {
  abierto.value = abierto.value === c.id ? null : c.id
  if (abierto.value !== c.id || c.leido) return
  try {
    await marcarLeido(c.id)
    c.leido = true
    refrescar()
  } catch (e) {
    console.error(e)
  }
}

async function elegir(c, hijo, opcion) {
  respondiendo.value = hijo.destinatarioId
  try {
    const fila = await responder(hijo.destinatarioId, opcion)
    hijo.respuesta = fila.respuesta
    hijo.respondidoAt = fila.respondido_at
    c.leido = true
    refrescar()
    toast.exito('Respuesta enviada')
  } catch (e) {
    toast.error('No se pudo enviar la respuesta', e)
  } finally {
    respondiendo.value = null
  }
}

function fechaCorta(timestamp) {
  return formatearFecha(fechaLocalDeTimestamp(timestamp), { day: 'numeric', month: 'long' })
}
</script>

<template>
  <div class="comunicados-page">
    <PageHeader titulo="Comunicados" subtitulo="Lo que te manda la institución" volver="/familia" />

    <div class="contenedor">
      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="faltaMigracion"
        title="Los comunicados todavía no están habilitados"
        hint="La institución tiene que terminar de configurarlos."
      />

      <EmptyState
        v-else-if="!comunicados.length"
        title="No tenés comunicados"
        hint="Cuando la institución o un docente te mande algo, aparece acá."
      />

      <ul v-else class="lista">
        <li
          v-for="c in comunicados"
          :key="c.id"
          :class="['tarjeta', 'comunicado', { 'sin-leer': !c.leido }]"
        >
          <button
            type="button"
            class="cabecera"
            :aria-expanded="abierto === c.id"
            @click="alternar(c)"
          >
            <span class="tipo" :class="c.tipo">{{ TIPOS_COMUNICADO[c.tipo]?.texto }}</span>
            <span class="titulo">
              <strong>{{ c.titulo }}</strong>
              <span class="texto-muted chico">
                {{ c.autor_nombre }} · {{ fechaCorta(c.created_at) }}
              </span>
            </span>
            <span v-if="!c.leido" class="nuevo">Nuevo</span>
          </button>

          <div v-if="abierto === c.id" class="cuerpo">
            <p class="texto">{{ c.cuerpo }}</p>

            <p
              v-if="c.fecha_limite"
              class="limite"
              :class="{ vencido: vencido(c.fecha_limite, hoy) }"
            >
              {{
                vencido(c.fecha_limite, hoy)
                  ? 'Venció el plazo para responder el'
                  : 'Responder hasta el'
              }}
              {{
                formatearFecha(c.fecha_limite, { weekday: 'long', day: 'numeric', month: 'long' })
              }}
            </p>

            <div v-if="c.opciones" class="respuestas">
              <div v-for="h in c.hijos" :key="h.destinatarioId" class="respuesta-hijo">
                <span class="hijo">{{ h.alumnoNombre }}</span>
                <div class="opciones" role="group" :aria-label="`Respuesta para ${h.alumnoNombre}`">
                  <button
                    v-for="o in c.opciones"
                    :key="o"
                    type="button"
                    :class="[
                      'btn',
                      'btn-chico',
                      h.respuesta === o ? 'btn-primario' : 'btn-secundario',
                    ]"
                    :aria-pressed="h.respuesta === o"
                    :disabled="respondiendo === h.destinatarioId || vencido(c.fecha_limite, hoy)"
                    @click="elegir(c, h, o)"
                  >
                    {{ o }}
                  </button>
                </div>
                <span v-if="h.respondidoAt" class="texto-muted chico">
                  Respondiste el {{ fechaCorta(h.respondidoAt) }}
                </span>
              </div>
            </div>
            <p v-else class="texto-muted chico">Confirmamos que lo leíste.</p>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.comunicados-page {
  min-height: calc(100vh - var(--navbar-height));
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.comunicado {
  overflow: hidden;
}

.comunicado.sin-leer {
  border-left: 4px solid var(--primary);
}

.cabecera {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 1rem 1.25rem;
  border: none;
  background: transparent;
  color: var(--text);
  text-align: left;
  cursor: pointer;
}

.cabecera:hover {
  background: var(--surface-hover);
}

.titulo {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  flex: 1;
  min-width: 0;
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
  letter-spacing: 0.03em;
  white-space: nowrap;
  background: var(--primary-soft);
  color: var(--primary-text);
}

.tipo.autorizacion,
.tipo.citacion {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.nuevo {
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  background: var(--primary);
  color: var(--on-primary);
  font-size: 0.6875rem;
  font-weight: 700;
}

.cuerpo {
  display: flex;
  flex-direction: column;
  gap: 0.875rem;
  padding: 0 1.25rem 1.25rem;
}

.texto {
  white-space: pre-line;
  font-size: 0.9375rem;
  line-height: 1.55;
}

.limite {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--warning-text);
}

.limite.vencido {
  color: var(--text-muted);
}

.respuestas {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--border);
}

.respuesta-hijo {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.hijo {
  font-weight: 600;
  font-size: 0.875rem;
}

.opciones {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}
</style>
