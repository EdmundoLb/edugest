<script setup>
import { nextTick, ref, watch } from 'vue'
import { useDialogoActual } from '@/composables/useConfirm'

const dialogo = useDialogoActual()
const botonAceptar = ref(null)

watch(dialogo, async (d) => {
  if (d) {
    await nextTick()
    botonAceptar.value?.focus()
  }
})

function teclado(e) {
  if (e.key === 'Escape') dialogo.value?.resolver(false)
}
</script>

<template>
  <transition name="dialogo">
    <div v-if="dialogo" class="overlay" @click.self="dialogo.resolver(false)" @keydown="teclado">
      <div
        class="dialogo"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="dialogo-titulo"
        :aria-describedby="dialogo.mensaje ? 'dialogo-mensaje' : undefined"
      >
        <h2 id="dialogo-titulo">{{ dialogo.titulo }}</h2>
        <p v-if="dialogo.mensaje" id="dialogo-mensaje">{{ dialogo.mensaje }}</p>
        <div class="acciones">
          <button type="button" class="btn btn-secundario" @click="dialogo.resolver(false)">
            {{ dialogo.cancelar }}
          </button>
          <button
            ref="botonAceptar"
            type="button"
            :class="['btn', dialogo.peligro ? 'btn-peligro' : 'btn-primario']"
            @click="dialogo.resolver(true)"
          >
            {{ dialogo.aceptar }}
          </button>
        </div>
      </div>
    </div>
  </transition>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  z-index: 250;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background: var(--overlay);
}

.dialogo {
  width: min(440px, 100%);
  padding: 1.5rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
}

h2 {
  font-size: 1.125rem;
  font-weight: 700;
}

p {
  margin-top: 0.5rem;
  font-size: 0.9375rem;
  color: var(--text-2);
}

.acciones {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 1.5rem;
}

.btn {
  padding: 0.625rem 1.125rem;
  border-radius: var(--radius-sm);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  border: 1px solid transparent;
}

.btn-secundario {
  background: transparent;
  border-color: var(--border-strong);
  color: var(--text);
}

.btn-secundario:hover {
  background: var(--surface-hover);
}

.btn-primario {
  background: var(--primary);
  color: var(--on-primary);
}

.btn-primario:hover {
  background: var(--primary-hover);
}

.btn-peligro {
  background: var(--danger);
  color: #fff;
}

.dialogo-enter-active,
.dialogo-leave-active {
  transition: opacity 0.15s;
}

.dialogo-enter-from,
.dialogo-leave-to {
  opacity: 0;
}
</style>
