<script setup>
// Gráfico de barras verticales simple y accesible (cada barra tiene su
// valor en texto para lectores de pantalla). datos: [{ etiqueta, valor, tono? }]
import { computed } from 'vue'

const props = defineProps({
  datos: { type: Array, default: () => [] },
  alto: { type: Number, default: 140 },
  max: { type: Number, default: null },
  sufijo: { type: String, default: '' },
  etiqueta: { type: String, default: '' },
})

const tope = computed(
  () =>
    props.max ??
    Math.max(1, ...props.datos.map((d) => (typeof d.valor === 'number' ? d.valor : 0))),
)
</script>

<template>
  <figure class="barras" :aria-label="etiqueta || undefined">
    <div class="columnas" :style="{ height: `${alto}px` }">
      <div v-for="d in datos" :key="d.etiqueta" class="columna">
        <span class="valor num">{{
          d.valor === null || d.valor === undefined ? '—' : `${d.valor}${sufijo}`
        }}</span>
        <span
          :class="[
            'barra',
            d.tono && `barra--${d.tono}`,
            { vacia: d.valor === null || d.valor === undefined },
          ]"
          :style="{ height: `${((d.valor ?? 0) / tope) * 100}%` }"
        />
      </div>
    </div>
    <div class="etiquetas">
      <span v-for="d in datos" :key="d.etiqueta">{{ d.etiqueta }}</span>
    </div>
  </figure>
</template>

<style scoped>
.barras {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  margin: 0;
}

.columnas,
.etiquetas {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 1fr;
  gap: var(--sp-2);
}

.columnas {
  align-items: end;
}

.columna {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: var(--sp-1);
  height: 100%;
}

.valor {
  font-size: var(--fs-xs);
  font-weight: var(--fw-semibold);
  color: var(--text-muted);
}

.barra {
  --color: var(--primary);
  width: min(100%, 44px);
  min-height: 3px;
  border-radius: 6px 6px 3px 3px;
  background: linear-gradient(
    180deg,
    var(--color),
    color-mix(in srgb, var(--color) 70%, transparent)
  );
  transition: height 700ms var(--ease-out);
}

.barra.vacia {
  background: var(--surface-hover);
}

.barra--exito {
  --color: var(--estado-presente);
}

.barra--alerta {
  --color: var(--estado-justificado);
}

.barra--peligro {
  --color: var(--estado-ausente);
}

.etiquetas span {
  text-align: center;
  font-size: var(--fs-xs);
  color: var(--text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
