<script setup>
import { useToast } from '@/composables/useToast'

const { toasts, cerrar } = useToast()
</script>

<template>
  <div class="toast-host no-print" aria-live="polite" aria-atomic="false">
    <transition-group name="toast">
      <div
        v-for="toast in toasts"
        :key="toast.id"
        :class="['toast', toast.tipo]"
        :role="toast.tipo === 'error' ? 'alert' : 'status'"
      >
        <span class="toast-icono" aria-hidden="true">
          {{ toast.tipo === 'exito' ? '✓' : toast.tipo === 'error' ? '!' : 'i' }}
        </span>
        <span class="toast-mensaje">{{ toast.mensaje }}</span>
        <button type="button" class="toast-cerrar" aria-label="Cerrar" @click="cerrar(toast.id)">
          ×
        </button>
      </div>
    </transition-group>
  </div>
</template>

<style scoped>
.toast-host {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 300;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  width: min(380px, calc(100vw - 2rem));
}

.toast {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 4px solid var(--primary);
  border-radius: var(--radius);
  box-shadow: var(--shadow-lg);
  font-size: 0.875rem;
  color: var(--text);
}

.toast.exito {
  border-left-color: var(--success);
}

.toast.error {
  border-left-color: var(--danger);
}

.toast-icono {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  font-size: 0.75rem;
  font-weight: 700;
  background: var(--primary-soft);
  color: var(--primary-text);
}

.exito .toast-icono {
  background: var(--success-soft);
  color: var(--success-text);
}

.error .toast-icono {
  background: var(--danger-soft);
  color: var(--danger-text);
}

.toast-mensaje {
  flex: 1;
  padding-top: 1px;
}

.toast-cerrar {
  border: none;
  background: none;
  color: var(--text-muted);
  font-size: 1.25rem;
  line-height: 1;
  cursor: pointer;
}

.toast-enter-active,
.toast-leave-active {
  transition:
    opacity 0.2s,
    transform 0.2s;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
</style>
