# Base de datos (Supabase)

Este documento describe el estado real de la base de datos del proyecto (Postgres + Auth de Supabase) a partir de la auditoría de 2026-08. El repo **no** tiene el proyecto vinculado con el Supabase CLI — no hay `supabase/config.toml` ni forma de hacer `supabase db push`. Todo cambio de esquema se aplica **a mano**, pegando el SQL en el SQL Editor del Dashboard de Supabase.

No hay service_role key ni ningún otro credential con más permisos que el anon key en este repo (ver `.env`). Si en el futuro se agrega un MCP de Supabase u otro acceso con más privilegios, actualizar esta sección.

## Tablas (schema `public`)

```
perfiles
  id             uuid PK  -- IGUAL a auth.users.id (no es un id independiente)
  user_id        uuid FK -> auth.users.id  -- redundante con id, ambos se setean al mismo valor
  nombre         varchar
  apellido       varchar
  rol            varchar CHECK IN ('admin','docente','estudiante')
  activo         boolean default true
  telefono       varchar
  created_at     timestamptz

alumnos
  id                    uuid PK
  perfil_id             uuid UNIQUE FK -> perfiles.id
  ci                    varchar UNIQUE NOT NULL
  nombre, apellido      varchar NOT NULL
  fecha_nacimiento      date
  telefono              varchar
  telefono_padre        text     -- agregado en 0005; texto libre, sin validar formato/código de país
  direccion             text
  historial_academico   text
  created_at, updated_at timestamptz

profesores
  id                uuid PK
  perfil_id         uuid UNIQUE FK -> perfiles.id
  ci                varchar NOT NULL
  nombre, apellido  varchar NOT NULL
  telefono          varchar
  especialidad      varchar
  anos_experiencia  integer default 0
  create_at, undated_at  timestamptz   -- sic: nombres con typo en el esquema original, no son bugs de esta sesión, no renombrar sin coordinarlo (rompe cualquier código/reporte que ya los use)

cursos
  id            uuid PK
  nombre        text NOT NULL
  descripcion   text
  created_at    timestamptz

horarios
  id            uuid PK
  profesor_id   uuid FK -> profesores.id
  curso_id      uuid FK -> cursos.id        -- corregido en migración 0001; antes apuntaba (mal) a profesores.id
  dia_semana    varchar CHECK IN ('Lunes'..'Viernes')
  hora_inicio, hora_fin  time
  turno         varchar CHECK IN ('Matutino','Vespertino')
  created_at    timestamptz

inscripciones          -- agregada en migración 0001, no existía en el esquema original
  id            uuid PK
  alumno_id     uuid FK -> alumnos.id ON DELETE CASCADE
  curso_id      uuid FK -> cursos.id  ON DELETE CASCADE
  created_at    timestamptz
  UNIQUE (alumno_id, curso_id)

asistencia
  id            uuid PK
  horario_id    uuid FK -> horarios.id
  alumno_id     uuid FK -> alumnos.id
  fecha         date NOT NULL
  estado        varchar CHECK IN ('presente','ausente','justificado')  -- reemplazó a `presente boolean` en migración 0004
  observacion   text
  created_at    timestamptz
  UNIQUE (horario_id, alumno_id, fecha)   -- agregado en migración 0001; lo necesita el upsert de LlamarLista.vue

informes_asistencia     -- agregada en migración 0005
  id            uuid PK
  horario_id    uuid FK -> horarios.id
  fecha         date NOT NULL
  profesor_id   uuid FK -> profesores.id
  estado        varchar CHECK IN ('pendiente','revisado') default 'pendiente'
  creado_at     timestamptz
  revisado_at   timestamptz
  revisado_por  uuid FK -> perfiles.id
  UNIQUE (horario_id, fecha)
```

`informes_asistencia` es el "remito" que un docente arma después de tomar asistencia (`LlamarLista.vue`, botón "Remitir informe a administración"): marca que la asistencia de un horario+fecha ya está lista para que el admin le avise a los padres. El admin la revisa en `InformesAsistencia.vue`, arma un link de `wa.me` por alumno con `src/lib/whatsapp.js` (usa `alumnos.telefono_padre`) y la marca como `revisado`. No hay envío automático de mensajes — el admin abre WhatsApp y lo manda a mano — y no hay tracking de qué alumnos puntuales ya se le avisaron dentro de un informe, el estado es a nivel informe completo.

`estado = 'justificado'` es una falta con justificación (ausencia no perjudica el % de asistencia). En todos los reportes (`MiAsistencia.vue`, `MisReportes.vue`) el porcentaje de asistencia se calcula como `presentes / (total - justificados)`, es decir, las faltas justificadas quedan excluidas del denominador en vez de contar como ausencia.

No hay tabla de "matrícula por año/período" ni forma de dar de baja una inscripción desde la UI todavía — `inscripciones` es intencionalmente mínima.

## Alta de usuarios: todo pasa por un trigger, no por el frontend

