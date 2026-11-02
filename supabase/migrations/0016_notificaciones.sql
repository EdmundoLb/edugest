-- =========================================================================
-- Migración: notificaciones dentro de la app
-- Sistema de Asistencia — EduGest
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Una sola transacción. Idempotente. Depende de 0013,
--   0014 y 0015.
--
-- QUÉ HACE:
--   1. notificaciones: bandeja por usuario (la campanita de la navbar). Las
--      generan triggers, nunca el navegador:
--        - falta registrada  -> familias del alumno con recibe_avisos (si el
--          docente la corrige a presente, la notificación sin leer se borra);
--        - aviso de la familia nuevo -> docentes del curso (o admins si es
--          para todos los cursos);
--        - aviso aprobado/rechazado -> la familia que lo mandó;
--        - comunicado nuevo  -> cada familia destinataria (una sola vez
--          aunque tenga dos hijos).
--      Se publica en Realtime: la campanita se actualiza sin recargar.
--   2. configurar_avisos(vinculo, recibe): la familia elige si quiere
--      enterarse de cada falta de cada hijo (tutores_alumnos.recibe_avisos).
--   3. avisos_enviados: registro de los avisos que el personal manda por
--      WhatsApp (antes no quedaba constancia de a quién se avisó).
--   4. suscripciones_push: dispositivos de cada usuario para las
--      notificaciones push. Se usan recién cuando se active
--      0017_push_y_email.sql (ver docs/NOTIFICACIONES.md).
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Notificaciones
-- -------------------------------------------------------------------------

create table if not exists public.notificaciones (
  id          uuid primary key default gen_random_uuid(),
  perfil_id   uuid not null references public.perfiles (id) on delete cascade,
  tipo        text not null,
  titulo      text not null,
  cuerpo      text,
  link        text,
  clave       text, -- para no repetir la misma notificación
  created_at  timestamptz not null default now(),
  leida_at    timestamptz,
  constraint notificaciones_tipo check (tipo in ('falta', 'solicitud', 'comunicado', 'resumen', 'sistema')),
  constraint notificaciones_clave unique (perfil_id, clave)
);

create index if not exists notificaciones_perfil_idx
  on public.notificaciones (perfil_id, created_at desc);

alter table public.notificaciones enable row level security;
revoke all on public.notificaciones from anon;

drop policy if exists "notificaciones_select_propias" on public.notificaciones;
drop policy if exists "notificaciones_delete_propias" on public.notificaciones;

create policy "notificaciones_select_propias"
on public.notificaciones for select
to authenticated
using (perfil_id = auth.uid());

create policy "notificaciones_delete_propias"
on public.notificaciones for delete
to authenticated
using (perfil_id = auth.uid());

create or replace function public.marcar_notificaciones_leidas(p_ids uuid[] default null)
returns void
language sql
security definer
set search_path = public
as $$
  update public.notificaciones
  set leida_at = now()
  where perfil_id = auth.uid()
    and leida_at is null
    and (p_ids is null or id = any (p_ids));
$$;

-- Realtime (la policy de SELECT decide quién recibe cada evento).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notificaciones'
  ) then
    alter publication supabase_realtime add table public.notificaciones;
  end if;
end $$;

-- -------------------------------------------------------------------------
-- 2) Triggers que generan notificaciones
-- -------------------------------------------------------------------------

create or replace function public.notificar_falta()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alumno text;
  v_curso text;
begin
  if new.estado = 'ausente' and (tg_op = 'INSERT' or old.estado is distinct from 'ausente') then
    select a.nombre || ' ' || a.apellido into v_alumno from public.alumnos a where a.id = new.alumno_id;
    select c.nombre into v_curso
    from public.horarios h join public.cursos c on c.id = h.curso_id
    where h.id = new.horario_id;

    insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
    select ta.tutor_id, 'falta',
           'Falta registrada: ' || v_alumno,
           coalesce(v_curso, 'Clase') || ' · ' || to_char(new.fecha, 'DD/MM/YYYY') ||
             '. Si tiene un motivo, podés avisarlo desde el portal.',
           '/familia/hijo/' || new.alumno_id,
           'falta:' || new.id
    from public.tutores_alumnos ta
    join public.perfiles p on p.id = ta.tutor_id and p.activo is not false
    where ta.alumno_id = new.alumno_id and ta.recibe_avisos
    on conflict (perfil_id, clave) do nothing;

  elsif tg_op = 'UPDATE' and old.estado = 'ausente' and new.estado <> 'ausente' then
    -- El docente corrigió la lista (o se justificó): si todavía no la vieron, se retira.
    delete from public.notificaciones
    where clave = 'falta:' || new.id and leida_at is null;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_notificar_falta on public.asistencia;
create trigger trg_notificar_falta
after insert or update of estado on public.asistencia
for each row execute function public.notificar_falta();

