-- =========================================================================
-- Migración: notificaciones push y resumen semanal por email
-- Sistema de Asistencia — EduGest
--
-- ANTES DE CORRERLA seguí docs/NOTIFICACIONES.md: hay que publicar las Edge
-- Functions `enviar-push` y `resumen-semanal`, cargar sus secretos y guardar
-- en Vault la URL de las funciones y el secreto compartido. Sin eso esta
-- migración no rompe nada: las llamadas simplemente no se hacen.
--
-- CÓMO EJECUTAR:
--   SQL Editor -> pegar TODO -> Run. Idempotente. Depende de 0016.
--
-- QUÉ HACE:
--   1. Activa pg_net (llamadas HTTP desde la base) y pg_cron (tareas
--      programadas).
--   2. Cada notificación nueva de un usuario con algún dispositivo
--      suscripto llama a la Edge Function enviar-push.
--   3. Todos los viernes a las 20:00 UTC (17:00 en Paraguay/Argentina)
--      llama a resumen-semanal, que arma el resumen de la semana de cada
--      familia (notificación + email).
-- =========================================================================

begin;

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- Llama a una Edge Function con el secreto compartido. Lee la URL base y el
-- secreto de Vault; si no están cargados, no hace nada.
create or replace function public._llamar_edge_function(p_funcion text, p_cuerpo jsonb)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_url text;
  v_secreto text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'edugest_functions_url';
  select decrypted_secret into v_secreto from vault.decrypted_secrets where name = 'edugest_webhook_secret';
  if v_url is null or v_secreto is null then
    return;
  end if;
  perform net.http_post(
    url := rtrim(v_url, '/') || '/' || p_funcion,
    body := p_cuerpo,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-edugest-secret', v_secreto
    ),
    timeout_milliseconds := 5000
  );
end;
$$;

revoke execute on function public._llamar_edge_function(text, jsonb) from anon, authenticated, public;

-- -------------------------------------------------------------------------
-- Push: cada notificación nueva (solo si el usuario tiene dispositivos)
-- -------------------------------------------------------------------------

create or replace function public.notificacion_a_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.suscripciones_push where perfil_id = new.perfil_id) then
    perform public._llamar_edge_function('enviar-push', jsonb_build_object('notificacion_id', new.id));
  end if;
  return null;
end;
$$;

revoke execute on function public.notificacion_a_push() from anon, authenticated, public;

drop trigger if exists trg_notificacion_a_push on public.notificaciones;
create trigger trg_notificacion_a_push
after insert on public.notificaciones
for each row execute function public.notificacion_a_push();

-- -------------------------------------------------------------------------
-- Resumen semanal: datos para la Edge Function (solo service_role)
-- -------------------------------------------------------------------------

create or replace function public.resumen_semanal_familias(p_desde date, p_hasta date)
returns table (
  tutor_id uuid,
  email text,
  tutor_nombre text,
  alumno_id uuid,
  alumno_nombre text,
  total bigint,
  presentes bigint,
  ausentes bigint,
  justificados bigint
)
language sql
security definer
stable
set search_path = public
as $$
  with dias as (
    select
      a.alumno_id,
      h.curso_id,
      a.fecha,
      case
        when bool_or(a.estado = 'ausente') then 'ausente'
        when bool_or(a.estado = 'justificado') then 'justificado'
        when bool_or(a.estado = 'tarde') then 'tarde'
        else 'presente'
      end as estado
    from public.asistencia a
    join public.horarios h on h.id = a.horario_id
    where a.fecha between p_desde and p_hasta
    group by a.alumno_id, h.curso_id, a.fecha
  )
  select
    ta.tutor_id,
    u.email::text,
    p.nombre::text,
    al.id,
    (al.nombre || ' ' || al.apellido)::text,
    count(d.fecha),
    count(d.fecha) filter (where d.estado in ('presente', 'tarde')),
    count(d.fecha) filter (where d.estado = 'ausente'),
    count(d.fecha) filter (where d.estado = 'justificado')
  from public.tutores_alumnos ta
  join public.perfiles p on p.id = ta.tutor_id and p.activo is not false
  join auth.users u on u.id = ta.tutor_id
  join public.alumnos al on al.id = ta.alumno_id
  left join dias d on d.alumno_id = ta.alumno_id
  group by ta.tutor_id, u.email, p.nombre, al.id, al.nombre, al.apellido
  order by ta.tutor_id, al.nombre;
$$;

revoke execute on function public.resumen_semanal_familias(date, date) from anon, authenticated, public;
grant execute on function public.resumen_semanal_familias(date, date) to service_role;

-- -------------------------------------------------------------------------
-- Tarea programada (pg_cron, hora UTC)
-- -------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from cron.job where jobname = 'edugest-resumen-semanal') then
    perform cron.unschedule('edugest-resumen-semanal');
  end if;
  perform cron.schedule(
    'edugest-resumen-semanal',
    '0 20 * * 5',
    $cron$ select public._llamar_edge_function('resumen-semanal', '{}'::jsonb) $cron$
  );
end $$;

commit;
