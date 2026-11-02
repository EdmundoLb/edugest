// Service worker de EduGest: hace la app instalable y muestra las
// notificaciones push (las manda la Edge Function enviar-push, ver
// docs/NOTIFICACIONES.md). No cachea nada: la app sigue necesitando
// conexión como hasta ahora.

self.addEventListener('install', () => self.skipWaiting())

self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()))

self.addEventListener('push', (event) => {
  let datos
  try {
    datos = event.data ? event.data.json() : {}
  } catch {
    datos = { titulo: event.data?.text() }
  }
  event.waitUntil(
    self.registration.showNotification(datos.titulo || 'EduGest', {
      body: datos.cuerpo || '',
      icon: '/icons/icono-192.png',
      badge: '/icons/icono-192.png',
      tag: datos.tag,
      data: { link: datos.link || '/' },
    }),
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const destino = new URL(event.notification.data?.link || '/', self.location.origin).href
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((ventanas) => {
      const abierta = ventanas.find((v) => v.url.startsWith(self.location.origin))
      if (abierta) return abierta.navigate(destino).then((v) => (v ?? abierta).focus())
      return self.clients.openWindow(destino)
    }),
  )
})
