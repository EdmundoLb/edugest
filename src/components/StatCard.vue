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
    required: true
  },
  label: {
    type: String,
    required: true
  },
  variant: {
    type: String,
    default: '',
    validator: (v) => ['', 'presente', 'ausente', 'porcentaje'].includes(v)
  }
})
</script>

<style scoped>
.stat-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem;
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
}

.stat-icon {
  margin-bottom: 0.5rem;
  color: rgba(255, 255, 255, 0.5);
}

.stat-icon :deep(svg) {
  width: 24px;
  height: 24px;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #fff;
}

.stat-label {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.5);
  margin-top: 0.25rem;
}

.stat-card.presente .stat-value {
  color: #6ee7b7;
}

.stat-card.ausente .stat-value {
  color: #fca5a5;
}

.stat-card.porcentaje .stat-value {
  color: #004aad;
}
</style>