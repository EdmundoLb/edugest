<script setup>
// Una fila de "Llamar lista". Tocar al alumno alterna presente/ausente; el
// control de la derecha da los cuatro estados, y el lápiz abre la observación.
// Los valores viven en el padre (v-model:estado / v-model:observacion).
import { ref, computed } from 'vue'
import { ESTADOS_LISTA, TEXTO_ESTADO, alternarEstado, vibrar } from '@/lib/lista'
import AppAvatar from '@/components/ui/AppAvatar.vue'
import AppIcon from '@/components/ui/AppIcon.vue'
import AppSegmented from '@/components/ui/AppSegmented.vue'

const props = defineProps({
  alumno: { type: Object, required: true },
  deshabilitado: { type: Boolean, default: false },
  // Motivo de un aviso pendiente de la familia para esta fecha (0014).
  aviso: { type: String, default: '' },
})

const estado = defineModel('estado', { type: String, default: 'presente' })
const observacion = defineModel('observacion', { type: String, default: '' })

const notaAbierta = ref(Boolean(observacion.value))
const nombreCompleto = computed(() => `${props.alumno.nombre} ${props.alumno.apellido}`)

function marcar(nuevo) {
  if (props.deshabilitado || nuevo === estado.value) return
  estado.value = nuevo
  vibrar()
}
</script>

<template>
  <div :class="['fila-asistencia', `fila-asistencia--${estado}`]">
    <button
      type="button"
      class="alumno"
      :disabled="deshabilitado"
      :aria-label="`${nombreCompleto}: ${TEXTO_ESTADO[estado]}. Tocá para marcar ${TEXTO_ESTADO[alternarEstado(estado)].toLowerCase()}.`"
      @click="marcar(alternarEstado(estado))"
    >
      <span class="avatar">
        <AppAvatar :nombre="nombreCompleto" :semilla="String(alumno.id)" />
        <span class="avatar-estado" aria-hidden="true">
          <AppIcon v-if="estado === 'ausente'" nombre="cerrar" :tamano="11" :grosor="3" />
          <AppIcon v-else-if="estado === 'tarde'" nombre="reloj" :tamano="11" :grosor="3" />
          <AppIcon v-else nombre="check" :tamano="11" :grosor="3" />
        </span>
      </span>
      <span class="nombre">
        <span class="nombre-texto"
          ><strong>{{ alumno.apellido }}</strong
          >, {{ alumno.nombre }}</span
        >
        <span v-if="aviso" class="aviso-familia" :title="aviso">
          <AppIcon nombre="bandeja" :tamano="13" />
          Aviso de la familia: {{ aviso }}
        </span>
      </span>
    </button>

    <AppSegmented
      :model-value="estado"
      :opciones="ESTADOS_LISTA"
      :nombre="`asistencia-${alumno.id}`"
      :etiqueta="`Asistencia de ${nombreCompleto}`"
      :deshabilitado="deshabilitado"
      compacto
      @update:model-value="marcar"
    />

    <button
      type="button"
      :class="['nota', { 'nota--con-texto': observacion }]"
      :aria-label="`Observación para ${nombreCompleto}`"
      :aria-expanded="notaAbierta"
      :title="observacion || 'Agregar observación'"
      @click="notaAbierta = !notaAbierta"
    >
      <AppIcon nombre="editar" :tamano="17" />
    </button>

    <input
      v-if="notaAbierta"
      v-model="observacion"
      type="text"
      class="observacion"
      placeholder="Observación (opcional)"
      :aria-label="`Observación para ${nombreCompleto}`"
      :disabled="deshabilitado"
    />
  </div>
</template>

<style scoped>
.fila-asistencia {
  --tono: var(--estado-presente);
  --tono-suave: var(--estado-presente-suave);
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  align-items: center;
  gap: var(--sp-2) var(--sp-3);
  padding: var(--sp-2) var(--sp-2) var(--sp-2) var(--sp-3);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--surface);
  transition:
    background-color var(--motion-base) var(--ease-out),
    border-color var(--motion-base) var(--ease-out);
}

.fila-asistencia--ausente {
  --tono: var(--estado-ausente);
  --tono-suave: var(--estado-ausente-suave);
  border-color: color-mix(in srgb, var(--estado-ausente) 35%, var(--border));
  background: color-mix(in srgb, var(--estado-ausente-suave) 55%, var(--surface));
}

.fila-asistencia--tarde {
  --tono: var(--estado-tarde);
  --tono-suave: var(--estado-tarde-suave);
}

.fila-asistencia--justificado {
  --tono: var(--estado-justificado);
  --tono-suave: var(--estado-justificado-suave);
}

.alumno {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  min-width: 0;
  min-height: 48px;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--text);
  text-align: left;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}

.alumno:active .avatar {
  transform: scale(0.94);
}

.avatar {
  position: relative;
  flex-shrink: 0;
  transition: transform var(--motion-fast) var(--ease-out);
}

.avatar-estado {
  position: absolute;
  right: -3px;
  bottom: -3px;
  display: grid;
  place-items: center;
  width: 18px;
  height: 18px;
  border: 2px solid var(--surface);
  border-radius: 50%;
  background: var(--tono);
  color: var(--on-primary);
  transition: background-color var(--motion-base) var(--ease-out);
}

.nombre {
  display: flex;
  flex-direction: column;
  min-width: 0;
  line-height: 1.3;
}

.nombre-texto {
  font-size: var(--fs-base);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.nombre strong {
  font-weight: var(--fw-semibold);
}

.aviso-familia {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  margin-top: 0.125rem;
  font-size: var(--fs-xs);
  font-weight: var(--fw-medium);
  color: var(--warning-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.nota {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border: none;
  border-radius: var(--radius-md);
  background: transparent;
  color: var(--text-subtle);
  cursor: pointer;
}

.nota:hover {
  background: var(--surface-hover);
  color: var(--text);
}

.nota--con-texto {
  color: var(--primary-text);
  background: var(--primary-soft);
}

.observacion {
  grid-column: 1 / -1;
  width: 100%;
  padding: var(--sp-2) var(--sp-3);
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  background: var(--surface-2);
  color: var(--text);
  font-size: var(--fs-sm);
}

.observacion::placeholder {
  color: var(--text-subtle);
}

.observacion:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: var(--focus-ring);
}

@media (max-width: 560px) {
  .fila-asistencia {
    grid-template-columns: minmax(0, 1fr) auto;
  }

  .fila-asistencia > :deep(.segmentado) {
    grid-column: 1 / -1;
    grid-row: 2;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
  }

  .nota {
    grid-column: 2;
    grid-row: 1;
  }
}
</style>
