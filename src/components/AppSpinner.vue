<template>
  <div class="spinner" :class="[size, variant]" />
</template>

<script setup>
defineProps({
  size: {
    type: String,
    default: 'medium',
    validator: (v) => ['small', 'medium', 'large'].includes(v),
  },
  variant: {
    type: String,
    default: 'primary',
    validator: (v) => ['primary', 'light'].includes(v),
  },
})
</script>

<style scoped>
.spinner {
  border: 2px solid var(--border-strong);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

.spinner.light {
  border-color: var(--border-strong);
  border-top-color: var(--on-primary);
}

.spinner.small {
  width: 16px;
  height: 16px;
}

.spinner.medium {
  width: 28px;
  height: 28px;
}

.spinner.large {
  width: 40px;
  height: 40px;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
