<script setup>
// Paleta de comandos (Ctrl/⌘ + K): ir a cualquier pantalla del rol y, para
// docentes y admin, buscar alumnos por nombre o CI. Se maneja con teclado.
import { ref, computed, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/stores/auth'
import { useTema } from '@/composables/useTema'
import { entradasPorRol, filtrarComandos, puntajeCoincidencia } from '@/lib/navegacion'
import { buscarAlumnos } from '@/lib/api/admin'
import AppIcon from '@/components/ui/AppIcon.vue'
import AppAvatar from '@/components/ui/AppAvatar.vue'

const emit = defineEmits(['salir'])
const abierta = defineModel({ type: Boolean, default: false })

const router = useRouter()
const { state } = useAuth()
const { tema, alternarTema } = useTema()

const consulta = ref('')
const alumnos = ref([])
const buscando = ref(false)
const seleccion = ref(0)
const entrada = ref(null)
let temporizador = null
let busquedaActual = 0

const puedeBuscarAlumnos = computed(() => ['docente', 'admin'].includes(state.perfil?.rol))

const acciones = computed(() => [
  {
    id: 'tema',
    texto: tema.value === 'dark' ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
    icono: tema.value === 'dark' ? 'sol' : 'luna',
  },
  { id: 'salir', texto: 'Cerrar sesión', icono: 'salir' },
])

const resultados = computed(() => {
  const pantallas = filtrarComandos(entradasPorRol(state.perfil?.rol), consulta.value).map((e) => ({
    tipo: 'pantalla',
    clave: e.to,
    texto: e.texto,
    detalle: e.grupo,
    icono: e.icono,
    to: e.to,
  }))
  const deAlumnos = alumnos.value.map((a) => ({
    tipo: 'alumno',
    clave: a.id,
    texto: `${a.apellido}, ${a.nombre}`,
    detalle: `CI ${a.ci}`,
    to: `/Estudiantes/${a.id}`,
  }))
  const deAcciones = filtrarComandos(acciones.value, consulta.value).map((a) => ({
    tipo: 'accion',
    clave: a.id,
    texto: a.texto,
    icono: a.icono,
    id: a.id,
  }))
  // Las pantallas que coinciden solo por letras salteadas (ej. "ana" en
  // "Calendario") van después de los alumnos encontrados.
  const fuerte = (r) => puntajeCoincidencia(r.texto, consulta.value) > 1
  return [
    ...pantallas.filter(fuerte),
    ...deAlumnos,
    ...pantallas.filter((r) => !fuerte(r)),
    ...deAcciones,
  ]
})

watch(abierta, async (v) => {
  if (!v) return
  consulta.value = ''
  alumnos.value = []
  seleccion.value = 0
  await nextTick()
  entrada.value?.focus()
})

watch(consulta, (texto) => {
  seleccion.value = 0
  clearTimeout(temporizador)
  if (!puedeBuscarAlumnos.value || texto.trim().length < 2) {
    alumnos.value = []
    buscando.value = false
    return
  }
  buscando.value = true
  temporizador = setTimeout(async () => {
    const numero = ++busquedaActual
    try {
      const r = await buscarAlumnos(texto, 6)
      if (numero === busquedaActual) alumnos.value = r
    } catch {
      if (numero === busquedaActual) alumnos.value = []
    } finally {
      if (numero === busquedaActual) buscando.value = false
    }
  }, 250)
})

function ejecutar(r) {
  if (!r) return
  abierta.value = false
  if (r.to) router.push(r.to)
  else if (r.id === 'tema') alternarTema()
  else if (r.id === 'salir') emit('salir')
}

function alTeclear(e) {
  const n = resultados.value.length
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    seleccion.value = n ? (seleccion.value + 1) % n : 0
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    seleccion.value = n ? (seleccion.value - 1 + n) % n : 0
  } else if (e.key === 'Enter') {
    e.preventDefault()
    ejecutar(resultados.value[seleccion.value])
  } else if (e.key === 'Escape') {
    abierta.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="paleta">
      <div v-if="abierta" class="paleta-fondo" @click.self="abierta = false">
        <div class="paleta" role="dialog" aria-modal="true" aria-label="Buscar o ir a">
          <div class="paleta-entrada">
            <AppIcon nombre="buscar" :tamano="20" />
            <input
              ref="entrada"
              v-model="consulta"
              type="text"
              :placeholder="
                puedeBuscarAlumnos ? 'Buscar un alumno o ir a una pantalla…' : 'Ir a una pantalla…'
              "
              aria-label="Buscar"
              autocomplete="off"
              role="combobox"
              aria-expanded="true"
              aria-controls="paleta-resultados"
              :aria-activedescendant="resultados[seleccion] ? `paleta-${seleccion}` : undefined"
              @keydown="alTeclear"
            />
            <kbd>Esc</kbd>
          </div>

          <ul id="paleta-resultados" class="paleta-lista" role="listbox">
            <li
              v-for="(r, i) in resultados"
              :id="`paleta-${i}`"
              :key="`${r.tipo}-${r.clave}`"
              role="option"
              :aria-selected="i === seleccion"
              :class="['resultado', { seleccionado: i === seleccion }]"
              @mousemove="seleccion = i"
              @click="ejecutar(r)"
            >
              <AppAvatar
                v-if="r.tipo === 'alumno'"
                :nombre="r.texto.split(', ').reverse().join(' ')"
                tamano="sm"
              />
              <span v-else class="resultado-icono"><AppIcon :nombre="r.icono" :tamano="18" /></span>
              <span class="resultado-texto">{{ r.texto }}</span>
              <span v-if="r.detalle" class="resultado-detalle">{{ r.detalle }}</span>
              <AppIcon
                v-if="i === seleccion"
                nombre="flecha-derecha"
                :tamano="16"
                class="resultado-ir"
              />
            </li>
            <li v-if="buscando" class="paleta-estado">Buscando alumnos…</li>
            <li v-else-if="!resultados.length" class="paleta-estado">
              Sin resultados para “{{ consulta }}”.
            </li>
          </ul>

          <footer class="paleta-pie">
            <span><kbd>↑</kbd><kbd>↓</kbd> moverse</span>
            <span><kbd>Enter</kbd> abrir</span>
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.paleta-fondo {
  position: fixed;
  inset: 0;
  z-index: 160;
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding: 12vh var(--sp-4) var(--sp-4);
  background: var(--overlay);
  backdrop-filter: blur(3px);
}

.paleta {
  display: flex;
  flex-direction: column;
  width: min(640px, 100%);
  max-height: 70vh;
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  background: var(--surface);
  box-shadow: var(--elev-3);
  overflow: hidden;
}

.paleta-entrada {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-bottom: 1px solid var(--border);
  color: var(--text-muted);
}

.paleta-entrada input {
  flex: 1;
  border: none;
  background: transparent;
  color: var(--text);
  font-size: var(--fs-md);
  outline: none;
}

kbd {
  display: inline-block;
  min-width: 1.5em;
  padding: 0.0625rem 0.375rem;
  border: 1px solid var(--border-strong);
  border-bottom-width: 2px;
  border-radius: 5px;
  background: var(--surface-2);
  color: var(--text-muted);
  font-family: inherit;
  font-size: 0.6875rem;
  text-align: center;
}

.paleta-lista {
  list-style: none;
  padding: var(--sp-2);
  overflow-y: auto;
}

.resultado {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  min-height: 44px;
  padding: 0 var(--sp-3);
  border-radius: var(--radius-md);
  cursor: pointer;
}

.resultado.seleccionado {
  background: var(--primary-soft);
}

.resultado-icono {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: var(--radius-sm);
  background: var(--surface-hover);
  color: var(--text-2);
}

.seleccionado .resultado-icono {
  background: var(--surface);
  color: var(--primary-text);
}

.resultado-texto {
  flex: 1;
  font-weight: var(--fw-medium);
}

.resultado-detalle {
  font-size: var(--fs-xs);
  color: var(--text-muted);
}

.resultado-ir {
  color: var(--primary-text);
}

.paleta-estado {
  padding: var(--sp-6);
  text-align: center;
  color: var(--text-muted);
  font-size: var(--fs-sm);
}

.paleta-pie {
  display: flex;
  gap: var(--sp-4);
  padding: var(--sp-2) var(--sp-5);
  border-top: 1px solid var(--border);
  background: var(--surface-2);
  color: var(--text-muted);
  font-size: var(--fs-xs);
}

.paleta-pie kbd + kbd {
  margin-left: 2px;
}

.paleta-enter-active,
.paleta-leave-active {
  transition: opacity var(--motion-fast) var(--ease-out);
}

.paleta-enter-active .paleta {
  transition: transform var(--motion-base) var(--ease-out);
}

.paleta-enter-from,
.paleta-leave-to {
  opacity: 0;
}

.paleta-enter-from .paleta {
  transform: translateY(-8px) scale(0.98);
}

@media (max-width: 640px) {
  .paleta-fondo {
    padding: var(--sp-3);
  }

  .paleta-pie {
    display: none;
  }
}
</style>
