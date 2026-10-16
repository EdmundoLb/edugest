# Sistema Académico — Centro Cultural Gymmart

Sistema de control de asistencia para el Centro Cultural Gymmart. Los docentes toman lista desde el celular o la computadora, la administración revisa los informes y avisa a las familias por WhatsApp, y cada estudiante puede consultar su propia asistencia.

## Funcionalidades

- **Estudiantes**: historial y porcentaje de asistencia propio.
- **Docentes**: cursos y horarios asignados, llamado de lista (presente / ausente / justificado, con observaciones), reportes de sus cursos y envío del informe diario a administración.
- **Administración**: panel con estadísticas, alumnos por curso, reportes de todos los cursos, revisión de informes y avisos por WhatsApp a padres/tutores.
- Tema claro y oscuro.

## Tecnología

- [Vue 3](https://vuejs.org/) + [Vite](https://vite.dev/) (SPA, sin backend propio).
- [Supabase](https://supabase.com/) para base de datos (Postgres) y autenticación. La seguridad real está en las políticas RLS de la base, no en el frontend — ver [`docs/BASE_DE_DATOS.md`](docs/BASE_DE_DATOS.md).

## Puesta en marcha

Requiere Node `^20.19.0` o `>=22.12.0`.

```sh
npm install
cp .env.example .env   # completar VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY
npm run dev            # http://localhost:5173
```

Si es una base de Supabase nueva, aplicar antes las migraciones de `supabase/migrations/` en orden (procedimiento en [`docs/BASE_DE_DATOS.md`](docs/BASE_DE_DATOS.md)).

Para que funcione "¿Olvidaste tu contraseña?", agregar `<url-de-la-app>/reset-password` en Supabase → Authentication → URL Configuration → Redirect URLs.

## Scripts

| comando | qué hace |
|---|---|
| `npm run dev` | servidor de desarrollo |
| `npm run build` | build de producción en `dist/` |
| `npm run preview` | sirve el build de producción |
| `npm run lint` | oxlint + eslint (con `--fix`) |
| `npm run format` | prettier sobre `src/` |

## Estructura

```
src/
  assets/main.css     tokens de diseño (colores, tema claro/oscuro)
  components/         componentes compartidos (navbar, encabezados, toasts...)
  composables/        useTema, useToast
  lib/                cliente Supabase y utilidades (fechas, días, WhatsApp)
  router/             rutas y control de acceso por rol (solo UX)
  stores/auth.js      sesión y perfil del usuario
  views/              una vista por ruta
supabase/migrations/  cambios de esquema/RLS, numerados, se aplican a mano
docs/                 base de datos y auditorías
```

## Documentación

- [`docs/BASE_DE_DATOS.md`](docs/BASE_DE_DATOS.md) — esquema, RLS, trigger de alta de usuarios, migraciones, cuentas de prueba.
- [`docs/AUDITORIA_2026-08.md`](docs/AUDITORIA_2026-08.md) — auditoría de seguridad de agosto 2026.
