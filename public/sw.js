// Service worker de EduGest:
// - hace la app instalable y muestra las notificaciones push (las manda la
//   Edge Function enviar-push, ver docs/NOTIFICACIONES.md);
// - guarda una copia de la app (HTML, JS, CSS, íconos) para que abra sin
//   conexión y el docente pueda tomar lista offline. Los datos de Supabase
//   NO se cachean acá: la app guarda su propia copia mínima (src/lib/listaOffline.js).

const CACHE = 'edugest-app-v1'

self.addEventListener('install', () => self.skipWaiting())

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((claves) => Promise.all(claves.filter((c) => c !== CACHE).map((c) => caches.delete(c))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (event) => {
  const req = event.request
  const url = new URL(req.url)
  if (req.method !== 'GET' || url.origin !== self.location.origin) return

  // Páginas: primero la red (siempre la versión nueva); sin red, la última
  // copia de la app (es una SPA: cualquier ruta sirve con index.html).
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((resp) => {
          const copia = resp.clone()
          caches.open(CACHE).then((c) => c.put('/index.html', copia))
          return resp
        })
        .catch(() => caches.match('/index.html')),
    )
    return
  }

  // Archivos de la build (con hash en el nombre, no cambian) e íconos:
  // primero la copia, si no la red.
  if (url.pathname.startsWith('/assets/') || url.pathname.startsWith('/icons/')) {
    event.respondWith(
      caches.match(req).then(
        (guardada) =>
          guardada ||
          fetch(req).then((resp) => {
            if (resp.ok) {
              const copia = resp.clone()
              caches.open(CACHE).then((c) => c.put(req, copia))
            }
            return resp
          }),
      ),
    )
  }
})

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
