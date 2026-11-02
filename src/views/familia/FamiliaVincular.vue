<script setup>
// Canje del código de vinculación que la institución le da a la familia
// (vincular_tutor, 0013). La base limita los intentos fallidos por hora.
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import PageHeader from '@/components/PageHeader.vue'
import { useToast } from '@/composables/useToast'
import { vincularConCodigo, esFuncionFaltante } from '@/lib/api/familias'
import { codigoValido, formatearCodigo } from '@/lib/vinculacion'

const router = useRouter()
const toast = useToast()

const codigo = ref('')
const enviando = ref(false)
const error = ref('')

const valido = computed(() => codigoValido(codigo.value))

async function vincular() {
  error.value = ''
  if (!valido.value) {
    error.value = 'El código tiene 8 caracteres, por ejemplo ABCD-EF23.'
    return
  }
  enviando.value = true
  try {
    const r = await vincularConCodigo(codigo.value)
    if (!r?.ok) {
      error.value = r?.error || 'No se pudo vincular el código.'
      return
    }
    toast.exito(`Listo, ya podés ver la asistencia de ${r.nombre}`)
    router.push('/familia')
  } catch (e) {
    if (esFuncionFaltante(e)) {
      error.value = 'El portal de familias todavía no está habilitado en la institución.'
    } else {
      toast.error('No se pudo vincular el código', e)
    }
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <div class="vincular-page">
    <PageHeader titulo="Vincular alumno" volver="/familia" />

    <div class="contenedor">
      <form class="tarjeta formulario" @submit.prevent="vincular">
        <h2>Ingresá el código de vinculación</h2>
        <p class="texto-muted">
          La institución te da un código por cada hijo. Es de un solo uso y vence a los 14 días; si
          se te venció, pedí uno nuevo.
        </p>

        <div class="campo">
          <label for="codigo">Código</label>
          <input
            id="codigo"
            :value="codigo"
            class="input codigo"
            type="text"
            placeholder="ABCD-EF23"
            autocomplete="off"
            autocapitalize="characters"
            maxlength="9"
            :disabled="enviando"
            @input="codigo = formatearCodigo($event.target.value)"
          />
        </div>

        <p v-if="error" class="error" role="alert">{{ error }}</p>

        <button type="submit" class="btn btn-primario" :disabled="enviando || !valido">
          {{ enviando ? 'Vinculando...' : 'Vincular' }}
        </button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.vincular-page {
  min-height: calc(100vh - var(--navbar-height));
}

.formulario {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  max-width: 460px;
  padding: 1.5rem;
}

.formulario h2 {
  font-size: 1.125rem;
  font-weight: 700;
}

.formulario p {
  font-size: 0.875rem;
}

.codigo {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 1.25rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
}

.error {
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--danger-border);
  border-radius: var(--radius-sm);
  background: var(--danger-soft);
  color: var(--danger-text);
}

.formulario .btn {
  align-self: flex-start;
}
</style>