`RegistroUsuarios.vue` llama a `supabase.auth.signUp({ email, password, options: { data: {...} } })` con `nombre, apellido, ci, telefono, rol, especialidad` en `data`. El frontend **no** hace ningún `insert` en `perfiles`/`alumnos`/`profesores`.

Un trigger `on_auth_user_created` (`AFTER INSERT ON auth.users`) ejecuta `public.handle_new_user()` (`SECURITY DEFINER`), que:
1. Lee `rol`, `nombre`, `apellido`, `ci`, `telefono`, `especialidad` de `raw_user_meta_data` (con defaults razonables si faltan — `rol` default `'estudiante'`, `ci` genera un placeholder `PENDIENTE-XXXXXXXX` si no vino).
2. Inserta la fila en `perfiles` (`id = auth.users.id`).
3. Si `rol = 'estudiante'`, inserta en `alumnos`. Si `rol = 'docente'`, inserta en `profesores`. Si `rol = 'admin'`, no inserta nada más (no hay flujo de alta pública para admin; se promueve a mano, ver más abajo).

**Si algún día se toca este flujo**: no dupliques el insert desde el cliente. Si hace falta cambiar qué datos junta el registro, se cambia `options.data` en `RegistroUsuarios.vue` **y** la función `handle_new_user` (están en `supabase/migrations/0001_rls_y_estructura.sql`, sección 6) — tienen que ir sincronizados.

## RLS: cómo está diseñada y por qué

Antes de la auditoría de 2026-08, RLS estaba activada en las 6 tablas pero las políticas eran, en la práctica, `using (true)` para el rol `public` — la base estaba abierta a internet sin login, y `cursos` no tenía ninguna política (bloqueaba a todos). Ver `docs/AUDITORIA_2026-08.md` para el detalle completo.

El diseño actual usa funciones **`SECURITY DEFINER`** como building blocks para evitar dos problemas:

- **Recursión de políticas**: si la policy de la tabla A hace un subquery directo contra la tabla B, y la policy de B a su vez consulta A (o una tercera tabla que vuelve a consultar A), Postgres tira `infinite recursion detected in policy` (código `42P17`). Esto pasó de verdad entre `horarios` e `inscripciones` (cada una consultaba la tabla de la otra directamente) y rompía el login de estudiantes y el panel de admin.
- La solución: cualquier chequeo "cross-table" que necesite una policy se escribe como una función `SECURITY DEFINER` (dueña de las tablas, típicamente el rol `postgres` si se creó desde el SQL Editor). Una función `SECURITY DEFINER` **bypassea RLS** en las tablas que consulta internamente (los dueños de tabla no están sujetos a RLS salvo que se use `FORCE ROW LEVEL SECURITY`, que no está activado acá) — así que dentro de esas funciones no hay recursión posible, aunque la lógica sea la misma.

Funciones helper (`public`, todas `SECURITY DEFINER stable`):

| función | qué hace |
|---|---|
| `is_admin()` | `true` si `auth.uid()` tiene `perfiles.rol = 'admin'` |
| `current_profesor_id()` | `profesores.id` del usuario logueado (o `null`) |
| `current_alumno_id()` | `alumnos.id` del usuario logueado (o `null`) |
| `docente_dicta_curso(curso_id)` | `true` si el docente logueado tiene un horario en ese curso |
| `alumno_inscripto_en_curso(curso_id)` | `true` si el alumno logueado está inscripto en ese curso |
| `docente_tiene_alumno(alumno_id)` | `true` si ese alumno está inscripto en algún curso que dicta el docente logueado |

**Regla para el futuro**: si agregás o cambiás una policy y necesitás consultar OTRA tabla protegida por RLS (no `perfiles`/`alumnos`/`profesores` vía las funciones que ya existen), escribí una función `SECURITY DEFINER` nueva en vez de un subquery `exists (select ... from esa_tabla ...)` directo en el `using`/`with_check`. Si dos tablas terminan consultándose una a la otra (aunque sea indirectamente, a través de una tercera), va a recursionar.

Resumen de políticas por tabla (todas restringidas a `authenticated`, no `public`):

- **perfiles**: SELECT/UPDATE solo la fila propia, o cualquiera si `is_admin()`. Un trigger separado (`prevent_self_privilege_escalation`, `BEFORE UPDATE`) revierte silenciosamente cualquier cambio a `rol`/`activo` que no venga de un admin — así que aunque la policy de UPDATE no filtre por columna, no hay forma de auto-ascender a admin.
- **alumnos**: SELECT propio / admin / `docente_tiene_alumno(id)`. UPDATE propio o admin. INSERT/DELETE solo admin.
- **profesores**: SELECT/UPDATE propio o admin. INSERT/DELETE solo admin.
- **cursos**: SELECT cualquier `authenticated` (no es dato sensible). INSERT/UPDATE/DELETE solo admin.
- **horarios**: SELECT admin / el docente dueño (`profesor_id = current_profesor_id()`) / `alumno_inscripto_en_curso(curso_id)`. Escritura solo admin (no hay UI todavía para que un docente cree sus propios horarios).
- **inscripciones**: SELECT admin / el alumno propio / `docente_dicta_curso(curso_id)`. Escritura solo admin.
- **asistencia**: SELECT admin / alumno propio / docente dueño del horario. INSERT/UPDATE/DELETE: docente dueño del horario, o admin.
- **informes_asistencia**: SELECT/UPDATE admin o el docente dueño del horario (`horario_id`, vía subquery directo a `horarios` — no hace falta una función `SECURITY DEFINER` nueva porque es una tabla hoja, ninguna policy de `horarios` la consulta a ella, así que no hay riesgo de recursión). INSERT: docente dueño del horario (con `profesor_id` propio) o admin. DELETE: solo admin.

