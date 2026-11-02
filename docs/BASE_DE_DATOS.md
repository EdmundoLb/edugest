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
  activa        boolean NOT NULL default true   -- 0012: false = dado de baja (nunca se borra si tiene asistencia)
  fecha_baja    date                          -- 0012
  motivo_baja   text                          -- 0012
  UNIQUE (alumno_id, curso_id)

asistencia
  id            uuid PK
  horario_id    uuid FK -> horarios.id
  alumno_id     uuid FK -> alumnos.id
  fecha         date NOT NULL
  estado        varchar CHECK IN ('presente','ausente','justificado')  -- reemplazó a `presente boolean` en migración 0004
  observacion   text
  created_at    timestamptz
  justificacion_id uuid  -- 0012: justificación que la marcó; SIN FK a propósito (ver 0012)
  UNIQUE (horario_id, alumno_id, fecha)   -- agregado en migración 0001; lo necesita el upsert de LlamarLista.vue

justificaciones         -- agregada en migración 0012
  id            uuid PK
  alumno_id     uuid FK -> alumnos.id ON DELETE CASCADE
  curso_id      uuid FK -> cursos.id  ON DELETE CASCADE   -- null = todos los cursos del alumno
  desde, hasta  date NOT NULL CHECK (hasta >= desde)
  motivo        text NOT NULL
  creado_por    uuid FK -> perfiles.id default auth.uid()
  created_at    timestamptz

tutores_alumnos         -- agregada en migración 0013 (portal de familias)
  id            uuid PK
  tutor_id      uuid FK -> perfiles.id ON DELETE CASCADE   -- perfil con rol 'tutor'
  alumno_id     uuid FK -> alumnos.id  ON DELETE CASCADE
  parentesco    text
  principal     boolean default false   -- el primero que se vincula; su teléfono va a alumnos.telefono_padre
  recibe_avisos boolean default true    -- reservado para notificaciones (Fase 4)
  created_at    timestamptz
  UNIQUE (tutor_id, alumno_id)

codigos_vinculacion     -- 0013: código de un solo uso que el admin le da a la familia
  codigo        text PK   -- 8 caracteres sin I/O/0/1
  alumno_id     uuid FK -> alumnos.id ON DELETE CASCADE
  creado_por    uuid FK -> perfiles.id
  created_at, expira_at (14 días), usado_por, usado_at

intentos_vinculacion    -- 0013: para limitar canjes fallidos (10 por hora); sin políticas, solo la usa vincular_tutor()

solicitudes_justificacion  -- 0014: aviso de ausencia / pedido de justificación de la familia
  id            uuid PK
  alumno_id     uuid FK -> alumnos.id ON DELETE CASCADE
  curso_id      uuid FK -> cursos.id   -- null = todos sus cursos (solo la resuelve admin)
  desde, hasta  date (máx. 60 días de rango; ±60 días de hoy al crearla)
  motivo        text (3–500)
  adjunto_path  text   -- objeto en el bucket privado `certificados`, ruta <alumno_id>/<id>.<ext>
  estado        text CHECK IN ('pendiente','aprobada','rechazada','cancelada')
  respuesta     text   -- de la institución (obligatoria al rechazar)
  creada_por    uuid FK -> perfiles.id default auth.uid()
  created_at, revisada_por, revisada_at
  justificacion_id uuid  -- la justificación que creó al aprobarse (sin FK)

comunicados             -- 0015: cuaderno de comunicaciones
  id, titulo (3–150), cuerpo (≤5000)
  tipo          text CHECK IN ('aviso','autorizacion','encuesta','citacion')
  audiencia     text: 'institucion' | 'curso' (curso_id) | 'alumno' (alumno_id)
  opciones      jsonb  -- null para aviso; array de 2 a 6 textos para el resto
  fecha_limite  date   -- para responder (opcional)
  autor_id      uuid FK -> perfiles.id default auth.uid()
  autor_nombre  text   -- firma ('Administración' o nombre del docente), la pone un trigger
  created_at

comunicados_destinatarios  -- 0015: una fila por tutor × hijo destinatario
  id, comunicado_id (ON DELETE CASCADE), tutor_id, alumno_id
  leido_at, respuesta, respondido_at   -- acuse de lectura y "firma"
  UNIQUE (comunicado_id, tutor_id, alumno_id)

notificaciones          -- 0016: bandeja de cada usuario (campanita), en Realtime
  id, perfil_id (FK perfiles), tipo ('falta','solicitud','comunicado','resumen','sistema')
  titulo, cuerpo, link, clave (UNIQUE con perfil_id, evita repetidas), created_at, leida_at