create or replace function public.notificar_solicitud()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alumno text;
begin
  select a.nombre || ' ' || a.apellido into v_alumno from public.alumnos a where a.id = new.alumno_id;

  if tg_op = 'INSERT' then
    insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
    select distinct p.id, 'solicitud',
           'Aviso de la familia: ' || v_alumno,
           left(new.motivo, 140),
           '/solicitudes',
           'solicitud:' || new.id
    from public.perfiles p
    where p.activo is not false
      and (
        (new.curso_id is null and p.rol = 'admin')
        or (
          new.curso_id is not null and exists (
            select 1 from public.horarios h join public.profesores pr on pr.id = h.profesor_id
            where h.curso_id = new.curso_id and pr.perfil_id = p.id
          )
        )
      )
    on conflict (perfil_id, clave) do nothing;

  elsif new.estado in ('aprobada', 'rechazada') and old.estado = 'pendiente' then
    insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
    values (
      new.creada_por, 'solicitud',
      case when new.estado = 'aprobada'
        then 'Aviso aprobado: ' || v_alumno
        else 'Aviso rechazado: ' || v_alumno end,
      coalesce(new.respuesta, case when new.estado = 'aprobada'
        then 'Las faltas de esas fechas quedan justificadas.' end),
      '/familia/hijo/' || new.alumno_id,
      'solicitud-resuelta:' || new.id
    )
    on conflict (perfil_id, clave) do nothing;

    -- Ya no hace falta que el personal la vea como pendiente.
    delete from public.notificaciones where clave = 'solicitud:' || new.id and leida_at is null;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_notificar_solicitud on public.solicitudes_justificacion;
create trigger trg_notificar_solicitud
after insert or update of estado on public.solicitudes_justificacion
for each row execute function public.notificar_solicitud();

create or replace function public.notificar_comunicado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  select new.tutor_id, 'comunicado', c.titulo,
         coalesce(c.autor_nombre, 'EduGest') || ' te envió un comunicado.',
         '/familia/comunicados',
         'comunicado:' || c.id
  from public.comunicados c
  where c.id = new.comunicado_id
  on conflict (perfil_id, clave) do nothing;
  return null;
end;
$$;

drop trigger if exists trg_notificar_comunicado on public.comunicados_destinatarios;
create trigger trg_notificar_comunicado
after insert on public.comunicados_destinatarios
for each row execute function public.notificar_comunicado();

-- -------------------------------------------------------------------------
-- 3) Preferencia de avisos de la familia
-- -------------------------------------------------------------------------

create or replace function public.configurar_avisos(p_vinculo_id uuid, p_recibe boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.tutores_alumnos
  set recibe_avisos = p_recibe
  where id = p_vinculo_id and tutor_id = auth.uid();
  if not found then
    raise exception 'No encontramos ese vínculo' using errcode = '42501';
  end if;
end;
$$;

-- -------------------------------------------------------------------------
-- 4) Registro de avisos enviados por WhatsApp
-- -------------------------------------------------------------------------

create table if not exists public.avisos_enviados (
  id          uuid primary key default gen_random_uuid(),
  alumno_id   uuid not null references public.alumnos (id) on delete cascade,
  canal       text not null default 'whatsapp',
  motivo      text not null,
  enviado_por uuid not null default auth.uid() references public.perfiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint avisos_enviados_motivo check (motivo in ('asistencia', 'alerta', 'comunicado', 'codigo'))
);

create index if not exists avisos_enviados_alumno_idx
  on public.avisos_enviados (alumno_id, created_at desc);

alter table public.avisos_enviados enable row level security;
revoke all on public.avisos_enviados from anon;

drop policy if exists "avisos_enviados_select_staff" on public.avisos_enviados;
drop policy if exists "avisos_enviados_insert_staff" on public.avisos_enviados;

create policy "avisos_enviados_select_staff"
on public.avisos_enviados for select
to authenticated
using (public.is_admin() or public.docente_tiene_alumno(alumno_id));

create policy "avisos_enviados_insert_staff"
on public.avisos_enviados for insert
to authenticated
with check (
  enviado_por = auth.uid()
  and (public.is_admin() or public.docente_tiene_alumno(alumno_id))
);

-- -------------------------------------------------------------------------
-- 5) Dispositivos para notificaciones push (se usan con 0017)
-- -------------------------------------------------------------------------

create table if not exists public.suscripciones_push (
  id          uuid primary key default gen_random_uuid(),
  perfil_id   uuid not null default auth.uid() references public.perfiles (id) on delete cascade,
  endpoint    text not null unique,
  p256dh      text not null,
  auth        text not null,
  user_agent  text,
  created_at  timestamptz not null default now()
);

alter table public.suscripciones_push enable row level security;
revoke all on public.suscripciones_push from anon;

drop policy if exists "suscripciones_push_propias" on public.suscripciones_push;
create policy "suscripciones_push_propias"
on public.suscripciones_push for all
to authenticated
using (perfil_id = auth.uid())
with check (perfil_id = auth.uid());

revoke execute on function public.notificar_falta() from anon, authenticated, public;
revoke execute on function public.notificar_solicitud() from anon, authenticated, public;
revoke execute on function public.notificar_comunicado() from anon, authenticated, public;
revoke execute on function public.marcar_notificaciones_leidas(uuid[]) from anon, public;
revoke execute on function public.configurar_avisos(uuid, boolean) from anon, public;
grant execute on function public.marcar_notificaciones_leidas(uuid[]) to authenticated;
grant execute on function public.configurar_avisos(uuid, boolean) to authenticated;

commit;
