<template>
  <div class="empty-state">
    <div class="empty-icon">
      <slot name="icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" />
          <polyline points="14 2 14 8 20 8" />
        </svg>
      </slot>
    </div>
    <p class="empty-title">{{ title }}</p>
    <span v-if="hint" class="empty-hint">{{ hint }}</span>
    <div v-if="$slots.action" class="empty-action">
      <slot name="action" />
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: {
    type: String,
    required: true
  },
  hint: {
    type: String,
    default: ''
  }
})
</script>

<style scoped>
.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  color: rgba(255, 255, 255, 0.5);
}

.empty-icon {
  margin-bottom: 1rem;
}

.empty-icon :deep(svg) {
  width: 48px;
  height: 48px;
  color: rgba(255, 255, 255, 0.2);
}

.empty-title {
  font-size: 1rem;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.7);
  margin: 0;
}

.empty-hint {
  display: block;
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.3);
  margin-top: 0.5rem;
}

.empty-action {
  margin-top: 1.5rem;
}
</style>