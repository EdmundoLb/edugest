import { ref } from 'vue'

// Diálogo de confirmación propio (en vez de window.confirm, que bloquea la
// página y no respeta el diseño). Se muestra con <ConfirmDialog /> montado
// una vez en App.vue.
//
//   const confirmar = useConfirm()
//   if (await confirmar({ titulo: '¿Descartar cambios?', aceptar: 'Descartar', peligro: true })) { ... }

const dialogo = ref(null)

export function useConfirm() {
  return function confirmar({
    titulo,
    mensaje = '',
    aceptar = 'Aceptar',
    cancelar = 'Cancelar',
    peligro = false,
  }) {
    // Si ya hay uno abierto, se resuelve como cancelado antes de abrir el nuevo.
    dialogo.value?.resolver(false)
    return new Promise((resolve) => {
      dialogo.value = {
        titulo,
        mensaje,
        aceptar,
        cancelar,
        peligro,
        resolver: (valor) => {
          dialogo.value = null
          resolve(valor)
        },
      }
    })
  }
}

export function useDialogoActual() {
  return dialogo
}
