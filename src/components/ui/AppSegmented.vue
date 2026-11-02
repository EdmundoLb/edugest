<script setup>
// Control segmentado (radio accesible con aspecto de botones). Lo usan los
// estados de asistencia y los filtros cortos.
// opciones: [{ valor, texto, corto?, tono?, icono? }]
import AppIcon from '@/components/ui/AppIcon.vue'

defineProps({
  opciones: { type: Array, required: true },
  nombre: { type: String, required: true },
  etiqueta: { type: String, default: '' },
  tamano: { type: String, default: 'md', validator: (v) => ['sm', 'md', 'lg'].includes(v) },
  deshabilitado: { type: Boolean, default: false },
  // Muestra `corto` en pantallas chicas.
  compacto: { type: Boolean, default: false },
})

const modelo = defineModel({ type: [String, Number, null], default: null })
</script>

<template>
  <div
    :class="['segmentado', `segmentado--${tamano}`, { 'segmentado--compacto': compacto }]"
    role="radiogroup"
    :aria-label="etiqueta || undefined"
  >
    <label
      v-for="op in opciones"
      :key="op.valor"
      :class="['segmento', op.tono && `segmento--${op.tono}`, { activo: modelo === op.valor }]"
    >
      <input
        v-model="modelo"
        type="radio"
        class="sr-only"
        :name="nombre"
        :value="op.valor"
        :disabled="deshabilitado"
      />
      <AppIcon v-if="op.icono" :nombre="op.icono" :tamano="16" />
      <span class="largo">{{ op.texto }}</span>
      <span v-if="op.corto" class="corto" aria-hidden="true">{{ op.corto }}</span>
    </label>
  </div>
</template>

<style scoped>
.segmentado {
  --alto: 38px;
  display: inline-flex;
  gap: 2px;
  padding: 3px;
  border-radius: var(--radius-md);
  background: var(--surface-hover);
}

.segmentado--sm {
  --alto: 30px;
}

.segmentado--lg {
  --alto: 46px;
}

.segmento {
  --activo-fondo: var(--surface);
  --activo-color: var(--text);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
  min-height: var(--alto);
  min-width: var(--alto);
  padding: 0 var(--sp-3);
  border-radius: calc(var(--radius-md) - 2px);
  color: var(--text-muted);
  font-size: var(--fs-sm);
  font-weight: var(--fw-semibold);
  cursor: pointer;
  user-select: none;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-fast) var(--ease-out);
}

.segmento:hover {
  color: var(--text);
}

.segmento:has(input:focus-visible) {
  outline: 2px solid var(--primary-text);
  outline-offset: 1px;
}

.segmento.activo {
  background: var(--activo-fondo);
  color: var(--activo-color);
  box-shadow: var(--elev-1);
}

.segmento--presente {
  --activo-fondo: var(--estado-presente-suave);
  --activo-color: var(--estado-presente-texto);
}

.segmento--ausente {
  --activo-fondo: var(--estado-ausente-suave);
  --activo-color: var(--estado-ausente-texto);
}

.segmento--tarde {
  --activo-fondo: var(--estado-tarde-suave);
  --activo-color: var(--estado-tarde-texto);
}

.segmento--justificado {
  --activo-fondo: var(--estado-justificado-suave);
  --activo-color: var(--estado-justificado-texto);
}

.corto {
  display: none;
}

@media (max-width: 560px) {
  .segmentado--compacto .largo {
    display: none;
  }

  .segmentado--compacto .corto {
    display: inline;
  }
}
</style>
