<script setup>
// Barra de progreso horizontal (avance de lectura, % de asistencia, lista).
// Con `segmentos` dibuja una barra apilada: [{ valor, tono }].
import { computed } from 'vue'
import { nivelPorcentaje } from '@/lib/ui'

const props = defineProps({
  valor: { type: Number, default: 0 }, // 0–100
  segmentos: { type: Array, default: null },
  tono: { type: String, default: '' }, // vacío = según nivel del %
  alto: { type: Number, default: 8 },
  etiqueta: { type: String, default: '' },
})

const nivel = computed(() => props.tono || nivelPorcentaje(props.valor))
const total = computed(() => (props.segmentos ?? []).reduce((a, s) => a + (s.valor || 0), 0) || 1)
</script>

<template>
  <div
    class="barra"
    :style="{ height: `${alto}px` }"
    role="progressbar"
    :aria-valuenow="segmentos ? undefined : Math.round(valor)"
    aria-valuemin="0"
    aria-valuemax="100"
    :aria-label="etiqueta || undefined"
  >
    <template v-if="segmentos">
      <span
        v-for="(s, i) in segmentos"
        :key="i"
        :class="['tramo', `tramo--${s.tono}`]"
        :style="{ width: `${((s.valor || 0) / total) * 100}%` }"
      />
    </template>
    <span
      v-else
      :class="['tramo', `tramo--${nivel}`]"
      :style="{ width: `${Math.min(Math.max(valor, 0), 100)}%` }"
    />
  </div>
</template>

<style scoped>
.barra {
  display: flex;
  width: 100%;
  border-radius: var(--radius-full);
  background: var(--surface-hover);
  overflow: hidden;
}

.tramo {
  height: 100%;
  transition: width 700ms var(--ease-out);
}

.tramo--alto,
.tramo--exito,
.tramo--presente {
  background: var(--estado-presente);
}

.tramo--medio,
.tramo--alerta,
.tramo--justificado {
  background: var(--estado-justificado);
}

.tramo--bajo,
.tramo--peligro,
.tramo--ausente {
  background: var(--estado-ausente);
}

.tramo--primario,
.tramo--tarde {
  background: var(--primary);
}

.tramo--neutro {
  background: var(--text-subtle);
}
</style>
