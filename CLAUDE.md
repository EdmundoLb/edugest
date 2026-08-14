# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Sistema Académico — attendance tracking system for "Centro Cultural Gymmart". Vue 3 SPA (Vite) with **no backend server of its own**: all data access goes straight from the browser to Supabase (Postgres + Auth) using the public anon key. There is no Node/API layer to add business logic to — validation and access control live either in the Vue components or in the Supabase database (RLS policies, triggers, constraints).

Roles: `estudiante`, `docente`, `admin` (stored in `perfiles.rol`). See `docs/BASE_DE_DATOS.md` for the full schema and RLS design — read it before touching auth, roles, or any Supabase query, since the real security boundary lives in the database, not in this repo.

## Commands

```sh
npm install          # install deps
npm run dev           # Vite dev server (http://localhost:5173)
npm run build          # production build to dist/
npm run preview        # preview the production build
npm run lint            # runs oxlint then eslint, both with --fix
npm run format           # prettier --write on src/
```

There is no test suite configured (no test script, no test runner installed).

## Environment

Requires `.env` with `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (see `.env.example`). The client throws on startup if either is missing (`src/lib/supabase.js`).

## Architecture

- **Auth/session state**: `src/stores/auth.js` is a hand-rolled singleton store (no Pinia) built with Vue `reactive()`. `useAuth()` returns shared state plus `initSession`, `login`, `logout`, `signUp`, `cargarPerfil`, and role helpers (`esEstudiante`, `esDocente`, `esAdmin`). `cargarPerfil()` fetches the `perfiles` row for the logged-in user, then the matching `alumnos` or `profesores` row depending on `rol`.
- **Routing / access control**: `src/router/index.js` gates routes with `meta: { requiresAuth, rol }`. `rol` can be a single role string or an array of allowed roles. The `beforeEach` guard checks the session and the user's `perfiles.rol` against `meta.rol`, redirecting to a role-appropriate home (`estudiante` → `/MiAsistencia`, `docente` → `/ProfesorDashboard`, `admin` → `/admin`) when access is denied. **This guard is a UX convenience, not the security boundary** — it can be bypassed by calling the Supabase REST API directly, so any access restriction that actually matters must also exist as an RLS policy in the database.
- **User provisioning happens in the database, not in Vue**: `RegistroUsuarios.vue` only calls `supabase.auth.signUp()` with profile fields (nombre, apellido, ci, telefono, rol, especialidad) passed as `options.data`. A Postgres trigger (`handle_new_user`, fired `AFTER INSERT` on `auth.users`) reads that metadata and creates the `perfiles` row and the matching `alumnos`/`profesores` row automatically. **Never add a client-side `insert` into `perfiles`/`alumnos`/`profesores` after `signUp()`** — the trigger already does it, and a duplicate insert will either error or create a second row with the same `user_id`, breaking `cargarPerfil()`'s `.single()` calls. Full trigger source is in `docs/BASE_DE_DATOS.md`.
- **Course enrollment**: the `inscripciones` table (alumno_id ↔ curso_id) drives which students appear when a teacher calls roll (`LlamarLista.vue`) and which students/schedules a given teacher or student can see under RLS. It is not visible anywhere in the UI yet — enrollment is currently managed by hand via SQL (see `supabase/migrations/`).
- **Views under `src/views/` map 1:1 to routes**; role-specific dashboards (`ProfesorDashboard`, `AdminDashboard`) link out to shared views (`MisCursos`, `MisReportes`, `Estudiantes*`) that branch their queries internally on `state.perfil.rol` (e.g. admin sees every horario/report system-wide, a docente sees only their own).
- **Date handling**: attendance dates are stored as `date` (no time) columns. Never use `new Date(dateOnlyString)` or `new Date().toISOString().split('T')[0]` for these — both silently shift by a day depending on the browser's timezone relative to UTC. Use `src/lib/fecha.js` (`hoyLocal()`, `parseFechaLocal()`, `formatearFecha()`) instead.
- **Database migrations**: there is no Supabase CLI linked to a project here. Schema/RLS changes live as plain SQL files in `supabase/migrations/`, numbered in the order they must be run, applied manually by pasting into the Supabase Dashboard SQL Editor (see `docs/BASE_DE_DATOS.md` for the exact procedure and for how to introspect the live schema/RLS from a fresh session).

## Docs

- `docs/BASE_DE_DATOS.md` — full current schema, table relationships, RLS policy design and rationale, the `handle_new_user` trigger, how to run/verify migrations, test accounts.
- `docs/AUDITORIA_2026-08.md` — findings and fixes from the 2026-08 security/correctness audit; read this before doing another audit so you don't re-discover the same issues from scratch.
