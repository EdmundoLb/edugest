import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vitest/config'

// Config aparte de vite.config.js para no cargar el plugin de devtools en
// los tests; solo hace falta el alias "@".
export default defineConfig({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    include: ['src/**/*.test.js'],
  },
})
