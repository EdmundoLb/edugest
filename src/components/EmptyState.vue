<template>
  <div :class="['empty-state', { 'empty-state--compacto': compacto }]">
    <div class="empty-ilustracion" aria-hidden="true">
      <span class="empty-halo" />
      <span class="empty-punto empty-punto--1" />
      <span class="empty-punto empty-punto--2" />
      <span class="empty-punto empty-punto--3" />
      <span class="empty-icono">
        <slot name="icon">
          <AppIcon :nombre="icono" :tamano="compacto ? 22 : 28" :grosor="1.75" />
        </slot>
      </span>
    </div>
    <p class="empty-title">{{ title }}</p>
    <span v-if="hint" class="empty-hint">{{ hint }}</span>
    <div v-if="$slots.action" class="empty-action">
      <slot name="action" />
    </div>
  </div>
</template>

<script setup>
// Estado vacío con una ilustración liviana (ícono sobre un halo con puntos de
// color de la marca) y una acción opcional. Mantiene `title`, `hint` y los
// slots `icon` / `action` de la versión anterior.
import AppIcon from '@/components/ui/AppIcon.vue'

defineProps({
  title: { type: String, required: true },
  hint: { type: String, default: '' },
  icono: { type: String, default: 'bandeja' },
  compacto: { type: Boolean, default: false },
})
</script>

<style scoped>
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: var(--sp-12) var(--sp-6);
  color: var(--text-muted);
  animation: aparecer var(--motion-slow) var(--ease-out) both;
}

.empty-state--compacto {
  padding: var(--sp-6) var(--sp-4);
}

.empty-ilustracion {
  position: relative;
  display: grid;
  place-items: center;
  width: 96px;
  height: 96px;
  margin-bottom: var(--sp-5);
}

.empty-state--compacto .empty-ilustracion {
  width: 64px;
  height: 64px;
  margin-bottom: var(--sp-3);
}

.empty-halo {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: radial-gradient(
    circle,
    var(--primary-soft-strong) 0%,
    var(--primary-soft) 55%,
    transparent 72%
  );
}

.empty-icono {
  position: relative;
  display: grid;
  place-items: center;
  width: 60%;
  height: 60%;
  border-radius: 30%;
  background: var(--surface);
  border: 1px solid var(--border);
  box-shadow: var(--elev-2);
  color: var(--primary-text);
}

.empty-icono :deep(svg) {
  width: 50%;
  height: 50%;
}

.empty-punto {
  position: absolute;
  border-radius: 50%;
}

.empty-punto--1 {
  top: 8%;
  right: 6%;
  width: 10px;
  height: 10px;
  background: var(--curso-2);
  opacity: 0.7;
}

.empty-punto--2 {
  bottom: 12%;
  left: 4%;
  width: 7px;
  height: 7px;
  background: var(--curso-4);
  opacity: 0.6;
}

.empty-punto--3 {
  top: 22%;
  left: 10%;
  width: 5px;
  height: 5px;
  background: var(--curso-8);
  opacity: 0.8;
}

.empty-state--compacto .empty-punto {
  display: none;
}

.empty-title {
  margin: 0;
  font-size: var(--fs-md);
  font-weight: var(--fw-semibold);
  color: var(--text);
}

.empty-hint {
  display: block;
  max-width: 42ch;
  margin-top: var(--sp-2);
  font-size: var(--fs-sm);
  line-height: var(--lh-base);
  color: var(--text-muted);
}

.empty-action {
  margin-top: var(--sp-5);
}
</style>