avisos_enviados         -- 0016: registro de avisos a familias por WhatsApp
  id, alumno_id, canal ('whatsapp'), motivo ('asistencia','alerta','comunicado','codigo'), enviado_por, created_at

suscripciones_push      -- 0016: dispositivos para push (los usa 0017)
  id, perfil_id, endpoint UNIQUE, p256dh, auth, user_agent, created_at

seguimientos            -- 0018: bitácora interna de contactos con la familia
  id, alumno_id, tipo ('llamada','whatsapp','entrevista','nota'), descripcion, compromiso,
  proxima_revision date, autor_id, autor_nombre (trigger), created_at

franjas_entrevista      -- 0018: horarios que publica un docente o admin
  id, profesional_id (default auth.uid()), profesional_nombre (trigger), inicio timestamptz,
  duracion_min (10–120), modalidad ('presencial','videollamada','telefono'), lugar,
  reservada boolean (la mantiene un trigger), UNIQUE (profesional_id, inicio)

reservas_entrevista     -- 0018: una por franja (franja_id UNIQUE)
  id, franja_id, tutor_id, alumno_id, motivo, tutor_nombre, tutor_telefono, created_at

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

No hay tabla de "matrícula por año/período". Desde 0012 una inscripción se **da de baja** (`activa = false`, `fecha_baja`, `motivo_baja`) en vez de borrarse: el alumno deja de aparecer al tomar lista (`LlamarLista.vue` trae los activos y los dados de baja después de la fecha elegida), en "Alumnos" y en los contadores, pero su asistencia sigue en los reportes de los meses en que cursó (`resumen_asistencia_por_alumno` devuelve `activa`/`fecha_baja`). `alumnos_en_riesgo` ignora las bajas. Solo se borra la fila (`desinscribir`) si la inscripción fue un error y no tiene asistencia.

`justificaciones` (0012) cubre faltas por rango de fechas (certificado médico, permiso). Tres triggers `SECURITY DEFINER` la mantienen sincronizada con `asistencia`:
- `trg_justificacion_al_crear` (AFTER INSERT): las faltas `ausente` ya cargadas en el rango pasan a `justificado` con `justificacion_id`.
- `trg_asistencia_aplicar_justificacion` (BEFORE INSERT/UPDATE en `asistencia`): una falta cargada después dentro del rango se justifica sola. Si el docente la marca `presente`, se suelta el enlace.
- `trg_justificacion_al_anular` (AFTER DELETE): las asistencias que justificó vuelven a `ausente` (o a otra justificación vigente que las cubra). Por eso `asistencia.justificacion_id` no tiene FK: un `on delete set null` borraría el enlace antes de que este trigger lo use.
No hay UPDATE de justificaciones: para corregir una se anula y se carga de nuevo.

## Alta de usuarios: todo pasa por un trigger, no por el frontend

`RegistroUsuarios.vue` llama a `supabase.auth.signUp({ email, password, options: { data: {...} } })` con `nombre, apellido, ci, telefono, rol, especialidad` en `data`. El frontend **no** hace ningún `insert` en `perfiles`/`alumnos`/`profesores`.

Un trigger `on_auth_user_created` (`AFTER INSERT ON auth.users`) ejecuta `public.handle_new_user()` (`SECURITY DEFINER`), que:
1. Lee `rol`, `nombre`, `apellido`, `ci`, `telefono`, `especialidad` de `raw_user_meta_data` (con defaults razonables si faltan — `rol` default `'estudiante'`, `ci` genera un placeholder `PENDIENTE-XXXXXXXX` si no vino).
2. Inserta la fila en `perfiles` (`id = auth.users.id`).
3. Si `rol = 'estudiante'`, inserta en `alumnos`. Si `rol = 'docente'`, inserta en `profesores` y el perfil queda con `activo = false` hasta que un admin lo apruebe (desde 0013). Si `rol = 'tutor'`, solo crea el perfil y, si vino `codigo_vinculacion` en la metadata, lo canjea (un código inválido no impide crear la cuenta).
4. **Desde 0013 solo acepta `estudiante`, `docente` y `tutor`**; cualquier otro valor (incluido `admin`) queda como `estudiante`. Antes de 0013 cualquiera podía crearse una cuenta admin llamando a `signUp` con `rol: 'admin'`. Admin se promueve a mano, ver más abajo.

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
| `tutor_de_alumno(alumno_id)` | (0013) `true` si el tutor logueado (activo) está vinculado a ese alumno |
| `tutor_ve_curso(curso_id)` | (0013) `true` si algún hijo del tutor logueado está inscripto en ese curso |

