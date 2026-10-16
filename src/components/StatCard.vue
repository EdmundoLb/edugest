<template>
  <div class="stat-card" :class="variant">
    <div class="stat-icon" v-if="$slots.icon">
      <slot name="icon" />
    </div>
    <span class="stat-value">{{ value }}</span>
    <span class="stat-label">{{ label }}</span>
  </div>
</template>

<script setup>
defineProps({
  value: {
    type: [String, Number],
    required: true,
  },
  label: {
    type: String,
    required: true,
  },
  variant: {
    type: String,
    default: '',
    validator: (v) => ['', 'presente', 'ausente', 'porcentaje'].includes(v),
  },
})
</script>

<style scoped>
.stat-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
}

.stat-icon {
  margin-bottom: 0.5rem;
  color: var(--text-muted);
}

.stat-icon :deep(svg) {
  width: 24px;
  height: 24px;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text);
}

.stat-label {
  font-size: 0.75rem;
  color: var(--text-muted);
  margin-top: 0.25rem;
}

.stat-card.presente .stat-value {
  color: var(--success-text);
}

.stat-card.ausente .stat-value {
  color: var(--danger-text);
}

.stat-card.porcentaje .stat-value {
  color: var(--primary-text);
}
</style>
