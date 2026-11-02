<script setup>
// Etiqueta corta de estado. Tonos semánticos de asistencia, de marca o de
// curso (curso-1..8). Con `punto` muestra un punto de color antes del texto.
defineProps({
  tono: { type: String, default: 'neutro' },
  punto: { type: Boolean, default: false },
  tamano: { type: String, default: 'md', validator: (v) => ['sm', 'md'].includes(v) },
})
</script>

<template>
  <span :class="['app-badge', `app-badge--${tono}`, `app-badge--${tamano}`]">
    <span v-if="punto" class="app-badge__punto" aria-hidden="true" />
    <slot />
  </span>
</template>

<style scoped>
.app-badge {
  --fondo: var(--surface-hover);
  --color: var(--text-2);
  --punto: var(--text-subtle);
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.125rem 0.5rem;
  border-radius: var(--radius-full);
  background: var(--fondo);
  color: var(--color);
  font-size: var(--fs-xs);
  font-weight: var(--fw-semibold);
  line-height: 1.5;
  white-space: nowrap;
}

.app-badge--sm {
  padding: 0 0.4375rem;
  font-size: 0.6875rem;
}

.app-badge__punto {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--punto);
}

.app-badge--primario,
.app-badge--tarde {
  --fondo: var(--estado-tarde-suave);
  --color: var(--estado-tarde-texto);
  --punto: var(--estado-tarde);
}

.app-badge--exito,
.app-badge--presente {
  --fondo: var(--estado-presente-suave);
  --color: var(--estado-presente-texto);
  --punto: var(--estado-presente);
}

.app-badge--peligro,
.app-badge--ausente {
  --fondo: var(--estado-ausente-suave);
  --color: var(--estado-ausente-texto);
  --punto: var(--estado-ausente);
}

.app-badge--alerta,
.app-badge--justificado {
  --fondo: var(--estado-justificado-suave);
  --color: var(--estado-justificado-texto);
  --punto: var(--estado-justificado);
}

.app-badge--solido {
  --fondo: var(--primary);
  --color: var(--on-primary);
  --punto: var(--on-primary);
}

.app-badge--curso-1 {
  --punto: var(--curso-1);
  --fondo: color-mix(in srgb, var(--curso-1) 14%, transparent);
}
.app-badge--curso-2 {
  --punto: var(--curso-2);
  --fondo: color-mix(in srgb, var(--curso-2) 14%, transparent);
}
.app-badge--curso-3 {
  --punto: var(--curso-3);
  --fondo: color-mix(in srgb, var(--curso-3) 14%, transparent);
}
.app-badge--curso-4 {
  --punto: var(--curso-4);
  --fondo: color-mix(in srgb, var(--curso-4) 14%, transparent);
}
.app-badge--curso-5 {
  --punto: var(--curso-5);
  --fondo: color-mix(in srgb, var(--curso-5) 14%, transparent);
}
.app-badge--curso-6 {
  --punto: var(--curso-6);
  --fondo: color-mix(in srgb, var(--curso-6) 14%, transparent);
}
.app-badge--curso-7 {
  --punto: var(--curso-7);
  --fondo: color-mix(in srgb, var(--curso-7) 14%, transparent);
}
.app-badge--curso-8 {
  --punto: var(--curso-8);
  --fondo: color-mix(in srgb, var(--curso-8) 14%, transparent);
}

[class*='app-badge--curso-'] {
  --color: var(--text);
}
</style>
