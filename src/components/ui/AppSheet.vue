<script setup>
// Panel modal: en computadora es un diálogo centrado; en celular sube desde
// abajo (bottom sheet). Cierra con Esc, tocando afuera o con la X, y devuelve
// el foco a donde estaba.
import { ref, watch, nextTick, onBeforeUnmount } from 'vue'
import AppIcon from '@/components/ui/AppIcon.vue'

defineProps({
  titulo: { type: String, default: '' },
  ancho: { type: String, default: '520px' },
})

const abierto = defineModel({ type: Boolean, default: false })
const panel = ref(null)
let focoAnterior = null

function cerrar() {
  abierto.value = false
}

function alTeclear(e) {
  if (e.key === 'Escape') cerrar()
}

watch(abierto, async (valor) => {
  if (valor) {
    focoAnterior = document.activeElement
    document.addEventListener('keydown', alTeclear)
    document.body.style.overflow = 'hidden'
    await nextTick()
    panel.value?.querySelector('input, select, textarea, button, a[href]')?.focus()
  } else {
    document.removeEventListener('keydown', alTeclear)
    document.body.style.overflow = ''
    focoAnterior?.focus?.()
  }
})

onBeforeUnmount(() => {
  document.removeEventListener('keydown', alTeclear)
  document.body.style.overflow = ''
})

defineExpose({ cerrar })
</script>

<template>
  <Teleport to="body">
    <Transition name="sheet">
      <div v-if="abierto" class="sheet-fondo" @click.self="cerrar">
        <div
          ref="panel"
          class="sheet"
          role="dialog"
          aria-modal="true"
          :aria-label="titulo || undefined"
          :style="{ '--sheet-ancho': ancho }"
        >
          <span class="sheet-agarre" aria-hidden="true" />
          <header v-if="titulo || $slots.cabecera" class="sheet-cabecera">
            <slot name="cabecera">
              <h2>{{ titulo }}</h2>
            </slot>
            <button type="button" class="sheet-cerrar" aria-label="Cerrar" @click="cerrar">
              <AppIcon nombre="cerrar" :tamano="20" />
            </button>
          </header>
          <div class="sheet-cuerpo">
            <slot :cerrar="cerrar" />
          </div>
          <footer v-if="$slots.pie" class="sheet-pie">
            <slot name="pie" :cerrar="cerrar" />
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.sheet-fondo {
  position: fixed;
  inset: 0;
  z-index: 150;
  display: grid;
  place-items: center;
  padding: var(--sp-4);
  background: var(--overlay);
  backdrop-filter: blur(2px);
}

.sheet {
  display: flex;
  flex-direction: column;
  width: min(var(--sheet-ancho), 100%);
  max-height: min(85vh, 760px);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  background: var(--surface);
  box-shadow: var(--elev-3);
  overflow: hidden;
}

.sheet-agarre {
  display: none;
}

.sheet-cabecera {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-3);
}

.sheet-cabecera h2 {
  font-size: var(--fs-lg);
  font-weight: var(--fw-bold);
  letter-spacing: var(--tracking-tight);
}

.sheet-cerrar {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border: none;
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
}

.sheet-cerrar:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.sheet-cuerpo {
  padding: 0 var(--sp-5) var(--sp-5);
  overflow-y: auto;
  overscroll-behavior: contain;
}

.sheet-pie {
  display: flex;
  justify-content: flex-end;
  gap: var(--sp-2);
  padding: var(--sp-4) var(--sp-5);
  border-top: 1px solid var(--border);
}

.sheet-enter-active,
.sheet-leave-active {
  transition: opacity var(--motion-base) var(--ease-out);
}

.sheet-enter-active .sheet,
.sheet-leave-active .sheet {
  transition: transform var(--motion-slow) var(--ease-out);
}

.sheet-enter-from,
.sheet-leave-to {
  opacity: 0;
}

.sheet-enter-from .sheet,
.sheet-leave-to .sheet {
  transform: translateY(12px) scale(0.98);
}

@media (max-width: 640px) {
  .sheet-fondo {
    place-items: end stretch;
    padding: 0;
  }

  .sheet {
    width: 100%;
    max-height: 88vh;
    border-radius: var(--radius-xl) var(--radius-xl) 0 0;
    padding-bottom: env(safe-area-inset-bottom);
  }

  .sheet-agarre {
    display: block;
    width: 40px;
    height: 4px;
    margin: var(--sp-2) auto 0;
    border-radius: var(--radius-full);
    background: var(--border-strong);
  }

  .sheet-enter-from .sheet,
  .sheet-leave-to .sheet {
    transform: translateY(100%);
  }
}
</style>
