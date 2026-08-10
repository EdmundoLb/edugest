<template>
  <div class="spinner" :class="size" />
</template>

<script setup>
defineProps({
  size: {
    type: String,
    default: 'medium',
    validator: (v) => ['small', 'medium', 'large'].includes(v)
  }
})
</script>

<style scoped>
.spinner {
  border: 2px solid rgba(255, 255, 255, 0.15);
  border-top-color: var(--color-primary, #004aad);
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
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