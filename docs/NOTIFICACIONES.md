# Notificaciones de EduGest

Hay tres niveles. El primero funciona solo; los otros dos se activan siguiendo esta guía.

| Nivel | Qué hace | Qué necesita |
|---|---|---|
| **En la app** (0016) | Campanita en la barra con faltas, avisos de familias, comunicados y respuestas, en tiempo real. | Nada: ya está activo. |
| **Push** (0017 + `enviar-push`) | La misma notificación llega al celular o la computadora aunque la app esté cerrada. | Claves VAPID y publicar una Edge Function. |
| **Email semanal** (0017 + `resumen-semanal`) | Los viernes, cada familia recibe el resumen de asistencia de la semana (notificación y email). | Cuenta gratuita de [Resend](https://resend.com) (3.000 emails/mes). |

Sin push ni email configurados, la app funciona igual: el botón "Activar notificaciones" no aparece y la migración 0017 no hace llamadas.

## Cómo funciona por dentro

1. Un trigger de la base crea la fila en `notificaciones` (nunca el navegador). Ver `supabase/migrations/0016_notificaciones.sql`.
2. La campanita (`CampanaNotificaciones.vue`) la recibe por Supabase Realtime.
3. Con 0017, un trigger llama por HTTP (`pg_net`) a la Edge Function `enviar-push`, que la manda a cada dispositivo suscripto (`suscripciones_push`). Las llamadas llevan el header `x-edugest-secret`; la URL y el secreto se leen de Supabase Vault.
4. `pg_cron` llama a `resumen-semanal` los viernes a las 20:00 UTC (17:00 en Paraguay/Argentina).

## Activar push y email, paso a paso

Las claves ya generadas están en un archivo de texto fuera del repo (te lo pasa quien hizo la instalación; si no lo tenés, generalas con `npx web-push generate-vapid-keys` y un secreto cualquiera largo y aleatorio). **Nunca subas esas claves al repositorio.**

### 1. Clave pública en la app

- En **Vercel → el proyecto → Settings → Environment Variables**, agregá `VITE_VAPID_PUBLIC_KEY` con la clave **pública**, y volvé a desplegar.
- Para probar en tu computadora, agregala también al `.env` local.

### 2. Publicar las dos Edge Functions

En **Supabase → Edge Functions → Deploy a new function → Via Editor**, una por vez:

- Nombre `enviar-push`: pegá el contenido de `supabase/functions/enviar-push/index.ts`.
- Nombre `resumen-semanal`: pegá el contenido de `supabase/functions/resumen-semanal/index.ts`.

En la configuración de **cada una**, desactivá **"Verify JWT with legacy secret"** (o "Enforce JWT verification"): no las llama un usuario sino la base, y las protege el secreto compartido.

### 3. Secretos de las funciones

En **Supabase → Edge Functions → Secrets** agregá:

| Nombre | Valor |
|---|---|
| `EDUGEST_WEBHOOK_SECRET` | el secreto compartido del archivo |
| `VAPID_PUBLIC_KEY` | la clave pública |
| `VAPID_PRIVATE_KEY` | la clave privada |
| `VAPID_SUBJECT` | `mailto:` + un email de la institución, ej. `mailto:direccion@tu-colegio.edu.py` |
| `RESEND_API_KEY` | (para el email) la API key de Resend |
| `RESEND_FROM` | (para el email) ej. `EduGest <avisos@tu-dominio.com>` |
| `APP_URL` | la dirección pública de la app, ej. `https://edugest.vercel.app` |

**Resend:** creá la cuenta en resend.com y verificá un dominio propio (Domains → Add domain). Sin dominio verificado, Resend solo deja mandar emails a la dirección con la que creaste la cuenta, así que las familias no los recibirían.

### 4. URL y secreto en Vault

En **SQL Editor**, una sola vez (reemplazá el secreto por el del archivo):

```sql
select vault.create_secret('https://azprithoukrmpyhtfpoj.supabase.co/functions/v1', 'edugest_functions_url');
select vault.create_secret('PEGÁ-ACÁ-EL-SECRETO-COMPARTIDO', 'edugest_webhook_secret');
```

### 5. Aplicar la migración 0017

Pegá `supabase/migrations/0017_push_y_email.sql` completo en el SQL Editor y Run.

### 6. Probar

1. Entrá a la app como una familia, en **Mis hijos → Tu teléfono para avisos → Notificaciones en este dispositivo → Activar**, y aceptá el permiso del navegador.
2. Como docente, tomá lista marcando ausente a ese alumno: debería llegar la notificación al dispositivo.
3. Para probar el resumen sin esperar al viernes: `select public._llamar_edge_function('resumen-semanal', '{}'::jsonb);`
4. Si algo no llega: **Edge Functions → la función → Logs**, y en SQL `select * from net._http_response order by created desc limit 5;` (respuesta 401 = el secreto no coincide entre Vault y la función).

## Instalar la app en el celular

La app ya es instalable (`public/manifest.webmanifest` + `public/sw.js`): en Android, Chrome ofrece "Instalar app" o "Agregar a la pantalla principal"; en iPhone, Safari → Compartir → "Agregar a inicio". En iPhone las notificaciones push solo funcionan con la app instalada así (iOS 16.4 o posterior).
