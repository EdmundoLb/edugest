<script setup>
import PageHeader from '@/components/PageHeader.vue'
import HistorialAlumno from '@/components/HistorialAlumno.vue'
import JustificacionesPanel from '@/components/JustificacionesPanel.vue'
import EmptyState from '@/components/EmptyState.vue'
import { ref, computed } from 'vue'
import { useAuth } from '@/stores/auth'
import { UMBRAL_PORCENTAJE, FALTAS_SEGUIDAS } from '@/lib/api/alertas'
import { resumirPorCurso, alertasDeCursos } from '@/lib/historial'

const { state } = useAuth()

// Días ya combinados que emite HistorialAlumno al cargar el período elegido.
const dias = ref([])

const nombreAlumno = computed(() => {
  return state.datosUsuario
    ? `${state.datosUsuario.nombre} ${state.datosUsuario.apellido}`
    : state.user?.email || 'Alumno'
})

// Cursos en los que conviene avisarle al estudiante.
const alertas = computed(() =>
  alertasDeCursos(resumirPorCurso(dias.value), {
    umbral: UMBRAL_PORCENTAJE,
    faltasSeguidas: FALTAS_SEGUIDAS,
  }),
)

const bajoUmbral = (a) => a.porcentaje !== null && a.porcentaje < UMBRAL_PORCENTAJE
</script>

<template>
  <div class="asistencia-page">
    <PageHeader titulo="Mi asistencia" :subtitulo="nombreAlumno" />

    <div class="page-content">
      <EmptyState
        v-if="!state.datosUsuario"
        title="No encontramos tu ficha de alumno"
        hint="Pedile a la administración que revise tu cuenta."
      />

      <template v-else>
        <div class="welcome-section">
          <h2>Hola, {{ nombreAlumno }}</h2>
          <p>Acá podés ver tu asistencia por curso y por mes, y el detalle de cada clase.</p>
        </div>

        <div v-if="alertas.length" class="alerta-estudiante" role="status">
          <strong>Atención con tu asistencia</strong>
          <ul>
            <li v-for="a in alertas" :key="a.cursoId">
              {{ a.cursoNombre }}:
              <template v-if="a.faltasSeguidas >= FALTAS_SEGUIDAS"
                >{{ a.faltasSeguidas }} faltas seguidas</template
              >
              <template v-if="a.faltasSeguidas >= FALTAS_SEGUIDAS && bajoUmbral(a)"> y </template>
              <template v-if="bajoUmbral(a)">{{ a.porcentaje }}% de asistencia</template>
            </li>
          </ul>
          <span
            >Si tus faltas tienen justificación, avisale a tu docente o a la administración.</span
          >
        </div>

        <HistorialAlumno
          :alumno-id="state.datosUsuario.id"
          :nombre-alumno="nombreAlumno"
          @cargado="(d) => (dias = d)"
        />

        <JustificacionesPanel :alumno-id="state.datosUsuario.id" class="justificaciones" />
      </template>
    </div>
  </div>
</template>

<style scoped>
.asistencia-page {
  min-height: calc(100vh - var(--navbar-height));
}

.page-content {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.welcome-section {
  margin-bottom: 1.5rem;
}

.welcome-section h2 {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.welcome-section p {
  font-size: 0.875rem;
  color: var(--text-muted);
}

.alerta-estudiante {
  margin-bottom: 1.5rem;
  padding: 1rem 1.25rem;
  border: 1px solid var(--warning-border);
  border-left: 4px solid var(--warning);
  border-radius: var(--radius);
  background: var(--warning-soft);
  color: var(--text);
  font-size: 0.875rem;
}

.alerta-estudiante ul {
  margin: 0.375rem 0 0.5rem 1.25rem;
}

.alerta-estudiante span {
  color: var(--text-2);
}

.justificaciones {
  margin-top: 1.5rem;
}

@media (max-width: 768px) {
  .page-content {
    padding: 1rem;
  }
}
</style>
