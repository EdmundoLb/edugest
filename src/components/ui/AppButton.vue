<script setup>
// Botón único de la app. Con `to` es un router-link; con `href`, un <a>;
// si no, un <button>. Reemplaza las clases de botón propias de cada vista.
import { computed } from 'vue'
import AppIcon from '@/components/ui/AppIcon.vue'

const props = defineProps({
  variante: {
    type: String,
    default: 'primario',
    validator: (v) => ['primario', 'secundario', 'fantasma', 'peligro', 'exito'].includes(v),
  },
  tamano: { type: String, default: 'md', validator: (v) => ['sm', 'md', 'lg'].includes(v) },
  icono: { type: String, default: '' },
  iconoDerecha: { type: String, default: '' },
  cargando: { type: Boolean, default: false },
  bloque: { type: Boolean, default: false },
  soloIcono: { type: Boolean, default: false },
  to: { type: [String, Object], default: null },
  href: { type: String, default: null },
  type: { type: String, default: 'button' },
  disabled: { type: Boolean, default: false },
})

const etiqueta = computed(() => (props.to ? 'router-link' : props.href ? 'a' : 'button'))
const tamanoIcono = computed(() => ({ sm: 16, md: 18, lg: 20 })[props.tamano])
</script>

<template>
  <component
    :is="etiqueta"
    :to="to ?? undefined"
    :href="href ?? undefined"
    :type="etiqueta === 'button' ? type : undefined"
    :disabled="etiqueta === 'button' ? disabled || cargando : undefined"
    :aria-disabled="etiqueta !== 'button' && disabled ? 'true' : undefined"
    :aria-busy="cargando ? 'true' : undefined"
    :class="[
      'app-btn',
      `app-btn--${variante}`,
      `app-btn--${tamano}`,
      { 'app-btn--bloque': bloque, 'app-btn--icono': soloIcono, 'app-btn--cargando': cargando },
    ]"
  >
    <span v-if="cargando" class="app-btn__spinner" aria-hidden="true" />
    <AppIcon v-else-if="icono" :nombre="icono" :tamano="tamanoIcono" />
    <span v-if="$slots.default" class="app-btn__texto"><slot /></span>
    <AppIcon v-if="iconoDerecha && !cargando" :nombre="iconoDerecha" :tamano="tamanoIcono" />
  </component>
</template>

<style scoped>
.app-btn {
  --alto: 40px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--sp-2);
  min-height: var(--alto);
  padding: 0 var(--sp-4);
  border: 1px solid transparent;
  border-radius: var(--radius-md);
  font-size: var(--fs-base);
  font-weight: var(--fw-semibold);
  line-height: 1;
  text-decoration: none;
  white-space: nowrap;
  cursor: pointer;
  user-select: none;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-fast) var(--ease-out),
    transform var(--motion-fast) var(--ease-out);
}

.app-btn:active:not(:disabled) {
  transform: translateY(1px) scale(0.99);
}

.app-btn:disabled,
.app-btn[aria-disabled='true'] {
  opacity: 0.5;
  cursor: not-allowed;
  pointer-events: none;
}

.app-btn--sm {
  --alto: 32px;
  padding: 0 var(--sp-3);
  font-size: var(--fs-sm);
  border-radius: var(--radius-sm);
}

.app-btn--lg {
  --alto: 48px;
  padding: 0 var(--sp-6);
  font-size: var(--fs-md);
}

.app-btn--bloque {
  width: 100%;
}

.app-btn--icono {
  width: var(--alto);
  padding: 0;
}

.app-btn--primario {
  background: var(--primary);
  color: var(--on-primary);
  box-shadow: var(--elev-1);
}

.app-btn--primario:hover {
  background: var(--primary-hover);
}

.app-btn--secundario {
  background: var(--surface);
  border-color: var(--border-strong);
  color: var(--text);
  box-shadow: var(--elev-1);
}

.app-btn--secundario:hover {
  background: var(--surface-hover);
}

.app-btn--fantasma {
  background: transparent;
  color: var(--text-2);
}

.app-btn--fantasma:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.app-btn--peligro {
  background: transparent;
  border-color: var(--danger-border);
  color: var(--danger-text);
}

.app-btn--peligro:hover {
  background: var(--danger-soft);
}

.app-btn--exito {
  background: var(--estado-presente);
  color: var(--on-primary);
}

.app-btn--exito:hover {
  filter: brightness(0.95);
}

.app-btn__spinner {
  width: 1em;
  height: 1em;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: girar 0.7s linear infinite;
}

@keyframes girar {
  to {
    transform: rotate(360deg);
  }
}
</style>
