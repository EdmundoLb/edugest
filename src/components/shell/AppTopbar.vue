<script setup>
// Barra superior de las pantallas internas. En computadora: buscador
// (Ctrl/⌘ + K) y campanita. En celular: la marca, la lupa y la campanita
// (la navegación va abajo, en AppBottomBar).
import { computed } from 'vue'
import { useAuth } from '@/stores/auth'
import CampanaNotificaciones from '@/components/CampanaNotificaciones.vue'
import AppIcon from '@/components/ui/AppIcon.vue'
import { useListaOffline } from '@/composables/useListaOffline'

defineEmits(['buscar'])

const { rutaInicio } = useAuth()
const { pendientes } = useListaOffline()

const esMac = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform)
const atajo = computed(() => (esMac ? '⌘K' : 'Ctrl K'))
</script>

<template>
  <header class="topbar no-print">
    <router-link :to="rutaInicio()" class="marca-movil" aria-label="EduGest, ir al inicio">
      <span class="marca-logo"
        ><img src="@/images/edugest-logo.png" alt="" class="logo-edugest"
      /></span>
      <span class="marca-texto">EduGest</span>
    </router-link>

    <button type="button" class="buscador" @click="$emit('buscar')">
      <AppIcon nombre="buscar" :tamano="18" />
      <span class="buscador-texto">Buscar o ir a…</span>
      <kbd>{{ atajo }}</kbd>
    </button>

    <div class="acciones">
      <span
        v-if="pendientes.length"
        class="offline"
        :title="`${pendientes.length} lista(s) guardadas sin conexión esperando para enviarse`"
      >
        <AppIcon nombre="sin-conexion" :tamano="16" />
        <span class="num">{{ pendientes.length }}</span>
      </span>
      <button type="button" class="icono-btn lupa" aria-label="Buscar" @click="$emit('buscar')">
        <AppIcon nombre="buscar" :tamano="20" />
      </button>
      <CampanaNotificaciones />
    </div>
  </header>
</template>

<style scoped>
.topbar {
  position: sticky;
  top: 0;
  z-index: 80;
  display: flex;
  align-items: center;
  gap: var(--sp-4);
  height: var(--topbar-alto);
  padding: 0 var(--sp-6);
  border-bottom: 1px solid var(--border);
  background: color-mix(in srgb, var(--bg) 82%, transparent);
  backdrop-filter: saturate(1.6) blur(14px);
  -webkit-backdrop-filter: saturate(1.6) blur(14px);
}

.marca-movil {
  display: none;
  align-items: center;
  gap: var(--sp-2);
  color: var(--text);
  text-decoration: none;
}

.marca-logo {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-md);
  background: var(--azul-50);
}

.marca-logo img {
  width: 22px;
  height: auto;
}

.marca-texto {
  font-size: var(--fs-md);
  font-weight: var(--fw-bold);
  letter-spacing: var(--tracking-tight);
}

.buscador {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  width: min(420px, 100%);
  height: 38px;
  padding: 0 var(--sp-3);
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--surface);
  color: var(--text-subtle);
  font-size: var(--fs-sm);
  cursor: pointer;
  transition:
    border-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-fast) var(--ease-out);
}

.buscador:hover {
  border-color: var(--border-strong);
  box-shadow: var(--elev-1);
}

.buscador-texto {
  flex: 1;
  text-align: left;
}

kbd {
  padding: 0.0625rem 0.375rem;
  border: 1px solid var(--border-strong);
  border-bottom-width: 2px;
  border-radius: 5px;
  background: var(--surface-2);
  color: var(--text-muted);
  font-family: inherit;
  font-size: 0.6875rem;
}

.acciones {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  margin-left: auto;
}

.offline {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.125rem 0.5rem;
  border-radius: var(--radius-full);
  background: var(--warning-soft);
  color: var(--warning-text);
  font-size: var(--fs-xs);
  font-weight: var(--fw-bold);
}

.icono-btn {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border: none;
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
}

.icono-btn:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.lupa {
  display: none;
}

@media (max-width: 1023px) {
  .topbar {
    padding: 0 var(--sp-3) 0 var(--sp-4);
  }

  .marca-movil {
    display: flex;
  }

  .buscador {
    display: none;
  }

  .lupa {
    display: grid;
  }
}
</style>
