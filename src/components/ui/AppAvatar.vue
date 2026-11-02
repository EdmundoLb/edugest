<script setup>
// Avatar con iniciales y un color estable por persona (o por curso).
import { computed } from 'vue'
import { iniciales, colorDeCurso } from '@/lib/ui'

const props = defineProps({
  nombre: { type: String, default: '' },
  // Para elegir el color; por defecto, el nombre.
  semilla: { type: String, default: '' },
  tamano: { type: String, default: 'md', validator: (v) => ['sm', 'md', 'lg', 'xl'].includes(v) },
})

const texto = computed(() => iniciales(props.nombre))
const color = computed(() => colorDeCurso(props.semilla || props.nombre))
</script>

<template>
  <span
    :class="['app-avatar', `app-avatar--${tamano}`]"
    :style="{ '--avatar-color': `var(--curso-${color})` }"
    aria-hidden="true"
  >
    {{ texto }}
  </span>
</template>

<style scoped>
.app-avatar {
  --lado: 36px;
  display: inline-grid;
  place-items: center;
  flex-shrink: 0;
  width: var(--lado);
  height: var(--lado);
  border-radius: 50%;
  background: color-mix(in srgb, var(--avatar-color) 18%, var(--surface));
  color: color-mix(in srgb, var(--avatar-color) 80%, var(--text));
  font-size: calc(var(--lado) * 0.38);
  font-weight: var(--fw-bold);
  letter-spacing: 0.01em;
  box-shadow: inset 0 0 0 1px color-mix(in srgb, var(--avatar-color) 30%, transparent);
}

.app-avatar--sm {
  --lado: 28px;
}

.app-avatar--lg {
  --lado: 48px;
}

.app-avatar--xl {
  --lado: 72px;
}
</style>
