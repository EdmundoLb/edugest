<script setup>
// Barra lateral de la app en computadora: menú agrupado por rol, badges en
// vivo y la cuenta del usuario abajo. Se puede colapsar a solo íconos.
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { useTema } from '@/composables/useTema'
import { useContadoresNavegacion } from '@/composables/useEfectosSesion'
import { menuPorRol, entradasPorRol, esRutaActiva, ROL_TEXTO } from '@/lib/navegacion'
import AppIcon from '@/components/ui/AppIcon.vue'
import AppAvatar from '@/components/ui/AppAvatar.vue'

defineEmits(['salir'])
const colapsada = defineModel('colapsada', { type: Boolean, default: false })

const route = useRoute()
const { state, rutaInicio } = useAuth()
const { tema, alternarTema } = useTema()
const { contadores } = useContadoresNavegacion()

const rol = computed(() => state.perfil?.rol)
const grupos = computed(() => menuPorRol(rol.value))
const entradas = computed(() => entradasPorRol(rol.value))

const nombre = computed(() => {
  const d = state.datosUsuario ?? state.perfil
  return d?.nombre ? `${d.nombre} ${d.apellido ?? ''}`.trim() : (state.user?.email ?? '')
})

const activo = (to) => esRutaActiva(route.path, to, entradas.value)
const badge = (item) => (item.badge ? contadores[item.badge]?.value || 0 : 0)
</script>

<template>
  <aside :class="['sidebar', { colapsada }]" aria-label="Menú principal">
    <div class="marca">
      <router-link :to="rutaInicio()" class="marca-link" aria-label="EduGest, ir al inicio">
        <span class="marca-logo">
          <img src="@/images/edugest-logo.png" alt="" class="logo-edugest" />
        </span>
        <span v-if="!colapsada" class="marca-texto">EduGest</span>
      </router-link>
      <button
        type="button"
        class="colapsar"
        :aria-label="colapsada ? 'Expandir menú' : 'Colapsar menú'"
        :title="colapsada ? 'Expandir menú' : 'Colapsar menú'"
        @click="colapsada = !colapsada"
      >
        <AppIcon nombre="panel-lateral" :tamano="18" />
      </button>
    </div>

    <nav class="navegacion">
      <div v-for="g in grupos" :key="g.grupo" class="grupo">
        <p v-if="!colapsada" class="grupo-titulo">{{ g.grupo }}</p>
        <span v-else class="grupo-separador" aria-hidden="true" />
        <router-link
          v-for="item in g.items"
          :key="item.to"
          :to="item.to"
          :class="['item', { activo: activo(item.to) }]"
          :aria-current="activo(item.to) ? 'page' : undefined"
          :title="colapsada ? item.texto : undefined"
        >
          <span class="item-icono">
            <AppIcon :nombre="item.icono" :tamano="19" />
            <span v-if="colapsada && badge(item)" class="punto-badge" aria-hidden="true" />
          </span>
          <span v-if="!colapsada" class="item-texto">{{ item.texto }}</span>
          <span v-if="!colapsada && badge(item)" class="item-badge num">
            {{ badge(item) > 99 ? '99+' : badge(item) }}
          </span>
          <span v-if="badge(item)" class="sr-only">({{ badge(item) }} pendientes)</span>
        </router-link>
      </div>
    </nav>

    <div class="pie">
      <button
        type="button"
        class="item item--boton"
        :title="colapsada ? (tema === 'dark' ? 'Tema claro' : 'Tema oscuro') : undefined"
        @click="alternarTema"
      >
        <span class="item-icono"
          ><AppIcon :nombre="tema === 'dark' ? 'sol' : 'luna'" :tamano="19"
        /></span>
        <span v-if="!colapsada" class="item-texto">{{
          tema === 'dark' ? 'Tema claro' : 'Tema oscuro'
        }}</span>
      </button>

      <div class="usuario">
        <AppAvatar :nombre="nombre" :semilla="state.user?.id" tamano="md" />
        <div v-if="!colapsada" class="usuario-datos">
          <strong>{{ nombre }}</strong>
          <span>{{ ROL_TEXTO[rol] ?? '' }}</span>
        </div>
        <button
          type="button"
          class="salir"
          aria-label="Cerrar sesión"
          title="Cerrar sesión"
          @click="$emit('salir')"
        >
          <AppIcon nombre="salir" :tamano="18" />
        </button>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  width: var(--sidebar-ancho);
  height: 100vh;
  height: 100dvh;
  padding: var(--sp-3);
  border-right: 1px solid var(--border);
  background: var(--surface);
  transition: width var(--motion-base) var(--ease-out);
}

