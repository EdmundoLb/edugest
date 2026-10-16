-- =========================================================================
-- Migración: soporte para la gestión de cursos desde el panel de admin
-- Sistema de Asistencia — Centro Cultural Gymmart
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Es una sola transacción (BEGIN/COMMIT). Idempotente.
--
-- QUÉ HACE:
--   1. Función admin_crear_alumno(...): crea la cuenta + perfil + fila de
--      alumnos de un alumno nuevo, para poder dar de alta alumnos desde la UI
--      (antes solo se podía con migraciones de importación).
--   2. Índice único en horarios (curso_id, dia_semana, hora_inicio) para que
--      no se puedan cargar franjas repetidas. Si ya hay duplicados, NO se
--      crea y se avisa con un NOTICE (ver consulta al final para encontrarlos).
--
-- Cursos, horarios e inscripciones ya tienen políticas RLS de escritura solo
-- para admin (0001), así que la UI no necesita nada más para esas tablas.
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Alta de alumno desde el panel de admin
-- -------------------------------------------------------------------------
--
-- alumnos.perfil_id -> perfiles.id -> auth.users.id, así que un alumno
-- necesita una cuenta en auth.users aunque todavía no vaya a iniciar sesión.
-- Se crea con el mismo formato de email que las importaciones
-- (<ci>@alumno.ccg.local), pero con una contraseña ALEATORIA que nadie
-- conoce: la cuenta existe pero no se puede usar para entrar hasta que se
-- le asigne un acceso real (a diferencia de las importaciones 0003/0006/0007,
-- que usaron una contraseña fija — ver 0010_seguridad_cuentas_alumnos.sql).
--
-- El trigger handle_new_user (0001) crea perfiles + alumnos a partir de
-- raw_user_meta_data, igual que en el registro normal.
--
-- SECURITY DEFINER porque escribe en auth.users; por eso lo primero que hace
-- es verificar que quien llama sea admin.

create or replace function public.admin_crear_alumno(
  p_nombre text,
  p_apellido text,
  p_ci text,
  p_telefono text default null,
  p_telefono_padre text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ci text := nullif(trim(p_ci), '');
  v_user_id uuid;
  v_alumno_id uuid;
  v_email text;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede dar de alta alumnos'
      using errcode = '42501';
  end if;

  if v_ci is null or nullif(trim(p_nombre), '') is null or nullif(trim(p_apellido), '') is null then
    raise exception 'Nombre, apellido y CI son obligatorios'
      using errcode = '22023';
  end if;

  -- Si ya existe un alumno con esa CI, se devuelve ese (idempotente).
  select a.id into v_alumno_id from public.alumnos a where a.ci = v_ci;
  if v_alumno_id is not null then
    return v_alumno_id;
  end if;

  v_user_id := gen_random_uuid();
  v_email := lower(regexp_replace(v_ci, '[^0-9A-Za-z]', '', 'g')) || '@alumno.ccg.local';

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, email_change,
    email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
    v_email,
    crypt(encode(gen_random_bytes(32), 'base64'), gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'rol', 'estudiante',
      'nombre', trim(p_nombre),
      'apellido', trim(p_apellido),
      'ci', v_ci,
      'telefono', nullif(trim(p_telefono), '')
    ),
    now(), now(), '', '', '', ''
  );

  insert into auth.identities (
    id, provider_id, user_id, identity_data, provider, created_at, updated_at
  ) values (
    gen_random_uuid(), v_user_id::text, v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email),
    'email', now(), now()
  );

  select a.id into v_alumno_id from public.alumnos a where a.perfil_id = v_user_id;

  if v_alumno_id is null then
    raise exception 'No se creó la fila de alumno (revisar el trigger handle_new_user)';
  end if;

  if nullif(trim(p_telefono_padre), '') is not null then
    update public.alumnos set telefono_padre = trim(p_telefono_padre) where id = v_alumno_id;
  end if;

  return v_alumno_id;
end;
$$;

revoke execute on function public.admin_crear_alumno(text, text, text, text, text) from anon, public;
grant execute on function public.admin_crear_alumno(text, text, text, text, text) to authenticated;

-- -------------------------------------------------------------------------
-- 2) Horarios sin franjas duplicadas
-- -------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from public.horarios
    group by curso_id, dia_semana, hora_inicio
    having count(*) > 1
  ) then
    raise notice 'Hay horarios duplicados (mismo curso, día y hora de inicio). '
      'No se creó el índice único. Corré la consulta del final de este archivo para verlos.';
  else
    create unique index if not exists horarios_curso_dia_hora_key
      on public.horarios (curso_id, dia_semana, hora_inicio);
  end if;
end $$;

commit;

-- =========================================================================
-- Verificación (opcional, solo lectura):
--
-- ¿Se creó el índice?
--   select indexname from pg_indexes where indexname = 'horarios_curso_dia_hora_key';
--
-- Horarios duplicados (si el NOTICE de arriba apareció):
--   select c.nombre, h.dia_semana, h.hora_inicio, count(*) as cantidad,
--          array_agg(h.id) as horario_ids
--   from public.horarios h join public.cursos c on c.id = h.curso_id
--   group by c.nombre, h.dia_semana, h.hora_inicio
--   having count(*) > 1;
-- =========================================================================
