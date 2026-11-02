# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Sistema Académico — attendance tracking system for "EduGest". Vue 3 SPA (Vite) with **no backend server of its own**: all data access goes straight from the browser to Supabase (Postgres + Auth) using the public anon key. There is no Node/API layer to add business logic to — validation and access control live either in the Vue components or in the Supabase database (RLS policies, triggers, constraints).

Roles: `estudiante`, `docente`, `admin`, `tutor` (padre/madre/tutor, migration 0013) (stored in `perfiles.rol`). See `docs/BASE_DE_DATOS.md` for the full schema and RLS design — read it before touching auth, roles, or any Supabase query, since the real security boundary lives in the database, not in this repo.

## Commands

```sh
npm install          # install deps
npm run dev           # Vite dev server (http://localhost:5173)
npm run build          # production build to dist/
npm run preview        # preview the production build
npm run lint            # runs oxlint then eslint, both with --fix
npm run format           # prettier --write on src/
npm test                 # vitest run (unit tests of src/lib, *.test.js next to the code)
```

Tests cover the pure helpers in `src/lib/` (dates, weekdays, CSV, WhatsApp messages, pagination, percentages); there are no component or end-to-end tests. `vitest.config.js` is separate from `vite.config.js` on purpose (no devtools plugin). Note: `npm install` of new packages may hit an npm 10 arborist bug (`Cannot read properties of null (reading 'edgesOut')`) caused by vitest's optional peers; `--legacy-peer-deps` works around it, but then peers are no longer auto-installed — that's why `vue-eslint-parser` is an explicit devDependency.

## Environment

