<script setup>
// Cuentas que se registraron solas y esperan aprobación del admin (hoy:
// docentes, ver handle_new_user en 0013). Si no hay ninguna, no muestra nada.
import { ref, onMounted } from 'vue'
import { useToast } from '@/composables/useToast'
import { cuentasPendientes, aprobarCuenta } from '@/lib/api/familias'
import { formatearFecha, fechaLocalDeTimestamp } from '@/lib/fecha'

const toast = useToast()

const ROL_TEXTO = { docente: 'Docente', estudiante: 'Estudiante', tutor: 'Familia' }

const cuentas = ref([])
const aprobando = ref(null)

onMounted(async () => {
  try {
    cuentas.value = await cuentasPendientes()
  } catch (e) {
    // Sin 0013 no hay cuentas pendientes; no hace falta avisar.
    console.error(e)
  }
})

async function aprobar(c) {
  aprobando.value = c.id
  try {
    await aprobarCuenta(c.id)
    cuentas.value = cuentas.value.filter((x) => x.id !== c.id)
    toast.exito(`Cuenta de ${c.nombre} ${c.apellido} aprobada`)
  } catch (e) {
    toast.error('No se pudo aprobar la cuenta', e)
  } finally {
    aprobando.value = null
  }
}
</script>

<template>
  <section v-if="cuentas.length" class="tarjeta pendientes" aria-label="Cuentas pendientes">
    <h2>Cuentas pendientes de aprobación</h2>
    <p class="texto-muted chico">
      Se registraron desde la página pública. Hasta que las apruebes no pueden ver ningún dato.
    </p>
    <ul>
      <li v-for="c in cuentas" :key="c.id">
        <div class="datos">
          <strong>{{ c.nombre }} {{ c.apellido }}</strong>
          <span class="texto-muted chico">
            {{ ROL_TEXTO[c.rol] || c.rol
            }}<template v-if="c.telefono"> · {{ c.telefono }}</template>
            · se registró el
            {{
              formatearFecha(fechaLocalDeTimestamp(c.created_at), { day: 'numeric', month: 'long' })
            }}
          </span>
        </div>
        <button
          type="button"
          class="btn btn-primario btn-chico"
          :disabled="aprobando === c.id"
          @click="aprobar(c)"
        >
          Aprobar
        </button>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.pendientes {
  padding: 1.25rem;
  border-left: 4px solid var(--warning);
}

.pendientes h2 {
  font-size: 1.0625rem;
  font-weight: 700;
  margin-bottom: 0.25rem;
}

.chico {
  font-size: 0.8125rem;
}

ul {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-top: 0.75rem;
}

li {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--border);
  border-radius: var(--radius);
}

.datos {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}
</style>
