<script setup>
// Una fila de "Llamar lista": nombre del alumno, los tres estados posibles y
// la observación. Los valores viven en el padre (v-model:estado / v-model:observacion).
defineProps({
  alumno: { type: Object, required: true },
  deshabilitado: { type: Boolean, default: false },
})

const estado = defineModel('estado', { type: String, default: 'presente' })
const observacion = defineModel('observacion', { type: String, default: '' })

const OPCIONES = [
  { valor: 'presente', texto: 'Presente', corto: 'P' },
  { valor: 'ausente', texto: 'Ausente', corto: 'A' },
  { valor: 'justificado', texto: 'Justificado', corto: 'J' },
]
</script>

<template>
  <div :class="['fila', estado]">
    <div class="alumno">
      <span class="avatar" aria-hidden="true">{{ alumno.apellido?.charAt(0)?.toUpperCase() }}</span>
      <span class="nombre">
        <strong>{{ alumno.apellido }}</strong
        >, {{ alumno.nombre }}
      </span>
    </div>

    <div
      class="opciones"
      role="radiogroup"
      :aria-label="`Asistencia de ${alumno.nombre} ${alumno.apellido}`"
    >
      <label
        v-for="op in OPCIONES"
        :key="op.valor"
        :class="['opcion', op.valor, { activa: estado === op.valor }]"
      >
        <input
          v-model="estado"
          type="radio"
          class="sr-only"
          :name="`asistencia-${alumno.id}`"
          :value="op.valor"
          :disabled="deshabilitado"
        />
        <span class="texto-largo">{{ op.texto }}</span>
        <span class="texto-corto" aria-hidden="true">{{ op.corto }}</span>
      </label>
    </div>

    <input
      v-model="observacion"
      type="text"
      class="observacion"
      placeholder="Observación (opcional)"
      :aria-label="`Observación para ${alumno.nombre} ${alumno.apellido}`"
      :disabled="deshabilitado"
    />
  </div>
</template>

<style scoped>
.fila {
  display: grid;
  grid-template-columns: minmax(180px, 1fr) auto minmax(160px, 1fr);
  align-items: center;
  gap: 0.75rem 1rem;
  padding: 0.75rem 1rem;
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 4px solid var(--success);
  border-radius: var(--radius);
}

.fila.ausente {
  border-left-color: var(--danger);
}

.fila.justificado {
  border-left-color: var(--warning);
}

.alumno {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  min-width: 0;
}

.avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 34px;
  height: 34px;
  border-radius: 50%;
  background: var(--primary-soft);
  color: var(--primary-text);
  font-size: 0.8125rem;
  font-weight: 700;
}

.nombre {
  font-size: 0.9375rem;
  overflow: hidden;
  text-overflow: ellipsis;
}

.nombre strong {
  font-weight: 600;
}

.opciones {
  display: flex;
  gap: 0.375rem;
}

.opcion {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 44px;
  min-height: 40px;
  padding: 0 0.875rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-sm);
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--text-muted);
  cursor: pointer;
  user-select: none;
  transition:
    background 0.12s,
    color 0.12s,
    border-color 0.12s;
}

.opcion:hover {
  background: var(--surface-hover);
}

.opcion:focus-within {
  box-shadow: var(--focus-ring);
}

.opcion.presente.activa {
  background: var(--success-soft);
  border-color: var(--success-border);
  color: var(--success-text);
}

.opcion.ausente.activa {
  background: var(--danger-soft);
  border-color: var(--danger-border);
  color: var(--danger-text);
}

.opcion.justificado.activa {
  background: var(--warning-soft);
  border-color: var(--warning-border);
  color: var(--warning-text);
}

.texto-corto {
  display: none;
}

.observacion {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  background: var(--surface-2);
  color: var(--text);
  font-size: 0.875rem;
}

.observacion::placeholder {
  color: var(--text-subtle);
}

.observacion:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: var(--focus-ring);
}

@media (max-width: 760px) {
  .fila {
    grid-template-columns: 1fr auto;
  }

  .observacion {
    grid-column: 1 / -1;
  }

  .texto-largo {
    display: none;
  }

  .texto-corto {
    display: inline;
  }

  .opcion {
    min-width: 46px;
    min-height: 44px;
    padding: 0;
    font-size: 0.9375rem;
  }
}
</style>
