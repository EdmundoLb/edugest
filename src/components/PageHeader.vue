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
  animation: aparecer var(--motion-slow) var(--ease-out) both;
}

.page-header-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: var(--sp-8) var(--sp-6) var(--sp-2);
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--sp-4);
  flex-wrap: wrap;
}

.page-header-texto {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  min-width: 0;
}

h1 {
  font-size: var(--fs-2xl);
  font-weight: var(--fw-bold);
  letter-spacing: var(--tracking-tight);
  line-height: var(--lh-tight);
}

.subtitulo {
  margin-top: var(--sp-1);
  font-size: var(--fs-base);
  color: var(--text-muted);
}

.btn-volver {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--surface);
  color: var(--text-muted);
  box-shadow: var(--elev-1);
  transition:
    background-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out);
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
  gap: var(--sp-2);
  flex-wrap: wrap;
}

@media (max-width: 600px) {
  .page-header-inner {
    padding: var(--sp-5) var(--sp-4) var(--sp-1);
  }

  h1 {
    font-size: var(--fs-xl);
  }
}

@media print {
  .page-header-inner {
    padding: 0 0 var(--sp-4);
  }
}
</style>
