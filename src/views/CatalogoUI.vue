<script setup>
// Catálogo del Design System v2. Solo existe en desarrollo (ruta /ui, ver
// router): sirve para revisar los componentes en claro y oscuro sin datos ni
// sesión. No se publica en producción.
import { ref } from 'vue'
import { useTema } from '@/composables/useTema'
import AppButton from '@/components/ui/AppButton.vue'
import AppCard from '@/components/ui/AppCard.vue'
import AppBadge from '@/components/ui/AppBadge.vue'
import AppAvatar from '@/components/ui/AppAvatar.vue'
import AppSkeleton from '@/components/ui/AppSkeleton.vue'
import AppSegmented from '@/components/ui/AppSegmented.vue'
import AppTabs from '@/components/ui/AppTabs.vue'
import AppSheet from '@/components/ui/AppSheet.vue'
import AppProgressRing from '@/components/ui/AppProgressRing.vue'
import AppProgressBar from '@/components/ui/AppProgressBar.vue'
import AppSparkline from '@/components/ui/AppSparkline.vue'
import AppBarChart from '@/components/ui/AppBarChart.vue'
import AppIcon from '@/components/ui/AppIcon.vue'
import StatCard from '@/components/StatCard.vue'
import EmptyState from '@/components/EmptyState.vue'
import { tendencia } from '@/lib/ui'

const { tema, alternarTema } = useTema()

const estado = ref('presente')
const pestana = ref('pendientes')
const sheet = ref(false)
const serie = [82, 85, 80, 88, 91, 87, 93, 90, 94]

const ESTADOS = [
  { valor: 'presente', texto: 'Presente', corto: 'P', tono: 'presente' },
  { valor: 'tarde', texto: 'Tarde', corto: 'T', tono: 'tarde' },
  { valor: 'ausente', texto: 'Ausente', corto: 'A', tono: 'ausente' },
  { valor: 'justificado', texto: 'Justif.', corto: 'J', tono: 'justificado' },
]

const ICONOS = [
  'inicio',
  'lista',
  'alumnos',
  'cursos',
  'calendario',
  'campana',
  'comunicado',
  'reportes',
  'familia',
  'escuela',
  'alerta',
  'check-circulo',
  'buscar',
  'ajustes',
  'sin-conexion',
  'destello',
]
</script>

