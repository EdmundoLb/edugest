<script setup>
// Aviso en los paneles de admin y docente cuando hay solicitudes de las
// familias sin resolver. Si no hay ninguna (o falta 0014), no muestra nada.
import { ref, onMounted } from 'vue'
import { contarPendientes } from '@/lib/api/solicitudes'

const pendientes = ref(0)

onMounted(async () => {
  try {
    pendientes.value = await contarPendientes()
  } catch (e) {
    console.error(e)
  }
})
</script>

<template>
  <router-link v-if="pendientes" to="/solicitudes" class="tarjeta aviso-solicitudes">
    <span class="numero">{{ pendientes }}</span>
    <span class="texto">
      <strong>{{
        pendientes === 1 ? 'Aviso de una familia sin revisar' : 'Avisos de familias sin revisar'
      }}</strong>
      <span class="texto-muted">Ausencias avisadas y pedidos de justificación</span>
    </span>
    <span class="ir" aria-hidden="true">Revisar →</span>
  </router-link>
</template>

<style scoped>
.aviso-solicitudes {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem 1.25rem;
  border-left: 4px solid var(--warning);
  color: var(--text);
  text-decoration: none;
}

.aviso-solicitudes:hover {
  background: var(--surface-hover);
}

.numero {
  display: grid;
  place-items: center;
  min-width: 2.5rem;
  height: 2.5rem;
  padding: 0 0.5rem;
  border-radius: 999px;
  background: var(--warning-soft);
  color: var(--warning-text);
  font-weight: 700;
  font-size: 1.125rem;
}

.texto {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  flex: 1;
  font-size: 0.875rem;
}

.ir {
  color: var(--primary-text);
  font-weight: 600;
  font-size: 0.875rem;
  white-space: nowrap;
}
</style>