Desde 0013, `is_admin()`, `current_profesor_id()` y `current_alumno_id()` dan `false`/`null` si `perfiles.activo` es `false`: una cuenta inactiva no ve nada.

**Regla para el futuro**: si agregás o cambiás una policy y necesitás consultar OTRA tabla protegida por RLS (no `perfiles`/`alumnos`/`profesores` vía las funciones que ya existen), escribí una función `SECURITY DEFINER` nueva en vez de un subquery `exists (select ... from esa_tabla ...)` directo en el `using`/`with_check`. Si dos tablas terminan consultándose una a la otra (aunque sea indirectamente, a través de una tercera), va a recursionar.

Resumen de políticas por tabla (todas restringidas a `authenticated`, no `public`):

- **perfiles**: SELECT/UPDATE solo la fila propia, o cualquiera si `is_admin()`. Un trigger separado (`prevent_self_privilege_escalation`, `BEFORE UPDATE`) revierte silenciosamente cualquier cambio a `rol`/`activo` que no venga de un admin — así que aunque la policy de UPDATE no filtre por columna, no hay forma de auto-ascender a admin.
- **alumnos**: SELECT propio / admin / `docente_tiene_alumno(id)`. UPDATE propio o admin. INSERT/DELETE solo admin.
- **profesores**: SELECT/UPDATE propio o admin. INSERT/DELETE solo admin.
- **cursos**: SELECT cualquier `authenticated` (no es dato sensible). INSERT/UPDATE/DELETE solo admin.
- **horarios**: SELECT admin / el docente dueño (`profesor_id = current_profesor_id()`) / `alumno_inscripto_en_curso(curso_id)`. Escritura solo admin (no hay UI todavía para que un docente cree sus propios horarios).
- **inscripciones**: SELECT admin / el alumno propio / `docente_dicta_curso(curso_id)`. Escritura solo admin.
- **asistencia**: SELECT admin / alumno propio / docente dueño del horario. INSERT/UPDATE/DELETE: docente dueño del horario, o admin.
- **justificaciones** (0012): SELECT admin / alumno propio / `docente_tiene_alumno(alumno_id)`. INSERT con `creado_por = auth.uid()` y (admin, o docente con `curso_id` no nulo de un curso que dicta y un alumno suyo). DELETE admin o quien la creó. Sin UPDATE.
- **Tutor (0013)**: las políticas SELECT de `alumnos`, `inscripciones`, `asistencia` y `justificaciones` suman `tutor_de_alumno(alumno_id)`, y la de `horarios` suma `tutor_ve_curso(curso_id)`. El tutor no escribe en ninguna de esas tablas.
- **tutores_alumnos** (0013): SELECT el propio tutor / admin / `docente_tiene_alumno(alumno_id)`. INSERT/UPDATE solo admin (la familia se vincula con la RPC `vincular_tutor`). DELETE admin o el propio tutor.
- **codigos_vinculacion** (0013): SELECT/DELETE solo admin; se crean con la RPC `generar_codigo_vinculacion` (verifica `is_admin()`).
- **alumnos, columnas protegidas** (0013): el trigger `trg_proteger_columnas_alumno` revierte cambios a `perfil_id`, `ci`, `nombre`, `apellido`, `telefono_padre` e `historial_academico` cuando el UPDATE viene de la API (`current_user = 'authenticated'`) y no es admin. Las funciones `SECURITY DEFINER` y el SQL Editor sí pueden.
- **solicitudes_justificacion** (0014): SELECT admin / `tutor_de_alumno` / `docente_tiene_alumno`. INSERT solo el tutor del alumno, en estado `pendiente`, con curso en el que esté inscripto (`inscripcion_activa`) o null, y adjunto dentro de la carpeta del alumno. UPDATE solo para cancelar una pendiente propia (el trigger `trg_solicitud_solo_cancelar` rechaza cambios a otras columnas). Se aprueba/rechaza con la RPC `resolver_solicitud(id, aprobar, respuesta)` (`SECURITY DEFINER`): admin, o docente que dicta ese curso; al aprobar inserta en `justificaciones` y los triggers de 0012 hacen el resto.
- **storage.objects, bucket `certificados`** (0014, privado, 5 MB, PDF/JPG/PNG/WEBP): INSERT el tutor del alumno de la carpeta (`alumno_de_ruta(name)`); SELECT admin / tutor / docente del alumno. Se leen con URLs firmadas de 5 minutos.
- **comunicados** (0015): SELECT admin / autor / destinatario (`es_destinatario_comunicado`). INSERT con `autor_id = auth.uid()` y admin, o docente con `audiencia = 'curso'` de un curso que dicta o `'alumno'` de un alumno suyo. DELETE admin o autor. Sin UPDATE. Triggers: `trg_comunicado_firmar` (firma), `trg_comunicado_destinatarios` (calcula destinatarios con `tutores_alumnos` + inscripciones activas) y, en `tutores_alumnos`, `trg_comunicados_para_tutor_nuevo` (le agrega lo de los últimos 30 días no vencido).
- **comunicados_destinatarios** (0015): SELECT el propio tutor / admin / autor (`es_autor_comunicado`). Sin INSERT/UPDATE/DELETE por la API: la familia usa `marcar_comunicado_leido(comunicado_id)` y `responder_comunicado(destinatario_id, respuesta)` (valida que la respuesta esté en `opciones` y que no haya vencido `fecha_limite`). Quien publica usa `comunicados_enviados()` y `destinatarios_de_comunicado(id)` (nombres y teléfonos de las familias, para recordatorios).
- **notificaciones** (0016): SELECT/DELETE solo las propias. Sin INSERT por la API: las crean los triggers `trg_notificar_falta` (asistencia → familias con `recibe_avisos`; si la falta se corrige, se borra la no leída), `trg_notificar_solicitud` (aviso nuevo → docentes del curso o admins; resuelto → la familia) y `trg_notificar_comunicado`. Se marcan leídas con `marcar_notificaciones_leidas(ids)`. Publicada en `supabase_realtime`.
- **avisos_enviados** (0016): SELECT/INSERT admin o docente del alumno. **suscripciones_push**: todo solo sobre las propias. La familia cambia `tutores_alumnos.recibe_avisos` con `configurar_avisos(vinculo, recibe)`.
- **Push y email** (0017, opcional, ver `docs/NOTIFICACIONES.md`): `pg_net` + `pg_cron`; `_llamar_edge_function()` lee la URL y el secreto de Vault (`edugest_functions_url`, `edugest_webhook_secret`); `resumen_semanal_familias()` solo para `service_role`.
- **seguimientos** (0018): SELECT/INSERT admin o docente del alumno (`autor_id = auth.uid()`); DELETE autor o admin. La familia no la ve.
- **franjas_entrevista** (0018): SELECT el propio profesional / admin / familia de un alumno de ese docente o cualquier familia si es de un admin (`tutor_ve_profesional`). INSERT docente o admin, a futuro. DELETE propio o admin (avisa a la familia si estaba reservada).
- **reservas_entrevista** (0018): SELECT la familia que reservó / el profesional (`es_profesional_de_franja`) / admin. Sin escritura por la API: `reservar_entrevista(franja, alumno, motivo)` y `cancelar_entrevista(reserva)`, que notifican a la otra parte.
- **Alertas tempranas** (0018): `revisar_alertas_tempranas()` corre todos los días a las 11:00 UTC con `pg_cron` (job `edugest-alertas-tempranas`): 3+ faltas seguidas → familia; 5+ sin seguimiento en 7 días → docentes del curso y admins; revisión pactada para hoy → autor; entrevistas de mañana → ambas partes. Se puede correr a mano: `select public.revisar_alertas_tempranas();`. La zona horaria de los textos sale de `zona_horaria_institucion()`.
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
6. `0006_import_alumnos_1ro_3ro_bti.sql` — importación de "(1º) Primer Curso-BTI" y "(3º) Tercer Curso-BTI" con sus alumnos reales (fuentes: `1RO BTI.csv`, `3RO BTI.csv`), mismo patrón que 0003. Idempotente por `ci` (no duplica alumnos ya migrados) y por horario (no duplica franjas).
7. `0007_import_alumnos_7mo_a_3ro_bc_bts.sql` — crea 7 cursos nuevos ("(7º) Séptimo Curso", "(8º) Octavo Curso", "(9º) Noveno Curso", "(1º)/(2º)/(3º) Curso-BC", "(1º) Curso-BTS") con horario y 168 alumnos reales. A diferencia de 0006, los cursos no existían — esta migración los crea, así que **no es idempotente para cursos/horarios** (correrla dos veces los duplicaría); sí lo es para alumnos/inscripciones. Quedaron 4 alumnos sin `ci` en las planillas originales, excluidos de este import (ver comentario en el archivo).

