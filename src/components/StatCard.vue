<script setup>
// Tarjeta de indicador (KPI): valor grande, etiqueta, ícono, tendencia
// opcional (+/- puntos) y mini gráfico. Con `to` es un link.
// Mantiene `value`, `label` y `variant` de la versión anterior.
import { computed } from 'vue'
import AppIcon from '@/components/ui/AppIcon.vue'
import AppSparkline from '@/components/ui/AppSparkline.vue'

const props = defineProps({
  value: { type: [String, Number], required: true },
  label: { type: String, required: true },
  variant: {
    type: String,
    default: '',
    validator: (v) => ['', 'presente', 'ausente', 'porcentaje', 'alerta'].includes(v),
  },
  icono: { type: String, default: '' },
  // { delta, direccion } de tendencia() en src/lib/ui.js
  tendencia: { type: Object, default: null },
  // Si subir es malo (ej. ausencias), invierte los colores de la tendencia.
  invertirTendencia: { type: Boolean, default: false },
  serie: { type: Array, default: () => [] },
  hint: { type: String, default: '' },
  to: { type: [String, Object], default: null },
  cargando: { type: Boolean, default: false },
})

const tonoTendencia = computed(() => {
  if (!props.tendencia || props.tendencia.direccion === 'igual') return 'neutro'
  const bueno =
    props.tendencia.direccion === 'sube' ? !props.invertirTendencia : props.invertirTendencia
  return bueno ? 'bueno' : 'malo'
})

const tonoSerie = computed(
  () => ({ presente: 'exito', ausente: 'peligro', alerta: 'alerta' })[props.variant] ?? 'primario',
)
</script>

<template>
  <component
    :is="to ? 'router-link' : 'div'"
    :to="to ?? undefined"
    :class="['stat-card', variant, { 'stat-card--link': to }]"
  >
    <div class="stat-cabecera">
      <span class="stat-label">{{ label }}</span>
      <span v-if="icono || $slots.icon" class="stat-icono">
        <slot name="icon"><AppIcon :nombre="icono" :tamano="18" /></slot>
      </span>
    </div>

    <span v-if="cargando" class="stat-skeleton" aria-hidden="true" />
    <span v-else class="stat-value num">{{ value }}</span>

    <div v-if="tendencia || serie.length || hint" class="stat-pie">
      <span v-if="tendencia" :class="['stat-tendencia', tonoTendencia]">
        <AppIcon
          :nombre="tendencia.direccion === 'baja' ? 'baja' : 'sube'"
          :tamano="14"
          :grosor="2.5"
        />
        {{ tendencia.delta > 0 ? '+' : '' }}{{ tendencia.delta }}
      </span>
      <span v-if="hint" class="stat-hint">{{ hint }}</span>
      <AppSparkline
        v-if="serie.length > 1"
        class="stat-sparkline"
        :valores="serie"
        :tono="tonoSerie"
        :ancho="84"
        :alto="28"
      />
    </div>
  </component>
</template>

<style scoped>
.stat-card {
  --acento: var(--text);
  position: relative;
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  padding: var(--sp-4) var(--sp-5);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  background: var(--surface);
  color: var(--text);
  text-decoration: none;
  overflow: hidden;
}

.stat-card::before {
  content: '';
  position: absolute;
  inset: 0 0 auto;
  height: 3px;
  background: var(--acento);
  opacity: 0;
}

.stat-card.presente {
  --acento: var(--estado-presente);
}

.stat-card.ausente {
  --acento: var(--estado-ausente);
}

.stat-card.alerta {
  --acento: var(--estado-justificado);
}

.stat-card.porcentaje {
  --acento: var(--primary);
}

.stat-card.presente::before,
.stat-card.ausente::before,
.stat-card.alerta::before,
.stat-card.porcentaje::before {
  opacity: 1;
}

.stat-card--link {
  transition:
    border-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-base) var(--ease-out),
    transform var(--motion-base) var(--ease-out);
}

.stat-card--link:hover {
  border-color: var(--primary-border);
  box-shadow: var(--elev-2);
  transform: translateY(-2px);
}

.stat-cabecera {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-2);
}

.stat-label {
  font-size: var(--fs-sm);
  font-weight: var(--fw-medium);
  color: var(--text-muted);
}

.stat-icono {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--acento) 12%, transparent);
  color: var(--acento);
}

.stat-card:not(.presente):not(.ausente):not(.alerta):not(.porcentaje) .stat-icono {
  background: var(--surface-hover);
  color: var(--text-muted);
}

.stat-value {
  font-size: var(--fs-2xl);
  font-weight: var(--fw-bold);
  line-height: var(--lh-tight);
  letter-spacing: var(--tracking-tight);
}

.stat-skeleton {
  display: block;
  width: 60%;
  height: 2rem;
  border-radius: var(--radius-sm);
  background: linear-gradient(
    90deg,
    var(--surface-hover) 25%,
    var(--surface-2) 50%,
    var(--surface-hover) 75%
  );
  background-size: 200% 100%;
  animation: brillo-skeleton 1.4s ease-in-out infinite;
}

.stat-pie {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  min-height: 28px;
}

.stat-tendencia {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.0625rem 0.4375rem;
  border-radius: var(--radius-full);
  font-size: var(--fs-xs);
  font-weight: var(--fw-semibold);
  background: var(--surface-hover);
  color: var(--text-muted);
}

.stat-tendencia.bueno {
  background: var(--estado-presente-suave);
  color: var(--estado-presente-texto);
}

.stat-tendencia.malo {
  background: var(--estado-ausente-suave);
  color: var(--estado-ausente-texto);
}

.stat-hint {
  font-size: var(--fs-xs);
  color: var(--text-subtle);
}

.stat-sparkline {
  margin-left: auto;
}
</style>
