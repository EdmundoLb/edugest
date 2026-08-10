<template>
  <div v-if="totalPages > 1" class="pagination">
    <button
      class="page-btn"
      :disabled="currentPage === 1"
      @click="$emit('page-change', currentPage - 1)"
      aria-label="Página anterior"
    >
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M15 18l-6-6 6-6" />
      </svg>
    </button>

    <template v-for="page in visiblePages" :key="page">
      <span v-if="page === '...'" class="page-ellipsis">...</span>
      <button
        v-else
        class="page-btn"
        :class="{ active: page === currentPage }"
        @click="$emit('page-change', page)"
        :aria-label="`Página ${page}`"
        :aria-current="page === currentPage ? 'page' : undefined"
      >
        {{ page }}
      </button>
    </template>

    <button
      class="page-btn"
      :disabled="currentPage === totalPages"
      @click="$emit('page-change', currentPage + 1)"
      aria-label="Página siguiente"
    >
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M9 18l6-6-6-6" />
      </svg>
    </button>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  currentPage: {
    type: Number,
    required: true
  },
  totalPages: {
    type: Number,
    required: true
  },
  maxVisible: {
    type: Number,
    default: 5
  }
})

defineEmits(['page-change'])

const visiblePages = computed(() => {
  const pages = []
  const total = props.totalPages
  const current = props.currentPage
  const max = props.maxVisible

  if (total <= max) {
    for (let i = 1; i <= total; i++) {
      pages.push(i)
    }
  } else {
    const half = Math.floor(max / 2)
    let start = Math.max(1, current - half)
    let end = Math.min(total, start + max - 1)

    if (end - start < max - 1) {
      start = Math.max(1, end - max + 1)
    }

    if (start > 1) {
      pages.push(1)
      if (start > 2) pages.push('...')
    }

    for (let i = start; i <= end; i++) {
      pages.push(i)
    }

    if (end < total) {
      if (end < total - 1) pages.push('...')
      pages.push(total)
    }
  }

  return pages
})
</script>

<style scoped>
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
  margin-top: 1.5rem;
}

.page-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 36px;
  height: 36px;
  padding: 0 0.5rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.page-btn:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
}

.page-btn.active {
  background: #004aad;
  border-color: #004aad;
  color: #fff;
}

.page-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.page-btn svg {
  width: 16px;
  height: 16px;
}

.page-ellipsis {
  color: rgba(255, 255, 255, 0.3);
  font-size: 0.875rem;
  padding: 0 0.25rem;
}
</style>