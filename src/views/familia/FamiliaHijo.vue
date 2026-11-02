<script setup>
// Historial completo de un hijo para la familia. Reutiliza los mismos
// componentes que "Mi asistencia"; RLS (tutor_de_alumno, 0013) solo deja ver
// a los alumnos vinculados a este tutor.
import { ref, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import HistorialAlumno from '@/components/HistorialAlumno.vue'
import JustificacionesPanel from '@/components/JustificacionesPanel.vue'
import SolicitudesFamiliaPanel from '@/components/SolicitudesFamiliaPanel.vue'
import EmptyState from '@/components/EmptyState.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import { supabase } from '@/lib/supabase'
import { UMBRAL_PORCENTAJE, FALTAS_SEGUIDAS } from '@/lib/api/alertas'
import { resumirPorCurso, alertasDeCursos } from '@/lib/historial'

const route = useRoute()

const alumno = ref(null)
const cargando = ref(true)
const dias = ref([])

const nombreAlumno = computed(() =>
  alumno.value ? `${alumno.value.nombre} ${alumno.value.apellido}` : '',
)

const alertas = computed(() =>
  alertasDeCursos(resumirPorCurso(dias.value), {
    umbral: UMBRAL_PORCENTAJE,
    faltasSeguidas: FALTAS_SEGUIDAS,
  }),
)

const bajoUmbral = (a) => a.porcentaje !== null && a.porcentaje < UMBRAL_PORCENTAJE

watch(() => route.params.id, cargar, { immediate: true })

async function cargar(id) {
  cargando.value = true
  alumno.value = null
  const { data, error } = await supabase
    .from('alumnos')
    .select('id, nombre, apellido')
    .eq('id', id)
    .maybeSingle()
  if (error) console.error(error)
  alumno.value = data
  cargando.value = false
}
</script>

<template>
  <div class="hijo-page">
    <PageHeader titulo="Asistencia" :subtitulo="nombreAlumno" volver="/familia" />

    <div class="contenedor">
      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="!alumno"
        title="No encontramos a este alumno"
        hint="Puede que el vínculo se haya quitado. Volvé a Mis hijos o pedile un código nuevo a la institución."
      />

      <template v-else>
        <div v-if="alertas.length" class="alerta" role="status">
          <strong>Atención con la asistencia de {{ alumno.nombre }}</strong>
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
            >Si las faltas tienen un motivo, comunicate con la institución para justificarlas.</span
          >
        </div>

        <SolicitudesFamiliaPanel
          :alumno-id="alumno.id"
          :nombre-alumno="alumno.nombre"
          class="solicitudes"
        />

        <HistorialAlumno
          :alumno-id="alumno.id"
          :nombre-alumno="nombreAlumno"
          @cargado="(d) => (dias = d)"
        />

        <JustificacionesPanel :alumno-id="alumno.id" class="justificaciones" />
      </template>
    </div>
  </div>
</template>

<style scoped>
.hijo-page {
  min-height: calc(100vh - var(--navbar-height));
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.alerta {
  margin-bottom: 1.5rem;
  padding: 1rem 1.25rem;
  border: 1px solid var(--warning-border);
  border-left: 4px solid var(--warning);
  border-radius: var(--radius);
  background: var(--warning-soft);
  color: var(--text);
  font-size: 0.875rem;
}

.alerta ul {
  margin: 0.375rem 0 0.5rem 1.25rem;
}

.alerta span {
  color: var(--text-2);
}

.solicitudes {
  margin-bottom: 1.5rem;
}

.justificaciones {
  margin-top: 1.5rem;
}
</style>
