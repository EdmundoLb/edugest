import { ref } from 'vue'

// Tema claro/oscuro. El valor inicial ya lo fija un script inline en
// index.html (antes de que cargue la app, para evitar un parpadeo de tema
// incorrecto); acá solo se lee y se cambia.

const CLAVE = 'tema'

function leerGuardado() {
  try {
    const valor = localStorage.getItem(CLAVE)
    return valor === 'light' || valor === 'dark' ? valor : null
  } catch {
    return null
  }
}

function temaDelSistema() {
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

const tema = ref(document.documentElement.dataset.theme || leerGuardado() || temaDelSistema())

function aplicar(valor) {
  tema.value = valor
  document.documentElement.dataset.theme = valor
}

export function useTema() {
  function alternarTema() {
    const nuevo = tema.value === 'dark' ? 'light' : 'dark'
    aplicar(nuevo)
    try {
      localStorage.setItem(CLAVE, nuevo)
    } catch {
      // Sin almacenamiento (modo privado, etc.): el tema dura hasta recargar.
    }
  }

  return { tema, alternarTema }
}