Requires `.env` with `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (see `.env.example`). The client throws on startup if either is missing (`src/lib/supabase.js`).

## Architecture

- **Auth/session state**: `src/stores/auth.js` is a hand-rolled singleton store (no Pinia) built with Vue `reactive()`. `useAuth()` returns shared state plus `initSession`, `login`, `logout`, `signUp`, `cargarPerfil`, and role helpers (`esEstudiante`, `esDocente`, `esAdmin`). `cargarPerfil()` fetches the `perfiles` row for the logged-in user, then the matching `alumnos` or `profesores` row depending on `rol`.
- **Routing / access control**: `src/router/index.js` gates routes with `meta: { requiresAuth, rol }`. `rol` can be a single role string or an array of allowed roles. The `beforeEach` guard checks the session and the user's `perfiles.rol` against `meta.rol`, redirecting to a role-appropriate home (`estudiante` → `/MiAsistencia`, `docente` → `/ProfesorDashboard`, `admin` → `/admin`, `tutor` → `/familia`) when access is denied, and sends inactive profiles (`perfiles.activo = false`) back to `/login?pendiente=1`. **This guard is a UX convenience, not the security boundary** — it can be bypassed by calling the Supabase REST API directly, so any access restriction that actually matters must also exist as an RLS policy in the database.
- **User provisioning happens in the database, not in Vue**: `RegistroUsuarios.vue` only calls `supabase.auth.signUp()` with profile fields (nombre, apellido, ci, telefono, rol, especialidad) passed as `options.data`. A Postgres trigger (`handle_new_user`, fired `AFTER INSERT` on `auth.users`) reads that metadata and creates the `perfiles` row and the matching `alumnos`/`profesores` row automatically. **Never add a client-side `insert` into `perfiles`/`alumnos`/`profesores` after `signUp()`** — the trigger already does it, and a duplicate insert will either error or create a second row with the same `user_id`, breaking `cargarPerfil()`'s `.single()` calls. Full trigger source is in `docs/BASE_DE_DATOS.md`.
- **Course enrollment**: the `inscripciones` table (alumno_id ↔ curso_id) drives which students appear when a teacher calls roll (`LlamarLista.vue`) and which students/schedules a given teacher or student can see under RLS. Admins manage courses, schedules and enrollment from `/admin/cursos` (`src/views/admin/`), including CSV import; creating a brand-new student goes through the `admin_crear_alumno` SQL function (migration 0009) because a student row needs an `auth.users` account, which the browser can't create with the anon key.
- **Reports & history**: `HistorialAlumno.vue` (per-course / per-month / class-by-class history of one student, used by `EstudiantePerfil` and `MiAsistencia`) and `ReporteInstitucional.vue` (`/Reportes/institucional`, every visible course for a month + 6-month trend) aggregate in the browser with the pure helpers in `src/lib/historial.js` (same day-combining rule as the SQL functions: ausente > justificado > presente). `ReporteMensual.vue` is the per-course student × day grid.
- **Family portal (migration 0013)**: role `tutor` sees only the students linked to it in `tutores_alumnos`, read-only, via `tutor_de_alumno()`/`tutor_ve_curso()` clauses in the SELECT policies. A tutor links to a student by redeeming a single-use code (`generar_codigo_vinculacion` by admin in `FamiliaAlumnoPanel`, `vincular_tutor` RPC or `codigo_vinculacion` in signUp metadata); never insert into `tutores_alumnos` from Vue. Views in `src/views/familia/`, data in `src/lib/api/familias.js`. The principal tutor's `perfiles.telefono` is copied by a trigger to `alumnos.telefono_padre`, so existing WhatsApp flows reach them. Also in 0013: `handle_new_user` only accepts `estudiante`/`docente`/`tutor` (never `admin`), self-registered docentes start with `perfiles.activo = false` until an admin approves them (`CuentasPendientes` on `/admin`), inactive profiles get nothing from RLS, and a student can't change their own `ci`/`nombre`/`apellido`/`telefono_padre` through the API.
- **Withdrawals & justifications (migration 0012)**: withdrawing a student from a course is `inscripciones.activa = false` (`darDeBaja` in `src/lib/api/admin.js`), never a `delete` once they have attendance — their history must stay in reports. Absence justifications by date range live in `justificaciones`; DB triggers flip matching `asistencia` rows to/from `justificado`, so don't replicate that logic in Vue. Code touching the 0012 columns/table falls back with `esEsquemaFaltante()` (`src/lib/api/reportes.js`) while the migration isn't applied.
- **Views under `src/views/` map 1:1 to routes**; role-specific dashboards (`ProfesorDashboard`, `AdminDashboard`) link out to shared views (`MisCursos`, `MisReportes`, `Estudiantes*`) that branch their queries internally on `state.perfil.rol` (e.g. admin sees every horario/report system-wide, a docente sees only their own).
- **Date handling**: attendance dates are stored as `date` (no time) columns. Never use `new Date(dateOnlyString)` or `new Date().toISOString().split('T')[0]` for these — both silently shift by a day depending on the browser's timezone relative to UTC. Use `src/lib/fecha.js` (`hoyLocal()`, `parseFechaLocal()`, `formatearFecha()`) instead.
- **Layout & design system**: `App.vue` owns the layout (fixed `AppNavbar`, `<main>` with `padding-top: var(--navbar-height)`, footer, `ToastHost`, `ConfirmDialog`). Views are normal-flow pages that start with `<PageHeader titulo=... :volver=...>`; never make a view `position: fixed` again. Colors come only from CSS tokens in `src/assets/main.css` (light by default, `[data-theme='dark']` overrides, forced light when printing); never hardcode hex/rgba colors in components. Shared utility classes there: `.contenedor`, `.tarjeta`, `.btn .btn-primario|.btn-secundario|.btn-peligro|.btn-chico`, `.campo`, `.input`. Theme toggle: `src/composables/useTema.js` (initial theme set by an inline script in `index.html` to avoid a flash).
- **Feedback**: use `useToast()` (`src/composables/useToast.js`) for success/error messages instead of `console.error` alone, and `useConfirm()` (`src/composables/useConfirm.js`, promise-based) instead of `window.confirm`.
- **Data access helpers**: `src/lib/api/` (`reportes.js`, `cursos.js`, `admin.js`, `alertas.js`). The logged-in teacher/student row is already in `state.datosUsuario` (loaded once in `main.js` before mount, and by `SimpleLogin` after login) — don't re-query `profesores`/`alumnos` by `perfil_id`. Any query that can exceed 1000 rows must go through `traerTodo()` (`src/lib/paginar.js`) or an aggregating SQL function. Order schedules with `ordenarPorDia()`, not `.order('dia_semana')` (alphabetical). Show times with `formatearHora()`.
- **Database migrations**: there is no Supabase CLI linked to a project here. Schema/RLS changes live as plain SQL files in `supabase/migrations/`, numbered in the order they must be run, applied manually by pasting into the Supabase Dashboard SQL Editor (see `docs/BASE_DE_DATOS.md` for the exact procedure and for how to introspect the live schema/RLS from a fresh session).

## Docs

- `docs/BASE_DE_DATOS.md` — full current schema, table relationships, RLS policy design and rationale, the `handle_new_user` trigger, how to run/verify migrations, test accounts.
- `docs/AUDITORIA_2026-08.md` — findings and fixes from the 2026-08 security/correctness audit; read this before doing another audit so you don't re-discover the same issues from scratch.