8. `0008_reportes.sql` — funciones `resumen_asistencia_por_fecha`, `asistencia_mensual_curso` y `resumen_asistencia_por_alumno` (agregan en Postgres en vez de traer cada fila al navegador; PostgREST corta en 1000 filas). Las usan "Reporte mensual" y "Resumen por fecha". `SECURITY INVOKER`: RLS filtra igual que en cualquier consulta. Si no está aplicada, "Resumen por fecha" cae a sumar en el navegador y "Reporte mensual" muestra un aviso.
9. `0009_gestion_cursos.sql` — función `admin_crear_alumno(...)` (`SECURITY DEFINER`, verifica `is_admin()`; crea cuenta + perfil + alumno con contraseña **aleatoria**, para el alta de alumnos desde `/admin/cursos/:id`) e índice único `horarios (curso_id, dia_semana, hora_inicio)`. Si ya hay horarios duplicados, el índice no se crea y la migración avisa con un `NOTICE` (al final del archivo está la consulta para encontrarlos).
10. `0010_seguridad_cuentas_alumnos.sql` — reemplaza la contraseña fija `Prueba123!` de las cuentas `<ci>@alumno.ccg.local` creadas por 0003/0006/0007 por una aleatoria. Ver `docs/AUDITORIA_2026-08.md`, hallazgo 15. **Leer el encabezado antes de correrla**: si algún alumno real usa esas cuentas, deja de poder entrar.
11. `0011_alertas_inasistencia.sql` — función `alumnos_en_riesgo(desde, hasta, umbral_pct, faltas_seguidas, minimo_clases)` para el panel "Alumnos en riesgo" de admin y docente. `SECURITY INVOKER`.
12. `0012_justificaciones_y_bajas.sql` — bajas de inscripción (`inscripciones.activa/fecha_baja/motivo_baja`), tabla `justificaciones` con RLS y triggers, `asistencia.justificacion_id`; redefine `resumen_asistencia_por_alumno` (agrega `activa`, `fecha_baja`) y `alumnos_en_riesgo` (sin bajas). **Va después de 0008 y 0011.** Sin ella la app funciona igual: justificaciones y bajas muestran un aviso y todo lo demás cae a la consulta sin las columnas nuevas.

