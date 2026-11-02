<script setup>
// Placeholder animado mientras carga. `lineas` > 1 arma un párrafo.
defineProps({
  forma: {
    type: String,
    default: 'linea',
    validator: (v) => ['linea', 'circulo', 'bloque'].includes(v),
  },
  ancho: { type: String, default: '100%' },
  alto: { type: String, default: '' },
  lineas: { type: Number, default: 1 },
})
</script>

<template>
  <span v-if="lineas > 1" class="skeleton-grupo" aria-hidden="true">
    <span
      v-for="n in lineas"
      :key="n"
      class="skeleton skeleton--linea"
      :style="{ width: n === lineas ? '60%' : '100%' }"
    />
  </span>
  <span
    v-else
    :class="['skeleton', `skeleton--${forma}`]"
    :style="{ width: ancho, height: alto || undefined }"
    aria-hidden="true"
  />
</template>

<style scoped>
.skeleton {
  display: block;
  border-radius: var(--radius-sm);
  background: linear-gradient(
    90deg,
    var(--surface-hover) 25%,
    var(--surface-2) 50%,
    var(--surface-hover) 75%
  );
  background-size: 200% 100%;
  animation: brillo-skeleton 1.4s ease-in-out infinite;
}

.skeleton--linea {
  height: 0.875rem;
}

.skeleton--circulo {
  border-radius: 50%;
  aspect-ratio: 1;
}

.skeleton--bloque {
  height: 120px;
  border-radius: var(--radius-lg);
}

.skeleton-grupo {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}
</style>
