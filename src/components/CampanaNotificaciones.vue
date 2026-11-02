<script setup>
// Campanita de la navbar: últimas notificaciones del usuario (0016), en
// tiempo real. Al abrir una, se marca leída y se va a su link.
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useNotificaciones } from '@/composables/useNotificaciones'
import { ICONO_NOTIFICACION, tiempoRelativo } from '@/lib/notificaciones'

const router = useRouter()
const { lista, noLeidas, marcar } = useNotificaciones()

const abierta = ref(false)

function abrir(n) {
  abierta.value = false
  if (!n.leida_at) marcar([n.id])
  if (n.link) router.push(n.link)
}

function cerrarFuera(e) {
  if (!e.target.closest('.campana')) abierta.value = false
}

function cerrarConEscape(e) {
  if (e.key === 'Escape') abierta.value = false
}

onMounted(() => {
  document.addEventListener('click', cerrarFuera)
  document.addEventListener('keydown', cerrarConEscape)
})

onUnmounted(() => {
  document.removeEventListener('click', cerrarFuera)
  document.removeEventListener('keydown', cerrarConEscape)
})
</script>

<template>
  <div class="campana">
    <button
      type="button"
      class="boton"
      :aria-label="noLeidas ? `Notificaciones: ${noLeidas} sin leer` : 'Notificaciones'"
      :aria-expanded="abierta"
      @click="abierta = !abierta"
    >
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9" />
        <path d="M13.73 21a2 2 0 01-3.46 0" />
      </svg>
      <span v-if="noLeidas" class="contador">{{ noLeidas > 9 ? '9+' : noLeidas }}</span>
    </button>

    <div v-if="abierta" class="panel" role="dialog" aria-label="Notificaciones">
      <div class="panel-cabecera">
        <strong>Notificaciones</strong>
        <button v-if="noLeidas" type="button" class="marcar-todas" @click="marcar()">
          Marcar todas como leídas
        </button>
      </div>

      <p v-if="!lista.length" class="vacio">No tenés notificaciones.</p>

      <ul v-else class="lista">
        <li v-for="n in lista" :key="n.id">
          <button type="button" :class="['item', { nueva: !n.leida_at }]" @click="abrir(n)">
            <span class="icono" aria-hidden="true">{{ ICONO_NOTIFICACION[n.tipo] }}</span>
            <span class="texto">
              <strong>{{ n.titulo }}</strong>
              <span v-if="n.cuerpo" class="cuerpo">{{ n.cuerpo }}</span>
              <span class="cuando">{{ tiempoRelativo(n.created_at) }}</span>
            </span>
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.campana {
  position: relative;
}

.boton {
  position: relative;
  display: grid;
  place-items: center;
  width: 2.25rem;
  height: 2.25rem;
  border: none;
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
}

.boton:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.boton svg {
  width: 1.25rem;
  height: 1.25rem;
}

.contador {
  position: absolute;
  top: 0.125rem;
  right: 0.125rem;
  min-width: 1rem;
  padding: 0 0.25rem;
  border-radius: 999px;
  background: var(--danger);
  color: var(--on-primary);
  font-size: 0.625rem;
  font-weight: 700;
  line-height: 1rem;
  text-align: center;
}

.panel {
  position: absolute;
  top: calc(100% + 0.5rem);
  right: 0;
  z-index: 50;
  width: min(360px, calc(100vw - 2rem));
  max-height: 70vh;
  overflow-y: auto;
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--surface);
  box-shadow: var(--shadow-lg);
}

.panel-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--border);
}

.marcar-todas {
  border: none;
  background: none;
  color: var(--primary-text);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

.vacio {
  padding: 1.5rem 1rem;
  text-align: center;
  color: var(--text-muted);
  font-size: 0.875rem;
}

.lista {
  list-style: none;
}

.item {
  display: flex;
  gap: 0.625rem;
  width: 100%;
  padding: 0.75rem 1rem;
  border: none;
  border-bottom: 1px solid var(--border);
  background: transparent;
  color: var(--text);
  text-align: left;
  cursor: pointer;
}

.item:hover {
  background: var(--surface-hover);
}

.item.nueva {
  background: var(--primary-soft);
}

.icono {
  font-size: 1.125rem;
  line-height: 1.25rem;
}

.texto {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  min-width: 0;
  font-size: 0.8125rem;
}

.cuerpo {
  color: var(--text-2);
}

.cuando {
  color: var(--text-muted);
  font-size: 0.75rem;
}
</style>
