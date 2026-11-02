<script setup>
// Encabezado de las páginas públicas (inicio y catálogo de desarrollo). Las
// pantallas internas usan el AppShell (barra lateral / inferior), que vive en
// src/components/shell/.
import { computed } from 'vue'
import { useAuth } from '@/stores/auth'
import { useTema } from '@/composables/useTema'
import AppButton from '@/components/ui/AppButton.vue'
import AppIcon from '@/components/ui/AppIcon.vue'

const { state, rutaInicio } = useAuth()
const { tema, alternarTema } = useTema()

const sesionActiva = computed(() => Boolean(state.session && state.perfil))
</script>

<template>
  <header class="navbar no-print">
    <div class="navbar-inner">
      <router-link to="/" class="logo" aria-label="EduGest, inicio">
        <span class="logo-marca">
          <img src="@/images/edugest-logo.png" alt="" class="logo-edugest" />
        </span>
        <span class="logo-texto">EduGest</span>
      </router-link>

      <div class="acciones">
        <button
          type="button"
          class="icono-btn"
          :aria-label="tema === 'dark' ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro'"
          :title="tema === 'dark' ? 'Tema claro' : 'Tema oscuro'"
          @click="alternarTema"
        >
          <AppIcon :nombre="tema === 'dark' ? 'sol' : 'luna'" :tamano="18" />
        </button>
        <AppButton v-if="sesionActiva" :to="rutaInicio()" icono-derecha="flecha-derecha">
          Ir a mi panel
        </AppButton>
        <template v-else>
          <AppButton variante="fantasma" to="/Registro" class="registrarse">Crear cuenta</AppButton>
          <AppButton to="/login">Iniciar sesión</AppButton>
        </template>
      </div>
    </div>
  </header>
</template>

<style scoped>
.navbar {
  position: fixed;
  inset: 0 0 auto;
  z-index: 100;
  height: var(--navbar-height);
  border-bottom: 1px solid var(--border);
  background: color-mix(in srgb, var(--surface) 82%, transparent);
  backdrop-filter: saturate(1.6) blur(14px);
  -webkit-backdrop-filter: saturate(1.6) blur(14px);
}

.navbar-inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  max-width: 1200px;
  height: 100%;
  margin: 0 auto;
  padding: 0 var(--sp-6);
}

.logo {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  color: var(--text);
  text-decoration: none;
}

.logo-marca {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-md);
  background: var(--azul-50);
}

.logo-marca img {
  width: 26px;
  height: auto;
}

.logo-texto {
  font-size: var(--fs-lg);
  font-weight: var(--fw-bold);
  letter-spacing: var(--tracking-tight);
}

.acciones {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
}

.icono-btn {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--surface);
  color: var(--text-muted);
  cursor: pointer;
}

.icono-btn:hover {
  background: var(--surface-hover);
  color: var(--text);
}

@media (max-width: 560px) {
  .navbar-inner {
    padding: 0 var(--sp-4);
  }

  .registrarse {
    display: none;
  }
}
</style>
