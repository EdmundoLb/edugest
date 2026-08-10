<template>
  <nav class="breadcrumb" aria-label="Breadcrumb">
    <ol class="breadcrumb-list">
      <li v-for="(crumb, idx) in crumbs" :key="crumb.path" class="breadcrumb-item">
        <router-link
          v-if="idx < crumbs.length - 1"
          :to="crumb.path"
          class="breadcrumb-link"
        >
          {{ crumb.label }}
        </router-link>
        <span v-else class="breadcrumb-current" aria-current="page">
          {{ crumb.label }}
        </span>
        <svg
          v-if="idx < crumbs.length - 1"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class="breadcrumb-separator"
          aria-hidden="true"
        >
          <path d="M9 18l6-6-6-6" />
        </svg>
      </li>
    </ol>
  </nav>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

const routeLabels = {
  '/': 'Inicio',
  '/login': 'Iniciar sesión',
  '/Registro': 'Registro',
  '/Estudiantes': 'Alumnos',
  '/MiAsistencia': 'Mi Asistencia',
  '/ProfesorDashboard': 'Panel',
  '/MisCursos': 'Mis Cursos',
  '/LlamarLista': 'Llamar Lista',
  '/MisReportes': 'Reportes',
  '/admin': 'Administración'
}

const crumbs = computed(() => {
  const pathSegments = route.path.split('/').filter(Boolean)
  const result = [{ path: '/', label: 'Inicio' }]

  let currentPath = ''
  pathSegments.forEach((segment, idx) => {
    currentPath += '/' + segment

    let label = routeLabels[currentPath]
    if (!label) {
      if (segment.match(/^[0-9a-f-]{36}$/i)) {
        label = 'Detalle'
      } else {
        label = segment.charAt(0).toUpperCase() + segment.slice(1)
      }
    }

    result.push({ path: currentPath, label })
  })

  return result
})
</script>

<style scoped>
.breadcrumb {
  padding: 0.75rem 0;
}

.breadcrumb-list {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  list-style: none;
  margin: 0;
  padding: 0;
  flex-wrap: wrap;
}

.breadcrumb-item {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.breadcrumb-link {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.5);
  text-decoration: none;
  transition: color 0.2s;
}

.breadcrumb-link:hover {
  color: #004aad;
}

.breadcrumb-current {
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.8);
  font-weight: 500;
}

.breadcrumb-separator {
  width: 14px;
  height: 14px;
  color: rgba(255, 255, 255, 0.3);
}
</style>