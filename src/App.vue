<script setup>
import { onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Navbar from '@/components/Navbar.vue'
import FooterSite from '@/components/FooterSite.vue'
import { useAuth } from '@/stores/auth'

const CHEQUEO_EXPIRACION_MS = 5 * 60 * 1000 // 5 minutos

const route = useRoute()
const router = useRouter()
const { state: authState, verificarExpiracion } = useAuth()

let intervaloExpiracion = null

onMounted(() => {
  intervaloExpiracion = setInterval(verificarExpiracion, CHEQUEO_EXPIRACION_MS)
})

onUnmounted(() => {
  if (intervaloExpiracion) clearInterval(intervaloExpiracion)
})

watch(
  () => authState.session,
  (session) => {
    if (!session && route.meta.requiresAuth) {
      router.push('/login')
    }
  }
)
</script>

<template>
  <Navbar />
  <RouterView />
  <FooterSite />
</template>
