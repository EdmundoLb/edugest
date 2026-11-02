<script setup>
// Modo "uno por uno" de Llamar lista: una tarjeta grande por alumno, se marca
// y pasa solo al siguiente. Se puede deshacer, y en computadora se maneja con
// las teclas P, A, T, J (y Retroceso para deshacer).
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { ESTADOS_LISTA, TEXTO_ESTADO, contarEstados, estadoPorTecla, vibrar } from '@/lib/lista'
import AppAvatar from '@/components/ui/AppAvatar.vue'
import AppButton from '@/components/ui/AppButton.vue'
import AppIcon from '@/components/ui/AppIcon.vue'
import AppProgressBar from '@/components/ui/AppProgressBar.vue'

const props = defineProps({
  alumnos: { type: Array, required: true },
  asistencia: { type: Object, required: true },
  avisos: { type: Map, default: () => new Map() },
  deshabilitado: { type: Boolean, default: false },
})

const emit = defineEmits(['marcar', 'ver-lista'])

const indice = ref(0)
const historial = ref([]) // [{ indice, id, previo }]

const actual = computed(() => props.alumnos[indice.value] ?? null)
const terminado = computed(() => indice.value >= props.alumnos.length)
const avance = computed(() =>
  props.alumnos.length
    ? (Math.min(indice.value, props.alumnos.length) / props.alumnos.length) * 100
    : 0,
)
const totales = computed(() => contarEstados(props.alumnos, props.asistencia))
const nombreActual = computed(() =>
  actual.value ? `${actual.value.nombre} ${actual.value.apellido}` : '',
)

const secundarios = ESTADOS_LISTA.filter((e) => e.valor === 'tarde' || e.valor === 'justificado')

function marcar(estado) {
  if (props.deshabilitado || !actual.value) return
  historial.value.push({
    indice: indice.value,
    id: actual.value.id,
    previo: props.asistencia[actual.value.id],
  })
  emit('marcar', actual.value.id, estado)
  vibrar()
  indice.value++
}

function deshacer() {
  const ultimo = historial.value.pop()
  if (!ultimo) return
  emit('marcar', ultimo.id, ultimo.previo)
  indice.value = ultimo.indice
}

function anterior() {
  if (indice.value > 0) indice.value--
}

function saltar() {
  if (!terminado.value) indice.value++
}

function empezarDeNuevo() {
  indice.value = 0
  historial.value = []
}

function alTeclear(e) {
  if (e.ctrlKey || e.metaKey || e.altKey) return
  if (e.target.closest?.('input, textarea, select, [contenteditable]')) return
  if (e.key === 'Backspace') {
    e.preventDefault()
    deshacer()
    return
  }
  const estado = estadoPorTecla(e.key)
  if (estado && !terminado.value) {
    e.preventDefault()
    marcar(estado)
  }
}

onMounted(() => window.addEventListener('keydown', alTeclear))
onUnmounted(() => window.removeEventListener('keydown', alTeclear))
</script>

<template>
  <section class="uno-por-uno" aria-label="Tomar lista de a un alumno">
    <div class="progreso">
      <span class="progreso-texto num">
        {{ Math.min(indice + 1, alumnos.length) }} de {{ alumnos.length }}
      </span>
      <AppProgressBar :valor="avance" tono="primario" :alto="6" etiqueta="Avance de la lista" />
    </div>

    <div v-if="!terminado" :key="actual.id" class="tarjeta-alumno aparecer" aria-live="polite">
      <AppAvatar :nombre="nombreActual" :semilla="String(actual.id)" tamano="xl" />
      <h2 class="nombre">
        {{ actual.nombre }} <strong>{{ actual.apellido }}</strong>
      </h2>
      <p v-if="avisos.get(actual.id)" class="aviso-familia">
        <AppIcon nombre="bandeja" :tamano="15" />
        Aviso de la familia: {{ avisos.get(actual.id) }}
      </p>
      <p class="marcado">
        Ahora:
        <span :class="`marcado--${asistencia[actual.id]}`">{{
          TEXTO_ESTADO[asistencia[actual.id]]
        }}</span>
      </p>

      <div class="principales">
        <button
          type="button"
          class="grande grande--presente"
          :disabled="deshabilitado"
          @click="marcar('presente')"
        >
          <AppIcon nombre="check" :tamano="28" :grosor="2.6" />
          Presente
          <kbd aria-hidden="true">P</kbd>
        </button>
        <button
          type="button"
          class="grande grande--ausente"
          :disabled="deshabilitado"
          @click="marcar('ausente')"
        >
          <AppIcon nombre="cerrar" :tamano="28" :grosor="2.6" />
          Ausente
          <kbd aria-hidden="true">A</kbd>
        </button>
      </div>

      <div class="secundarios">
        <AppButton
          v-for="e in secundarios"
          :key="e.valor"
          variante="secundario"
          :icono="e.valor === 'tarde' ? 'reloj' : 'documento'"
          :disabled="deshabilitado"
          bloque
          @click="marcar(e.valor)"
        >
          {{ e.texto }}
        </AppButton>
      </div>
    </div>

    <div v-else class="tarjeta-alumno tarjeta-fin aparecer">
      <span class="fin-icono"><AppIcon nombre="check-circulo" :tamano="40" /></span>
      <h2 class="nombre">¡Lista completa!</h2>
      <p class="fin-resumen">
        <strong class="num">{{ totales.presente + totales.tarde }}</strong> presentes ·
        <strong class="num">{{ totales.ausente }}</strong> ausentes
        <template v-if="totales.justificado">
          · <strong class="num">{{ totales.justificado }}</strong> justificados</template
        >
      </p>
      <p class="fin-ayuda">Revisá si hace falta y guardá con el botón de abajo.</p>
      <div class="fin-acciones">
        <AppButton variante="secundario" icono="lista" @click="emit('ver-lista')">
          Ver como lista
        </AppButton>
        <AppButton variante="fantasma" icono="deshacer" @click="empezarDeNuevo">
          Empezar de nuevo
        </AppButton>
      </div>
    </div>

    <div class="navegacion">
      <AppButton
        variante="fantasma"
        tamano="sm"
        icono="deshacer"
        :disabled="!historial.length || deshabilitado"
        @click="deshacer"
      >
        Deshacer
      </AppButton>
      <div class="navegacion-pasos">
        <AppButton
          variante="fantasma"
          tamano="sm"
          solo-icono
          icono="chevron-izquierda"
          aria-label="Alumno anterior"
          :disabled="indice === 0"
          @click="anterior"
        />
        <AppButton
          variante="fantasma"
          tamano="sm"
          icono-derecha="chevron-derecha"
          :disabled="terminado"
          @click="saltar"
        >
          Saltar
        </AppButton>
      </div>
    </div>
  </section>
