<script setup>
// Pestañas accesibles (role="tablist"), con contador opcional.
// opciones: [{ valor, texto, contador? }]
defineProps({
  opciones: { type: Array, required: true },
  etiqueta: { type: String, default: '' },
})

const modelo = defineModel({ type: [String, Number], required: true })

function mover(e, opciones, indice) {
  const siguiente = { ArrowRight: 1, ArrowLeft: -1 }[e.key]
  if (!siguiente) return
  e.preventDefault()
  const destino = opciones[(indice + siguiente + opciones.length) % opciones.length]
  modelo.value = destino.valor
  e.currentTarget.parentElement.children[opciones.indexOf(destino)]?.focus()
}
</script>

<template>
  <div class="tabs" role="tablist" :aria-label="etiqueta || undefined">
    <button
      v-for="(op, i) in opciones"
      :key="op.valor"
      type="button"
      role="tab"
      :aria-selected="modelo === op.valor"
      :tabindex="modelo === op.valor ? 0 : -1"
      :class="['tab', { activa: modelo === op.valor }]"
      @click="modelo = op.valor"
      @keydown="mover($event, opciones, i)"
    >
      {{ op.texto }}
      <span v-if="op.contador" class="contador num">{{ op.contador }}</span>
    </button>
  </div>
</template>

<style scoped>
.tabs {
  display: flex;
  gap: var(--sp-1);
  border-bottom: 1px solid var(--border);
  overflow-x: auto;
  scrollbar-width: none;
}

.tab {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-4);
  border: none;
  background: none;
  color: var(--text-muted);
  font-size: var(--fs-base);
  font-weight: var(--fw-semibold);
  white-space: nowrap;
  cursor: pointer;
  transition: color var(--motion-fast) var(--ease-out);
}

.tab:hover {
  color: var(--text);
}

.tab::after {
  content: '';
  position: absolute;
  left: var(--sp-3);
  right: var(--sp-3);
  bottom: -1px;
  height: 2px;
  border-radius: 2px;
  background: var(--primary);
  transform: scaleX(0);
  transition: transform var(--motion-base) var(--ease-out);
}

.tab.activa {
  color: var(--primary-text);
}

.tab.activa::after {
  transform: scaleX(1);
}

.contador {
  padding: 0 0.4375rem;
  border-radius: var(--radius-full);
  background: var(--primary-soft-strong);
  color: var(--primary-text);
  font-size: var(--fs-xs);
}
</style>