.sidebar.colapsada {
  width: var(--sidebar-ancho-colapsado);
}

.marca {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-2);
  padding: var(--sp-1) var(--sp-1) var(--sp-4);
}

.colapsada .marca {
  flex-direction: column;
}

.marca-link {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  color: var(--text);
  text-decoration: none;
}

.marca-logo {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-md);
  background: var(--azul-50);
}

.marca-logo img {
  width: 26px;
  height: auto;
}

.marca-texto {
  font-size: var(--fs-lg);
  font-weight: var(--fw-bold);
  letter-spacing: var(--tracking-tight);
}

.colapsar {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border: none;
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
}

.colapsar:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.navegacion {
  flex: 1;
  overflow-y: auto;
  scrollbar-width: thin;
}

.grupo + .grupo {
  margin-top: var(--sp-4);
}

.grupo-titulo {
  padding: 0 var(--sp-3) var(--sp-2);
  font-size: 0.6875rem;
  font-weight: var(--fw-semibold);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-subtle);
}

.grupo-separador {
  display: block;
  height: 1px;
  margin: 0 var(--sp-2) var(--sp-2);
  background: var(--border);
}

.item {
  position: relative;
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  width: 100%;
  min-height: 40px;
  padding: 0 var(--sp-3);
  border: none;
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--text-2);
  font-size: var(--fs-base);
  font-weight: var(--fw-medium);
  text-align: left;
  text-decoration: none;
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out);
}

.colapsada .item {
  justify-content: center;
  padding: 0;
}

.item:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.item.activo {
  background: var(--primary-soft);
  color: var(--primary-text);
  font-weight: var(--fw-semibold);
}

.item.activo::before {
  content: '';
  position: absolute;
  left: -12px;
  top: 8px;
  bottom: 8px;
  width: 3px;
  border-radius: 0 3px 3px 0;
  background: var(--primary);
}

.item-icono {
  position: relative;
  display: grid;
  place-items: center;
}

.item-texto {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.item-badge {
  min-width: 20px;
  padding: 0 0.375rem;
  border-radius: var(--radius-full);
  background: var(--danger);
  color: var(--on-primary);
  font-size: 0.6875rem;
  font-weight: var(--fw-bold);
  line-height: 20px;
  text-align: center;
}

.punto-badge {
  position: absolute;
  top: -2px;
  right: -4px;
  width: 8px;
  height: 8px;
  border: 2px solid var(--surface);
  border-radius: 50%;
  background: var(--danger);
}

.pie {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  padding-top: var(--sp-3);
  border-top: 1px solid var(--border);
}

.usuario {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-2);
  border-radius: var(--radius-md);
  background: var(--surface-2);
}

.colapsada .usuario {
  flex-direction: column;
  background: transparent;
  padding: 0;
}

.usuario-datos {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
  line-height: 1.25;
}

.usuario-datos strong {
  font-size: var(--fs-sm);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.usuario-datos span {
  font-size: var(--fs-xs);
  color: var(--text-muted);
}

.salir {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border: none;
  border-radius: var(--radius-sm);
  background: transparent;
  color: var(--text-muted);
  cursor: pointer;
}

.salir:hover {
  background: var(--danger-soft);
  color: var(--danger-text);
}
</style>