</template>

<style scoped>
.uno-por-uno {
  display: flex;
  flex-direction: column;
  gap: var(--sp-4);
}

.progreso {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
}

.progreso-texto {
  flex-shrink: 0;
  font-size: var(--fs-sm);
  font-weight: var(--fw-semibold);
  color: var(--text-muted);
}

.progreso > :last-child {
  flex: 1;
}

.tarjeta-alumno {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-8) var(--sp-5) var(--sp-5);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  background: var(--surface);
  box-shadow: var(--elev-2);
  text-align: center;
}

.nombre {
  font-size: var(--fs-2xl);
  font-weight: var(--fw-medium);
  letter-spacing: var(--tracking-tight);
  line-height: 1.2;
}

.nombre strong {
  font-weight: var(--fw-bold);
}

.aviso-familia {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  padding: var(--sp-1) var(--sp-3);
  border-radius: var(--radius-full);
  background: var(--warning-soft);
  color: var(--warning-text);
  font-size: var(--fs-sm);
  font-weight: var(--fw-medium);
}

.marcado {
  font-size: var(--fs-sm);
  color: var(--text-muted);
}

.marcado span {
  font-weight: var(--fw-semibold);
}

.marcado--presente {
  color: var(--estado-presente-texto);
}

.marcado--ausente {
  color: var(--estado-ausente-texto);
}

.marcado--tarde {
  color: var(--estado-tarde-texto);
}

.marcado--justificado {
  color: var(--estado-justificado-texto);
}

.principales {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sp-3);
  width: 100%;
  margin-top: var(--sp-3);
}

.grande {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--sp-2);
  min-height: 120px;
  border: 2px solid transparent;
  border-radius: var(--radius-xl);
  font-size: var(--fs-lg);
  font-weight: var(--fw-bold);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  transition:
    transform var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-fast) var(--ease-out);
}

.grande:hover:not(:disabled) {
  box-shadow: var(--elev-2);
}

.grande:active:not(:disabled) {
  transform: scale(0.97);
}

.grande:focus-visible {
  outline: 2px solid var(--primary-text);
  outline-offset: 2px;
}

.grande:disabled {
  opacity: 0.5;
  cursor: default;
}

.grande--presente {
  border-color: color-mix(in srgb, var(--estado-presente) 40%, transparent);
  background: var(--estado-presente-suave);
  color: var(--estado-presente-texto);
}

.grande--ausente {
  border-color: color-mix(in srgb, var(--estado-ausente) 40%, transparent);
  background: var(--estado-ausente-suave);
  color: var(--estado-ausente-texto);
}

.grande kbd {
  position: absolute;
  top: var(--sp-2);
  right: var(--sp-3);
  padding: 0 0.375rem;
  border: 1px solid currentColor;
  border-radius: 5px;
  font-family: inherit;
  font-size: 0.6875rem;
  opacity: 0.55;
}

.secundarios {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sp-3);
  width: 100%;
}

.fin-icono {
  display: grid;
  place-items: center;
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: var(--estado-presente-suave);
  color: var(--estado-presente-texto);
}

.fin-resumen {
  font-size: var(--fs-md);
  color: var(--text-2);
}

.fin-ayuda {
  font-size: var(--fs-sm);
  color: var(--text-muted);
}

.fin-acciones {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--sp-2);
  margin-top: var(--sp-2);
}

.navegacion {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.navegacion-pasos {
  display: flex;
  gap: var(--sp-1);
}

@media (hover: none) {
  .grande kbd {
    display: none;
  }
}
</style>