<template>
  <div class="catalogo contenedor">
    <header class="cabecera">
      <div>
        <h1>Design System v2</h1>
        <p class="texto-muted">Catálogo de componentes de EduGest (solo en desarrollo).</p>
      </div>
      <AppButton
        variante="secundario"
        :icono="tema === 'dark' ? 'sol' : 'luna'"
        @click="alternarTema"
      >
        Tema {{ tema === 'dark' ? 'claro' : 'oscuro' }}
      </AppButton>
    </header>

    <section>
      <h2>Botones</h2>
      <div class="fila">
        <AppButton icono="mas">Primario</AppButton>
        <AppButton variante="secundario" icono="descargar">Secundario</AppButton>
        <AppButton variante="fantasma">Fantasma</AppButton>
        <AppButton variante="peligro" icono="basura">Peligro</AppButton>
        <AppButton variante="exito" icono="check">Éxito</AppButton>
        <AppButton cargando>Guardando</AppButton>
        <AppButton tamano="sm" variante="secundario">Chico</AppButton>
        <AppButton tamano="lg" icono-derecha="flecha-derecha">Grande</AppButton>
        <AppButton solo-icono variante="secundario" icono="ajustes" aria-label="Ajustes" />
      </div>
    </section>

    <section>
      <h2>Indicadores</h2>
      <div class="grilla">
        <StatCard
          value="94%"
          label="Asistencia del mes"
          icono="actividad"
          variant="porcentaje"
          :tendencia="tendencia(serie)"
          :serie="serie"
        />
        <StatCard
          value="312"
          label="Presentes hoy"
          icono="check-circulo"
          variant="presente"
          hint="de 330 alumnos"
        />
        <StatCard
          value="18"
          label="Ausentes hoy"
          icono="cerrar"
          variant="ausente"
          :tendencia="{ delta: 4, direccion: 'sube' }"
          invertir-tendencia
        />
        <StatCard value="7" label="Alumnos en riesgo" icono="alerta" variant="alerta" to="/ui" />
        <StatCard value="0" label="Cargando" cargando />
      </div>
    </section>

    <section>
      <h2>Progreso y gráficos</h2>
      <div class="fila alineada">
        <AppProgressRing :valor="94" />
        <AppProgressRing :valor="78" />
        <AppProgressRing :valor="61" />
        <AppProgressRing :valor="null" :tamano="72" />
        <AppSparkline :valores="serie" :ancho="160" :alto="48" tono="exito" />
      </div>
      <AppCard class="bloque">
        <AppProgressBar :valor="82" />
        <AppProgressBar
          class="bloque-chico"
          :segmentos="[
            { valor: 28, tono: 'presente' },
            { valor: 2, tono: 'tarde' },
            { valor: 3, tono: 'ausente' },
            { valor: 1, tono: 'justificado' },
          ]"
          :alto="10"
        />
      </AppCard>
      <AppCard class="bloque">
        <AppBarChart
          :datos="[
            { etiqueta: 'Lun', valor: 92, tono: 'exito' },
            { etiqueta: 'Mar', valor: 88, tono: 'exito' },
            { etiqueta: 'Mié', valor: 71, tono: 'peligro' },
            { etiqueta: 'Jue', valor: 85, tono: 'alerta' },
            { etiqueta: 'Vie', valor: null },
          ]"
          :max="100"
          sufijo="%"
        />
      </AppCard>
    </section>

    <section>
      <h2>Controles</h2>
      <div class="fila alineada">
        <AppSegmented
          v-model="estado"
          :opciones="ESTADOS"
          nombre="demo-estado"
          etiqueta="Estado"
          compacto
        />
        <AppSegmented v-model="estado" :opciones="ESTADOS" nombre="demo-estado-lg" tamano="lg" />
      </div>
      <AppTabs
        v-model="pestana"
        class="bloque"
        :opciones="[
          { valor: 'pendientes', texto: 'Pendientes', contador: 3 },
          { valor: 'resueltas', texto: 'Resueltas' },
          { valor: 'todas', texto: 'Todas' },
        ]"
      />
    </section>

    <section>
      <h2>Badges y avatares</h2>
      <div class="fila alineada">
        <AppBadge tono="presente" punto>Presente</AppBadge>
        <AppBadge tono="tarde" punto>Tarde</AppBadge>
        <AppBadge tono="ausente" punto>Ausente</AppBadge>
        <AppBadge tono="justificado" punto>Justificado</AppBadge>
        <AppBadge tono="solido">Nuevo</AppBadge>
        <AppBadge v-for="n in 8" :key="n" :tono="`curso-${n}`" punto>Curso {{ n }}</AppBadge>
      </div>
      <div class="fila alineada">
        <AppAvatar nombre="Ana Pérez" tamano="sm" />
        <AppAvatar nombre="Luis Gómez" />
        <AppAvatar nombre="María José Benítez" tamano="lg" />
        <AppAvatar nombre="Carlos Duarte" tamano="xl" />
      </div>
    </section>

    <section>
      <h2>Tarjetas</h2>
      <div class="grilla">
        <AppCard to="/ui" acento="primario">
          <strong>Tarjeta enlazable</strong>
          <p class="texto-muted">Con hover, foco y acento.</p>
        </AppCard>
        <AppCard acento="curso-3" elevada>
          <strong>Elevada con color de curso</strong>
          <p class="texto-muted">Para destacar.</p>
        </AppCard>
        <AppCard>
          <AppSkeleton :lineas="3" />
        </AppCard>
      </div>
    </section>

    <section>
      <h2>Íconos</h2>
      <div class="fila alineada">
        <span v-for="i in ICONOS" :key="i" class="icono" :title="i"><AppIcon :nombre="i" /></span>
      </div>
    </section>

    <section>
      <h2>Estado vacío y panel</h2>
      <AppCard>
        <EmptyState
          title="No hay avisos pendientes"
          hint="Cuando una familia avise una ausencia, aparece acá."
          icono="bandeja"
        >
          <template #action>
            <AppButton variante="secundario" @click="sheet = true">Abrir panel</AppButton>
          </template>
        </EmptyState>
      </AppCard>
      <AppSheet v-model="sheet" titulo="Panel de ejemplo">
        <p class="texto-muted">En celular sube desde abajo; en computadora es un diálogo.</p>
        <template #pie="{ cerrar }">
          <AppButton variante="secundario" @click="cerrar">Cancelar</AppButton>
          <AppButton @click="cerrar">Aceptar</AppButton>
        </template>
      </AppSheet>
    </section>
  </div>
</template>

<style scoped>
.catalogo {
  display: flex;
  flex-direction: column;
  gap: var(--sp-10);
  padding-bottom: var(--sp-12);
}

.cabecera {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--sp-4);
  flex-wrap: wrap;
}

h1 {
  font-size: var(--fs-2xl);
  letter-spacing: var(--tracking-tight);
}

h2 {
  margin-bottom: var(--sp-4);
  font-size: var(--fs-lg);
}

.fila {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-3);
}

.fila + .fila {
  margin-top: var(--sp-4);
}

.alineada {
  align-items: center;
}

.grilla {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: var(--sp-4);
}

.bloque {
  margin-top: var(--sp-4);
}

.bloque-chico {
  margin-top: var(--sp-3);
}

.icono {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border: 1px solid var(--border);
  border-radius: var(--radius-md);
  color: var(--text-2);
}
</style>
