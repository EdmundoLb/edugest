<script setup>
// Barra inferior del celular: 4 destinos al alcance del pulgar y "Más", que
// abre un panel con el resto del menú, el tema y cerrar sesión.
import { ref, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { useTema } from '@/composables/useTema'
import { useContadoresNavegacion } from '@/composables/useEfectosSesion'
import { barraInferior, entradasPorRol, esRutaActiva, ROL_TEXTO } from '@/lib/navegacion'
import AppIcon from '@/components/ui/AppIcon.vue'
import AppAvatar from '@/components/ui/AppAvatar.vue'
import AppSheet from '@/components/ui/AppSheet.vue'

defineEmits(['salir'])

const route = useRoute()
const { state } = useAuth()
const { tema, alternarTema } = useTema()
const { contadores } = useContadoresNavegacion()

const masAbierto = ref(false)
const rol = computed(() => state.perfil?.rol)
const barra = computed(() => barraInferior(rol.value))
const entradas = computed(() => entradasPorRol(rol.value))
const nombre = computed(() => {
  const d = state.datosUsuario ?? state.perfil
  return d?.nombre ? `${d.nombre} ${d.apellido ?? ''}`.trim() : (state.user?.email ?? '')
})

const activo = (to) => esRutaActiva(route.path, to, entradas.value)
const badge = (item) => (item.badge ? contadores[item.badge]?.value || 0 : 0)
const masActivo = computed(() => barra.value.resto.some((e) => activo(e.to)))
const badgeMas = computed(() => barra.value.resto.reduce((n, e) => n + badge(e), 0))

watch(
  () => route.fullPath,
  () => (masAbierto.value = false),
)
</script>

<template>
  <nav class="barra-inferior no-print" aria-label="Navegación principal">
    <router-link
      v-for="item in barra.principales"
      :key="item.to"
      :to="item.to"
      :class="['destino', { activo: activo(item.to) }]"
      :aria-current="activo(item.to) ? 'page' : undefined"
    >
      <span class="destino-icono">
        <AppIcon :nombre="item.icono" :tamano="22" :grosor="activo(item.to) ? 2.4 : 2" />
        <span v-if="badge(item)" class="badge num">{{ badge(item) > 9 ? '9+' : badge(item) }}</span>
      </span>
      <span class="destino-texto">{{ item.corto ?? item.texto }}</span>
    </router-link>

    <button
      type="button"
      :class="['destino', { activo: masActivo }]"
      :aria-expanded="masAbierto"
      @click="masAbierto = true"
    >
      <span class="destino-icono">
        <AppIcon nombre="mas-opciones" :tamano="22" />
        <span v-if="badgeMas" class="badge num">{{ badgeMas > 9 ? '9+' : badgeMas }}</span>
      </span>
      <span class="destino-texto">Más</span>
    </button>
  </nav>

  <AppSheet v-model="masAbierto">
    <template #cabecera>
      <div class="cuenta">
        <AppAvatar :nombre="nombre" :semilla="state.user?.id" tamano="lg" />
        <div>
          <strong>{{ nombre }}</strong>
          <span>{{ ROL_TEXTO[rol] ?? '' }}</span>
        </div>
      </div>
    </template>

    <ul class="lista-mas">
      <li v-for="item in barra.resto" :key="item.to">
        <router-link :to="item.to" :class="['fila', { activo: activo(item.to) }]">
          <span class="fila-icono"><AppIcon :nombre="item.icono" :tamano="20" /></span>
          <span class="fila-texto">{{ item.texto }}</span>
          <span v-if="badge(item)" class="badge-fila num">{{ badge(item) }}</span>
          <AppIcon nombre="chevron-derecha" :tamano="18" class="fila-flecha" />
        </router-link>
      </li>
      <li>
        <button type="button" class="fila" @click="alternarTema">
          <span class="fila-icono"
            ><AppIcon :nombre="tema === 'dark' ? 'sol' : 'luna'" :tamano="20"
          /></span>
          <span class="fila-texto">{{ tema === 'dark' ? 'Tema claro' : 'Tema oscuro' }}</span>
        </button>
      </li>
      <li>
        <button type="button" class="fila fila--salir" @click="$emit('salir')">
          <span class="fila-icono"><AppIcon nombre="salir" :tamano="20" /></span>
          <span class="fila-texto">Cerrar sesión</span>
        </button>
      </li>
    </ul>
  </AppSheet>
</template>

<style scoped>
.barra-inferior {
  position: fixed;
  inset: auto 0 0;
  z-index: 90;
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 1fr;
  height: calc(var(--bottombar-alto) + env(safe-area-inset-bottom));
  padding-bottom: env(safe-area-inset-bottom);
  border-top: 1px solid var(--border);
  background: color-mix(in srgb, var(--surface) 88%, transparent);
  backdrop-filter: saturate(1.6) blur(14px);
  -webkit-backdrop-filter: saturate(1.6) blur(14px);
}

.destino {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.1875rem;
  border: none;
  background: transparent;
  color: var(--text-muted);
  font-size: 0.6875rem;
  font-weight: var(--fw-semibold);
  text-decoration: none;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.destino.activo {
  color: var(--primary-text);
}

.destino-icono {
  position: relative;
  display: grid;
  place-items: center;
  width: 56px;
  height: 30px;
  border-radius: var(--radius-full);
  transition: background-color var(--motion-base) var(--ease-out);
}

.destino.activo .destino-icono {
  background: var(--primary-soft-strong);
}

.destino:active .destino-icono {
  transform: scale(0.94);
}

.badge {
  position: absolute;
  top: -3px;
  right: 8px;
  min-width: 17px;
  padding: 0 4px;
  border: 2px solid var(--surface);
  border-radius: var(--radius-full);
  background: var(--danger);
  color: var(--on-primary);
  font-size: 0.625rem;
  font-weight: var(--fw-bold);
  line-height: 13px;
  text-align: center;
}

.cuenta {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
}

.cuenta div {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
}

.cuenta span {
  font-size: var(--fs-sm);
  color: var(--text-muted);
}

.lista-mas {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: var(--sp-1);
}

.fila {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  width: 100%;
  min-height: 52px;
  padding: 0 var(--sp-3);
  border: none;
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--text);
  font-size: var(--fs-md);
  font-weight: var(--fw-medium);
  text-align: left;
  text-decoration: none;
  cursor: pointer;
}

.fila:hover,
.fila.activo {
  background: var(--surface-hover);
}

.fila-icono {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-md);
  background: var(--azul-50);
  color: var(--primary-text);
}

.fila-texto {
  flex: 1;
}

.fila-flecha {
  color: var(--text-subtle);
}

.badge-fila {
  min-width: 22px;
  padding: 0 0.375rem;
  border-radius: var(--radius-full);
  background: var(--danger);
  color: var(--on-primary);
  font-size: var(--fs-xs);
  font-weight: var(--fw-bold);
  line-height: 22px;
  text-align: center;
}

.fila--salir {
  color: var(--danger-text);
}

.fila--salir .fila-icono {
  background: var(--danger-soft);
  color: var(--danger-text);
}
</style>
