<script setup>
// Encabezado común de las vistas internas: título, subtítulo opcional, link
// para volver y un slot para acciones a la derecha.
defineProps({
  titulo: { type: String, required: true },
  subtitulo: { type: String, default: '' },
  volver: { type: [String, Object], default: null },
})
</script>

<template>
  <header class="page-header">
    <div class="page-header-inner">
      <div class="page-header-texto">
        <router-link v-if="volver" :to="volver" class="btn-volver no-print" aria-label="Volver">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            aria-hidden="true"
          >
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
        </router-link>
        <div>
          <h1>{{ titulo }}</h1>
          <p v-if="subtitulo" class="subtitulo">{{ subtitulo }}</p>
        </div>
      </div>
      <div v-if="$slots.default" class="page-header-acciones no-print">
        <slot />
      </div>
    </div>
  </header>
</template>

<style scoped>
.page-header {
  background: var(--surface);
  border-bottom: 1px solid var(--border);
}

.page-header-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1.25rem 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
}

.page-header-texto {
  display: flex;
  align-items: center;
  gap: 0.875rem;
  min-width: 0;
}

h1 {
  font-size: 1.375rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  line-height: 1.25;
}

.subtitulo {
  margin-top: 0.125rem;
  font-size: 0.875rem;
  color: var(--text-muted);
}

.btn-volver {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 38px;
  height: 38px;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  color: var(--text-muted);
  transition: background 0.15s;
}

.btn-volver:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.btn-volver svg {
  width: 18px;
  height: 18px;
}

.page-header-acciones {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

@media (max-width: 600px) {
  .page-header-inner {
    padding: 1rem;
  }

  h1 {
    font-size: 1.1875rem;
  }
}
</style>