13. `0013_portal_familias.sql` — rol `tutor`, `tutores_alumnos`, `codigos_vinculacion`, RPCs `generar_codigo_vinculacion`, `vincular_tutor` y `tutores_de_alumno`, cláusulas de lectura del tutor en las políticas, sincronización del teléfono del tutor principal con `alumnos.telefono_padre`; además endurece `handle_new_user` (sin alta de admin, docentes pendientes de aprobación), hace efectivo `perfiles.activo` y protege columnas de `alumnos`. **Va después de 0012.**
14. `0014_solicitudes_justificacion.sql` — tabla `solicitudes_justificacion`, RPC `resolver_solicitud`, bucket privado `certificados` con sus políticas en `storage.objects`. **Va después de 0013.**
15. `0015_comunicados.sql` — tablas `comunicados` y `comunicados_destinatarios`, triggers de firma y destinatarios, RPCs de lectura/respuesta y de seguimiento. **Va después de 0013.**
16. `0016_notificaciones.sql` — notificaciones en la app (triggers + Realtime), preferencia de avisos, `avisos_enviados`, `suscripciones_push`. **Va después de 0015.**
17. `0017_push_y_email.sql` — push y resumen semanal por email. **Correrla solo después de seguir `docs/NOTIFICACIONES.md`.**
18. `0018_seguimiento_y_entrevistas.sql` — bitácora de seguimiento, agenda de entrevistas, alertas tempranas diarias (`pg_cron`) y `patrones_ausentismo`. **Va después de 0016.** Se puede aplicar sin 0017.

1, 2 y 3 ya están aplicadas en el proyecto de Supabase de este equipo (confirmado en la auditoría de 2026-08 y en la verificación de la importación). 4 a 12 son posteriores — verificar en la base cuáles ya se pegaron en el SQL Editor (por ejemplo `select proname from pg_proc where proname in ('resumen_asistencia_por_fecha','admin_crear_alumno','alumnos_en_riesgo');`). Si conectás este repo a un proyecto de Supabase nuevo (otro ambiente, staging, etc.), corré todas en orden antes de usar la app.

`horarios.dia_semana`: la restricción original acepta `'Miercoles'` sin tilde (es lo que insertaron las importaciones). La UI de administración guarda los días con esa grafía (`DIAS_SEMANA` en `src/lib/api/admin.js`) y los muestra con tilde; para comparar días se usa siempre `indiceDia()` de `src/lib/dias.js`, que ignora tildes.

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
