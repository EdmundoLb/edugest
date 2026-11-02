<script setup>
// Tarjeta base. Con `to` es un router-link completo (área clickeable grande,
// con hover y foco), útil para accesos rápidos y listas.
defineProps({
  to: { type: [String, Object], default: null },
  padding: {
    type: String,
    default: 'md',
    validator: (v) => ['none', 'sm', 'md', 'lg'].includes(v),
  },
  // Borde izquierdo de color: 'primario' | 'exito' | 'peligro' | 'alerta' | 'curso-N'.
  acento: { type: String, default: '' },
  elevada: { type: Boolean, default: false },
})
</script>

<template>
  <component
    :is="to ? 'router-link' : 'section'"
    :to="to ?? undefined"
    :class="[
      'app-card',
      `app-card--pad-${padding}`,
      {
        'app-card--link': to,
        'app-card--elevada': elevada,
        [`app-card--acento-${acento}`]: acento,
      },
    ]"
  >
    <slot />
  </component>
</template>

<style scoped>
.app-card {
  display: block;
  position: relative;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  color: var(--text);
  text-decoration: none;
}

.app-card--pad-none {
  padding: 0;
}

.app-card--pad-sm {
  padding: var(--sp-3) var(--sp-4);
}

.app-card--pad-md {
  padding: var(--sp-5);
}

.app-card--pad-lg {
  padding: var(--sp-6) var(--sp-8);
}

.app-card--elevada {
  box-shadow: var(--elev-2);
}

.app-card--link {
  transition:
    border-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-base) var(--ease-out),
    transform var(--motion-base) var(--ease-out);
}

.app-card--link:hover {
  border-color: var(--primary-border);
  box-shadow: var(--elev-2);
  transform: translateY(-2px);
}

.app-card--link:active {
  transform: translateY(0);
}

[class*='app-card--acento-'] {
  border-left-width: 4px;
}

.app-card--acento-primario {
  border-left-color: var(--primary);
}

.app-card--acento-exito {
  border-left-color: var(--estado-presente);
}

.app-card--acento-peligro {
  border-left-color: var(--estado-ausente);
}

.app-card--acento-alerta {
  border-left-color: var(--estado-justificado);
}

.app-card--acento-curso-1 {
  border-left-color: var(--curso-1);
}
.app-card--acento-curso-2 {
  border-left-color: var(--curso-2);
}
.app-card--acento-curso-3 {
  border-left-color: var(--curso-3);
}
.app-card--acento-curso-4 {
  border-left-color: var(--curso-4);
}
.app-card--acento-curso-5 {
  border-left-color: var(--curso-5);
}
.app-card--acento-curso-6 {
  border-left-color: var(--curso-6);
}
.app-card--acento-curso-7 {
  border-left-color: var(--curso-7);
}
.app-card--acento-curso-8 {
  border-left-color: var(--curso-8);
}
</style>