## Cómo promover un usuario a `admin`

No hay flujo de alta pública para `admin`. Para promover una cuenta ya registrada, hay que correr esto en el SQL Editor (el trigger anti-auto-escalada bloquearía un `UPDATE` normal porque, corrido desde el SQL Editor, no hay `auth.uid()`):

```sql
alter table public.perfiles disable trigger trg_prevent_self_privilege_escalation;
update public.perfiles set rol = 'admin' where id = (select id from auth.users where email = 'correo@ejemplo.com');
alter table public.perfiles enable trigger trg_prevent_self_privilege_escalation;
```

## Migraciones

`supabase/migrations/*.sql`, numeradas, pensadas para pegarse **enteras** en el SQL Editor y ejecutarse con Run (cada una es una transacción `begin`/`commit`). Aplicar en orden:

1. `0001_rls_y_estructura.sql` — RLS completa (reemplaza las políticas viejas), tabla `inscripciones`, fix del FK `horarios.curso_id`, `UNIQUE` en `asistencia`, `handle_new_user` con rama docente, trigger anti-auto-escalada. Es idempotente (hace `drop policy if exists` de todo antes de crear).
2. `0002_fix_recursion_rls.sql` — corrige la recursión infinita entre `horarios` e `inscripciones` descrita arriba. **Depende de 0001.**
3. `0003_import_alumnos_2do_curso.sql` — limpieza de cursos duplicados vacíos e importación del curso "2do - Gabinete de Informática" con sus 11 alumnos reales.
4. `0004_estado_asistencia.sql` — reemplaza `asistencia.presente` (boolean) por `asistencia.estado` (varchar con `presente`/`ausente`/`justificado`), con backfill de los datos existentes.
5. `0005_informes_asistencia.sql` — agrega `alumnos.telefono_padre` y la tabla `informes_asistencia` (informe diario que el docente remite a administración para avisarle a los padres por WhatsApp), con sus políticas RLS.

1, 2 y 3 ya están aplicadas en el proyecto de Supabase de este equipo (confirmado en la auditoría de 2026-08 y en la verificación de la importación). 4 y 5 son nuevas — falta pegarlas en el SQL Editor. Si conectás este repo a un proyecto de Supabase nuevo (otro ambiente, staging, etc.), corré las cinco en orden antes de usar la app.

### Cómo introspeccionar el estado real de una base (para verificar antes de asumir nada)

El SQL Editor de Supabase, si le pegás varias sentencias `select` separadas por `;` y le das Run una sola vez, **solo muestra el resultado de la última**. Para no perder resultados, o consultás una sola cosa por vez, o armás un único `select` que junte todo en un solo `jsonb`. Ejemplo para ver tablas + políticas RLS de una:

```sql
select jsonb_pretty(jsonb_build_object(
  'tablas_y_rls', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'tabla', c.relname, 'rls_activado', c.relrowsecurity
    ) order by c.relname), '[]'::jsonb)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  ),
  'politicas_rls', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'tabla', tablename, 'politica', policyname, 'operacion', cmd,
      'roles', roles, 'using', qual, 'with_check', with_check
    ) order by tablename, cmd), '[]'::jsonb)
    from pg_policies where schemaname = 'public'
  )
)) as resultado;
```

Para ver el código fuente de una función: `select pg_get_functiondef(oid) from pg_proc where proname = 'nombre_funcion';`.

## Cuentas de prueba

Creadas durante la auditoría de 2026-08 para probar los tres roles de punta a punta. Contraseña de las tres: `Prueba123!` (seteada directo por SQL con `crypt('Prueba123!', gen_salt('bf'))` sobre `auth.users.encrypted_password` — útil si algún día hay que resetear una cuenta de prueba sin depender del envío de mails).

| email | rol | notas |
|---|---|---|
| `testdocente@ccg.com` | docente | tiene 1 horario asignado ("Curso de prueba", Lunes 08:00–09:00) |
| `testestudiante@ccg.com` | estudiante | inscripto en "Curso de prueba" |
| `admin@ccg.com` | admin | promovida a mano con el procedimiento de arriba (se registró originalmente como estudiante) |
