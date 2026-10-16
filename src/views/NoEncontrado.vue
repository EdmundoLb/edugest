<script setup>
import { computed } from 'vue'
import { useAuth } from '@/stores/auth'

const { rutaInicio } = useAuth()

const destino = computed(() => rutaInicio())
</script>

<template>
  <div class="no-encontrado">
    <span class="codigo">404</span>
    <h1>Página no encontrada</h1>
    <p>La dirección que buscás no existe o fue movida.</p>
    <router-link :to="destino" class="btn-inicio">Volver al inicio</router-link>
  </div>
</template>

<style scoped>
.no-encontrado {
  min-height: 70vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 6rem 1rem 2rem;
  text-align: center;
}

.codigo {
  font-size: 4rem;
  font-weight: 800;
  color: var(--primary-text);
  line-height: 1;
}

h1 {
  font-size: 1.5rem;
}

p {
  color: var(--text-2);
}

.btn-inicio {
  margin-top: 0.5rem;
  padding: 0.75rem 1.5rem;
  border-radius: 10px;
  background: var(--primary);
  color: var(--on-primary);
  text-decoration: none;
  font-weight: 600;
}
</style>
