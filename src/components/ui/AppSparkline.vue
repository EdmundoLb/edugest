<script setup>
// Mini gráfico de línea en SVG (tendencia de 30 días, % por semana...).
// Ignora huecos (null) y escala al rango de los datos.
import { computed } from 'vue'

const props = defineProps({
  valores: { type: Array, default: () => [] },
  ancho: { type: Number, default: 120 },
  alto: { type: Number, default: 36 },
  tono: { type: String, default: 'primario' },
  relleno: { type: Boolean, default: true },
  min: { type: Number, default: null },
  max: { type: Number, default: null },
})

const puntos = computed(() => {
  const datos = props.valores.map((v, i) => ({ i, v })).filter((p) => typeof p.v === 'number')
  if (datos.length < 2) return []
  const lo = props.min ?? Math.min(...datos.map((p) => p.v))
  const hi = props.max ?? Math.max(...datos.map((p) => p.v))
  const rango = hi - lo || 1
  const n = props.valores.length - 1 || 1
  const margen = 3
  return datos.map((p) => ({
    x: (p.i / n) * (props.ancho - margen * 2) + margen,
    y: props.alto - margen - ((p.v - lo) / rango) * (props.alto - margen * 2),
  }))
})

const linea = computed(() =>
  puntos.value.map((p, i) => `${i ? 'L' : 'M'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' '),
)
const area = computed(() => {
  if (!puntos.value.length) return ''
  const ult = puntos.value[puntos.value.length - 1]
  return `${linea.value} L${ult.x.toFixed(1)},${props.alto} L${puntos.value[0].x.toFixed(1)},${props.alto} Z`
})
const final = computed(() => puntos.value[puntos.value.length - 1])
</script>

<template>
  <svg
    v-if="puntos.length"
    :class="['sparkline', `sparkline--${tono}`]"
    :width="ancho"
    :height="alto"
    :viewBox="`0 0 ${ancho} ${alto}`"
    aria-hidden="true"
  >
    <path v-if="relleno" class="area" :d="area" />
    <path class="linea" :d="linea" fill="none" />
    <circle class="punto" :cx="final.x" :cy="final.y" r="2.75" />
  </svg>
</template>

<style scoped>
.sparkline {
  --color: var(--primary);
  overflow: visible;
}

.sparkline--exito {
  --color: var(--estado-presente);
}

.sparkline--peligro {
  --color: var(--estado-ausente);
}

.sparkline--alerta {
  --color: var(--estado-justificado);
}

.linea {
  stroke: var(--color);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.area {
  fill: color-mix(in srgb, var(--color) 14%, transparent);
}

.punto {
  fill: var(--color);
  stroke: var(--surface);
  stroke-width: 1.5;
}
</style>
