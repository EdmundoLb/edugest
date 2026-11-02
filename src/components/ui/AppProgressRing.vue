<script setup>
// Anillo de porcentaje (asistencia del mes, avance). El color sigue el nivel
// (alto / medio / bajo) salvo que se fije `tono`.
import { computed } from 'vue'
import { nivelPorcentaje } from '@/lib/ui'

const props = defineProps({
  valor: { type: Number, default: null }, // 0–100 o null
  tamano: { type: Number, default: 96 },
  grosor: { type: Number, default: 9 },
  umbral: { type: Number, default: 75 },
  tono: { type: String, default: '' },
  etiqueta: { type: String, default: '' },
})

const radio = computed(() => (props.tamano - props.grosor) / 2)
const circunferencia = computed(() => 2 * Math.PI * radio.value)
const relleno = computed(() =>
  props.valor === null
    ? circunferencia.value
    : circunferencia.value * (1 - Math.min(Math.max(props.valor, 0), 100) / 100),
)
const nivel = computed(() => props.tono || nivelPorcentaje(props.valor, props.umbral))
</script>

<template>
  <div
    :class="['anillo', `anillo--${nivel}`]"
    :style="{ width: `${tamano}px`, height: `${tamano}px` }"
    role="img"
    :aria-label="etiqueta || (valor === null ? 'Sin datos' : `${Math.round(valor)}%`)"
  >
    <svg :width="tamano" :height="tamano" :viewBox="`0 0 ${tamano} ${tamano}`" aria-hidden="true">
      <circle
        class="pista"
        :cx="tamano / 2"
        :cy="tamano / 2"
        :r="radio"
        :stroke-width="grosor"
        fill="none"
      />
      <circle
        class="valor"
        :cx="tamano / 2"
        :cy="tamano / 2"
        :r="radio"
        :stroke-width="grosor"
        fill="none"
        stroke-linecap="round"
        :stroke-dasharray="circunferencia"
        :stroke-dashoffset="relleno"
        :transform="`rotate(-90 ${tamano / 2} ${tamano / 2})`"
      />
    </svg>
    <div class="centro">
      <slot>
        <span class="porcentaje num">{{ valor === null ? '—' : `${Math.round(valor)}%` }}</span>
      </slot>
    </div>
  </div>
</template>

<style scoped>
.anillo {
  --color: var(--primary);
  position: relative;
  display: inline-grid;
  place-items: center;
  flex-shrink: 0;
}

.anillo svg {
  position: absolute;
  inset: 0;
}

.pista {
  stroke: var(--surface-hover);
}

.valor {
  stroke: var(--color);
  transition: stroke-dashoffset 900ms var(--ease-out);
}

.anillo--alto {
  --color: var(--estado-presente);
}

.anillo--medio {
  --color: var(--estado-justificado);
}

.anillo--bajo {
  --color: var(--estado-ausente);
}

.anillo--neutro {
  --color: var(--text-subtle);
}

.centro {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  line-height: 1.1;
}

.porcentaje {
  font-size: 1.375rem;
  font-weight: var(--fw-bold);
  letter-spacing: var(--tracking-tight);
}
</style>
