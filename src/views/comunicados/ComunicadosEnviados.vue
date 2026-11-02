<script setup>
// Comunicados que mandó el usuario (admin: todos) con cuántas familias los
// leyeron y respondieron.
import { ref, onMounted } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import AppSpinner from '@/components/AppSpinner.vue'
import EmptyState from '@/components/EmptyState.vue'
import { useToast } from '@/composables/useToast'
import { comunicadosEnviados, esFuncionFaltante } from '@/lib/api/comunicados'
import { TIPOS_COMUNICADO, AUDIENCIAS } from '@/lib/comunicados'
import { formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const toast = useToast()

const lista = ref([])
const cargando = ref(true)
const faltaMigracion = ref(false)

onMounted(async () => {
  try {
    lista.value = await comunicadosEnviados()
  } catch (e) {
    if (esFuncionFaltante(e)) faltaMigracion.value = true
    else toast.error('No se pudieron cargar los comunicados', e)
  } finally {
    cargando.value = false
  }
})

function destino(c) {
  if (c.audiencia === 'curso') return c.curso_nombre
  if (c.audiencia === 'alumno') return c.alumno_nombre
  return AUDIENCIAS.institucion
}

function pct(parte, total) {
  return total ? Math.round((Number(parte) / Number(total)) * 100) : 0
}
</script>

<template>
  <div class="enviados-page">
    <PageHeader titulo="Comunicados" subtitulo="Cuaderno de comunicaciones con las familias" />

    <div class="contenedor">
      <div class="barra">
        <router-link to="/comunicados/nuevo" class="btn btn-primario">Nuevo comunicado</router-link>
      </div>

      <div v-if="cargando" class="cargando"><AppSpinner size="medium" /></div>

      <EmptyState
        v-else-if="faltaMigracion"
        title="Función no habilitada"
        hint="Falta aplicar la migración 0015_comunicados.sql."
      />

      <EmptyState
        v-else-if="!lista.length"
        title="Todavía no mandaste comunicados"
        hint="Avisos, autorizaciones para salidas, encuestas o citaciones: las familias los ven en el portal y queda registrado quién los leyó."
      />

      <ul v-else class="lista">
        <li v-for="c in lista" :key="c.id">
          <router-link :to="`/comunicados/${c.id}`" class="tarjeta item">
            <div class="item-cabecera">
              <span class="tipo" :class="c.tipo">{{ TIPOS_COMUNICADO[c.tipo]?.texto }}</span>
              <strong class="titulo">{{ c.titulo }}</strong>
              <span class="texto-muted chico fecha">
                {{
                  formatearFecha(fechaLocalDeTimestamp(c.created_at), {
                    day: 'numeric',
                    month: 'short',
                  })
                }}
              </span>
            </div>
            <span class="texto-muted chico"> Para: {{ destino(c) }} · {{ c.autor_nombre }} </span>

            <div v-if="Number(c.destinatarios)" class="avance">
              <div class="barra-avance" :aria-label="`${pct(c.leidos, c.destinatarios)}% leído`">
                <span :style="{ width: `${pct(c.leidos, c.destinatarios)}%` }" />
              </div>
              <span class="chico">
                Leído por {{ c.leidos }} de {{ c.destinatarios }}
                <template v-if="c.tipo !== 'aviso'"> · {{ c.respondidos }} respondieron </template>
              </span>
            </div>
            <span v-else class="chico sin-familias">
              Ninguna familia vinculada recibió este comunicado.
            </span>
          </router-link>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.enviados-page {
  min-height: calc(100vh - var(--navbar-height));
}

.barra {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 1rem;
}

.cargando {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.lista {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.item {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  padding: 1rem 1.25rem;
  color: var(--text);
  text-decoration: none;
}

.item:hover {
  background: var(--surface-hover);
}

.item-cabecera {
  display: flex;
  align-items: center;
  gap: 0.625rem;
}

.titulo {
  flex: 1;
  min-width: 0;
}

.fecha {
  white-space: nowrap;
}

.chico {
  font-size: 0.8125rem;
}

.tipo {
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  font-size: 0.6875rem;
  font-weight: 700;
  text-transform: uppercase;
  white-space: nowrap;
  background: var(--primary-soft);
  color: var(--primary-text);
}

.tipo.autorizacion,
.tipo.citacion {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.avance {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.barra-avance {
  flex: 1;
  min-width: 120px;
  max-width: 280px;
  height: 0.5rem;
  border-radius: 999px;
  background: var(--surface-hover);
  overflow: hidden;
}

.barra-avance span {
  display: block;
  height: 100%;
  background: var(--success);
}

.sin-familias {
  color: var(--warning-text);
}
</style>
