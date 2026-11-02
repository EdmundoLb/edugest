-- =========================================================================
-- Migración: seguimiento de alumnos en riesgo y agenda de entrevistas
-- Sistema de Asistencia — EduGest
--
-- CÓMO EJECUTAR:
--   SQL Editor -> pegar TODO -> Run. Una sola transacción. Idempotente.
--   Depende de 0011 (alumnos_en_riesgo), 0013 y 0016 (notificaciones).
--
-- QUÉ HACE:
--   1. seguimientos: bitácora interna (familia no la ve) de lo que se hizo
--      con un alumno: llamada, WhatsApp, entrevista o nota, con el
--      compromiso acordado y la fecha para volver a revisar. Convierte la
--      alerta en un protocolo: detectar -> contactar -> acordar -> revisar.
--   2. Agenda de entrevistas: docentes y admin publican franjas
--      (franjas_entrevista); la familia reserva una para un hijo
--      (reservar_entrevista). Una reserva por franja. Notifica a la otra
--      parte al reservar o cancelar.
--   3. revisar_alertas_tempranas(): corre todos los días (pg_cron, 11:00
--      UTC = 8:00 en Paraguay/Argentina) y genera notificaciones (las
--      fechas usan zona_horaria_institucion(), America/Asuncion por defecto):
--        - 3+ faltas seguidas sin justificar -> a la familia;
--        - 5+ faltas seguidas y nadie registró un seguimiento en 7 días ->
--          a los docentes del curso y a administración;
--        - un seguimiento con fecha de revisión de hoy -> a quien lo cargó;
--        - entrevistas de mañana -> recordatorio a la familia y al docente.
--   4. patrones_ausentismo(desde, hasta): alumnos que faltan casi siempre
--      el mismo día de la semana (para el reporte institucional).
-- =========================================================================

begin;

create extension if not exists pg_cron;

-- Zona horaria de la institución: la usan las fechas y horas que se
-- escriben en las notificaciones y el "hoy" de las alertas. Cambiarla acá si
-- la institución está en otro país.
create or replace function public.zona_horaria_institucion()
returns text
language sql
immutable
as $$ select 'America/Asuncion'::text $$;

alter table public.notificaciones drop constraint if exists notificaciones_tipo;
alter table public.notificaciones
  add constraint notificaciones_tipo
  check (tipo in ('falta', 'solicitud', 'comunicado', 'resumen', 'sistema', 'seguimiento', 'entrevista'));

-- -------------------------------------------------------------------------
-- 1) Bitácora de seguimiento
-- -------------------------------------------------------------------------

create table if not exists public.seguimientos (
  id                uuid primary key default gen_random_uuid(),
  alumno_id         uuid not null references public.alumnos (id) on delete cascade,
  tipo              text not null,
  descripcion       text not null,
  compromiso        text,
  proxima_revision  date,
  autor_id          uuid not null default auth.uid() references public.perfiles (id) on delete cascade,
  autor_nombre      text,
  created_at        timestamptz not null default now(),
  constraint seguimientos_tipo check (tipo in ('llamada', 'whatsapp', 'entrevista', 'nota')),
  constraint seguimientos_descripcion check (length(trim(descripcion)) between 3 and 2000)
);

create index if not exists seguimientos_alumno_idx on public.seguimientos (alumno_id, created_at desc);

alter table public.seguimientos enable row level security;
revoke all on public.seguimientos from anon;

drop policy if exists "seguimientos_select_staff" on public.seguimientos;
drop policy if exists "seguimientos_insert_staff" on public.seguimientos;
drop policy if exists "seguimientos_delete_autor_o_admin" on public.seguimientos;

create policy "seguimientos_select_staff"
on public.seguimientos for select
to authenticated
using (public.is_admin() or public.docente_tiene_alumno(alumno_id));

create policy "seguimientos_insert_staff"
on public.seguimientos for insert
to authenticated
with check (
  autor_id = auth.uid()
  and (public.is_admin() or public.docente_tiene_alumno(alumno_id))
);

create policy "seguimientos_delete_autor_o_admin"
on public.seguimientos for delete
to authenticated
using (public.is_admin() or autor_id = auth.uid());

-- Firma visible (perfiles solo deja ver la fila propia).
create or replace function public.firmar_con_autor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select trim(p.nombre || ' ' || coalesce(p.apellido, '')) into new.autor_nombre
  from public.perfiles p where p.id = new.autor_id;
  return new;
end;
$$;

drop trigger if exists trg_seguimiento_firmar on public.seguimientos;
create trigger trg_seguimiento_firmar
before insert on public.seguimientos
for each row execute function public.firmar_con_autor();

-- -------------------------------------------------------------------------
-- 2) Agenda de entrevistas
-- -------------------------------------------------------------------------

create table if not exists public.franjas_entrevista (
  id                  uuid primary key default gen_random_uuid(),
  profesional_id      uuid not null default auth.uid() references public.perfiles (id) on delete cascade,
  profesional_nombre  text,
  inicio              timestamptz not null,
  duracion_min        integer not null default 20,
  modalidad           text not null default 'presencial',
  lugar               text,
  -- La familia no ve reservas ajenas: con esto sabe si el horario está libre.
  reservada           boolean not null default false,
  created_at          timestamptz not null default now(),
  constraint franjas_duracion check (duracion_min between 10 and 120),
  constraint franjas_modalidad check (modalidad in ('presencial', 'videollamada', 'telefono')),
  constraint franjas_unica unique (profesional_id, inicio)
);

create index if not exists franjas_inicio_idx on public.franjas_entrevista (inicio);

create table if not exists public.reservas_entrevista (
  id              uuid primary key default gen_random_uuid(),
  franja_id       uuid not null unique references public.franjas_entrevista (id) on delete cascade,
  tutor_id        uuid not null references public.perfiles (id) on delete cascade,
  alumno_id       uuid not null references public.alumnos (id) on delete cascade,
  motivo          text,
  tutor_nombre    text,
  tutor_telefono  text,
  created_at      timestamptz not null default now()
);

alter table public.franjas_entrevista enable row level security;
alter table public.reservas_entrevista enable row level security;
revoke all on public.franjas_entrevista from anon;
revoke all on public.reservas_entrevista from anon;

-- La familia ve las franjas de los docentes de sus hijos y las de
-- administración.
create or replace function public.tutor_ve_profesional(p_profesional_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select (
    exists (
      select 1 from public.perfiles p
      where p.id = p_profesional_id and p.rol = 'admin'
    )
    and exists (select 1 from public.tutores_alumnos where tutor_id = auth.uid())
  )
  or exists (
    select 1
    from public.tutores_alumnos ta
    join public.inscripciones i on i.alumno_id = ta.alumno_id and i.activa
    join public.horarios h on h.curso_id = i.curso_id
    join public.profesores pr on pr.id = h.profesor_id
    where ta.tutor_id = auth.uid() and pr.perfil_id = p_profesional_id
  );
$$;

create or replace function public.es_profesional_de_franja(p_franja_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.franjas_entrevista where id = p_franja_id and profesional_id = auth.uid()
  );
$$;

grant execute on function public.tutor_ve_profesional(uuid) to authenticated;
grant execute on function public.es_profesional_de_franja(uuid) to authenticated;
revoke execute on function public.tutor_ve_profesional(uuid) from anon, public;
revoke execute on function public.es_profesional_de_franja(uuid) from anon, public;

drop policy if exists "franjas_select_scoped" on public.franjas_entrevista;
drop policy if exists "franjas_insert_staff" on public.franjas_entrevista;
drop policy if exists "franjas_delete_propias" on public.franjas_entrevista;

create policy "franjas_select_scoped"
on public.franjas_entrevista for select
to authenticated
using (
  profesional_id = auth.uid()
  or public.is_admin()
  or public.tutor_ve_profesional(profesional_id)
);

create policy "franjas_insert_staff"
on public.franjas_entrevista for insert
to authenticated
with check (
  profesional_id = auth.uid()
  and inicio > now()
  and (public.is_admin() or public.current_profesor_id() is not null)
);

create policy "franjas_delete_propias"
on public.franjas_entrevista for delete
to authenticated
using (profesional_id = auth.uid() or public.is_admin());

drop policy if exists "reservas_select_scoped" on public.reservas_entrevista;
create policy "reservas_select_scoped"
on public.reservas_entrevista for select
to authenticated
using (
  tutor_id = auth.uid()
  or public.is_admin()
  or public.es_profesional_de_franja(franja_id)
);

drop trigger if exists trg_franja_firmar on public.franjas_entrevista;
create or replace function public.franja_firmar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select case when p.rol = 'admin' then 'Administración · ' else '' end
         || trim(p.nombre || ' ' || coalesce(p.apellido, ''))
    into new.profesional_nombre
  from public.perfiles p where p.id = new.profesional_id;
  return new;
end;
$$;

create trigger trg_franja_firmar
before insert on public.franjas_entrevista
for each row execute function public.franja_firmar();

create or replace function public.reservar_entrevista(p_franja_id uuid, p_alumno_id uuid, p_motivo text)
returns public.reservas_entrevista
language plpgsql
security definer
set search_path = public
as $$
declare
  f public.franjas_entrevista;
  r public.reservas_entrevista;
  v_alumno text;
begin
  if not public.tutor_de_alumno(p_alumno_id) then
    raise exception 'Solo podés pedir entrevistas por tus hijos' using errcode = '42501';
  end if;

  select * into f from public.franjas_entrevista where id = p_franja_id for update;
  if f.id is null or not public.tutor_ve_profesional(f.profesional_id) then
    raise exception 'Ese horario no está disponible' using errcode = '22023';
  end if;
  if f.inicio <= now() then
    raise exception 'Ese horario ya pasó' using errcode = '22023';
  end if;
  if exists (select 1 from public.reservas_entrevista where franja_id = p_franja_id) then
    raise exception 'Ese horario ya lo reservó otra familia' using errcode = '23505';
  end if;

  insert into public.reservas_entrevista (franja_id, tutor_id, alumno_id, motivo, tutor_nombre, tutor_telefono)
  select p_franja_id, auth.uid(), p_alumno_id, nullif(left(trim(p_motivo), 500), ''),
         trim(p.nombre || ' ' || coalesce(p.apellido, '')), p.telefono
  from public.perfiles p where p.id = auth.uid()
  returning * into r;

  select nombre || ' ' || apellido into v_alumno from public.alumnos where id = p_alumno_id;
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  values (
    f.profesional_id, 'entrevista',
    'Entrevista reservada: ' || v_alumno,
    to_char(f.inicio at time zone public.zona_horaria_institucion(), 'DD/MM HH24:MI') || ' · ' || coalesce(r.motivo, 'Sin motivo indicado'),
    '/entrevistas',
    'reserva:' || r.id
  )
  on conflict (perfil_id, clave) do nothing;

  return r;
end;
$$;

create or replace function public.franja_marcar_reservada()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.franjas_entrevista
  set reservada = (tg_op = 'INSERT')
  where id = coalesce(new.franja_id, old.franja_id);
  return null;
end;
$$;

drop trigger if exists trg_franja_marcar_reservada on public.reservas_entrevista;
create trigger trg_franja_marcar_reservada
after insert or delete on public.reservas_entrevista
for each row execute function public.franja_marcar_reservada();

-- Cancela la familia que reservó, o el profesional / admin.
create or replace function public.cancelar_entrevista(p_reserva_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.reservas_entrevista;
  f public.franjas_entrevista;
  v_alumno text;
  v_avisar uuid;
begin
  select * into r from public.reservas_entrevista where id = p_reserva_id for update;
  if r.id is null then
    raise exception 'La reserva no existe' using errcode = '22023';
  end if;
  select * into f from public.franjas_entrevista where id = r.franja_id;
  if not (r.tutor_id = auth.uid() or f.profesional_id = auth.uid() or public.is_admin()) then
    raise exception 'No podés cancelar esta entrevista' using errcode = '42501';
  end if;

  delete from public.reservas_entrevista where id = p_reserva_id;

  v_avisar := case when auth.uid() = r.tutor_id then f.profesional_id else r.tutor_id end;
  select nombre || ' ' || apellido into v_alumno from public.alumnos where id = r.alumno_id;
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  values (
    v_avisar, 'entrevista',
    'Entrevista cancelada: ' || v_alumno,
    to_char(f.inicio at time zone public.zona_horaria_institucion(), 'DD/MM HH24:MI'),
    case when v_avisar = r.tutor_id then '/familia/entrevistas' else '/entrevistas' end,
    'cancelada:' || r.id
  )
  on conflict (perfil_id, clave) do nothing;
end;
$$;

-- Si el docente borra una franja reservada, avisarle a la familia.
create or replace function public.franja_borrada_avisar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  select r.tutor_id, 'entrevista',
         'Entrevista cancelada: ' || a.nombre || ' ' || a.apellido,
         to_char(old.inicio at time zone public.zona_horaria_institucion(), 'DD/MM HH24:MI') || ' · ' ||
           coalesce(old.profesional_nombre, '') || ' canceló el horario. Podés reservar otro.',
         '/familia/entrevistas',
         'cancelada:' || r.id
  from public.reservas_entrevista r
  join public.alumnos a on a.id = r.alumno_id
  where r.franja_id = old.id
  on conflict (perfil_id, clave) do nothing;
  return old;
end;
$$;

drop trigger if exists trg_franja_borrada_avisar on public.franjas_entrevista;
create trigger trg_franja_borrada_avisar
before delete on public.franjas_entrevista
for each row execute function public.franja_borrada_avisar();

-- -------------------------------------------------------------------------
-- 3) Alertas tempranas automáticas (pg_cron diario)
-- -------------------------------------------------------------------------

create or replace function public.revisar_alertas_tempranas()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hoy date := (now() at time zone public.zona_horaria_institucion())::date;
  v_familias int := 0;
  v_escaladas int := 0;
  v_revisiones int := 0;
  v_recordatorios int := 0;
begin
  -- Corre como dueño (sin RLS): alumnos_en_riesgo ve todos los cursos.
  drop table if exists _riesgo;
  create temp table _riesgo on commit drop as
  select * from public.alumnos_en_riesgo(v_hoy - 30, v_hoy);

  -- 3+ faltas seguidas -> familia (una vez por racha: la clave lleva la última falta).
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  select ta.tutor_id, 'falta',
         r.nombre || ' lleva ' || r.faltas_seguidas || ' faltas seguidas',
         r.curso_nombre || '. Si hay un motivo, avisalo desde el portal o comunicate con la institución.',
         '/familia/hijo/' || r.alumno_id,
         'racha:' || r.alumno_id || ':' || r.curso_id || ':' || r.ultima_falta
  from _riesgo r
  join public.tutores_alumnos ta on ta.alumno_id = r.alumno_id
  join public.perfiles p on p.id = ta.tutor_id and p.activo is not false
  where r.faltas_seguidas >= 3
  on conflict (perfil_id, clave) do nothing;
  get diagnostics v_familias = row_count;

  -- 5+ faltas seguidas sin seguimiento en 7 días -> docentes del curso y admins.
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  select distinct p.id, 'seguimiento',
         'Sin seguimiento: ' || r.nombre || ' ' || r.apellido,
         r.faltas_seguidas || ' faltas seguidas en ' || r.curso_nombre ||
           ' y nadie registró un contacto con la familia en la última semana.',
         '/Estudiantes/' || r.alumno_id,
         'escalada:' || r.alumno_id || ':' || r.curso_id || ':' || r.ultima_falta
  from _riesgo r
  join public.perfiles p on p.activo is not false and (
    p.rol = 'admin'
    or exists (
      select 1 from public.horarios h join public.profesores pr on pr.id = h.profesor_id
      where h.curso_id = r.curso_id and pr.perfil_id = p.id
    )
  )
  where r.faltas_seguidas >= 5
    and not exists (
      select 1 from public.seguimientos s
      where s.alumno_id = r.alumno_id and s.created_at > now() - interval '7 days'
    )
  on conflict (perfil_id, clave) do nothing;
  get diagnostics v_escaladas = row_count;

  -- Seguimientos con revisión pactada para hoy -> a quien lo cargó.
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  select s.autor_id, 'seguimiento',
         'Revisar hoy: ' || a.nombre || ' ' || a.apellido,
         coalesce('Compromiso: ' || s.compromiso, left(s.descripcion, 140)),
         '/Estudiantes/' || s.alumno_id,
         'revision:' || s.id
  from public.seguimientos s
  join public.alumnos a on a.id = s.alumno_id
  where s.proxima_revision = v_hoy
  on conflict (perfil_id, clave) do nothing;
  get diagnostics v_revisiones = row_count;

  -- Entrevistas de mañana -> familia y profesional.
  insert into public.notificaciones (perfil_id, tipo, titulo, cuerpo, link, clave)
  select destino.perfil_id, 'entrevista',
         'Mañana: entrevista por ' || a.nombre || ' ' || a.apellido,
         to_char(f.inicio at time zone public.zona_horaria_institucion(), 'HH24:MI') || ' · ' ||
           case f.modalidad when 'presencial' then coalesce(f.lugar, 'presencial')
                            when 'videollamada' then 'videollamada' || coalesce(' · ' || f.lugar, '')
                            else 'por teléfono' end,
         destino.link,
         'recordatorio:' || r.id
  from public.reservas_entrevista r
  join public.franjas_entrevista f on f.id = r.franja_id
  join public.alumnos a on a.id = r.alumno_id
  cross join lateral (values (r.tutor_id, '/familia/entrevistas'), (f.profesional_id, '/entrevistas'))
    as destino (perfil_id, link)
  where (f.inicio at time zone public.zona_horaria_institucion())::date = v_hoy + 1
  on conflict (perfil_id, clave) do nothing;
  get diagnostics v_recordatorios = row_count;

  return jsonb_build_object(
    'familias', v_familias, 'escaladas', v_escaladas,
    'revisiones', v_revisiones, 'recordatorios', v_recordatorios
  );
end;
$$;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'edugest-alertas-tempranas') then
    perform cron.unschedule('edugest-alertas-tempranas');
  end if;
  perform cron.schedule(
    'edugest-alertas-tempranas',
    '0 11 * * *',
    $cron$ select public.revisar_alertas_tempranas() $cron$
  );
end $$;

-- -------------------------------------------------------------------------
-- 4) Patrones: faltas concentradas en un día de la semana
-- -------------------------------------------------------------------------

create or replace function public.patrones_ausentismo(p_desde date, p_hasta date)
returns table (
  alumno_id uuid,
  nombre text,
  apellido text,
  curso_id uuid,
  curso_nombre text,
  dia_semana int, -- 1 = lunes ... 5 = viernes (ISO)
  faltas_ese_dia bigint,
  faltas_total bigint
)
language sql
stable
set search_path = public
as $$
  with faltas as (
    select a.alumno_id, h.curso_id, a.fecha
    from public.asistencia a
    join public.horarios h on h.id = a.horario_id
    where a.estado = 'ausente' and a.fecha between p_desde and p_hasta
    group by a.alumno_id, h.curso_id, a.fecha
  ),
  por_dia as (
    select alumno_id, curso_id, extract(isodow from fecha)::int as dia, count(*) as n,
           sum(count(*)) over (partition by alumno_id, curso_id) as total
    from faltas
    group by alumno_id, curso_id, extract(isodow from fecha)
  )
  select d.alumno_id, al.nombre::text, al.apellido::text, d.curso_id, c.nombre::text,
         d.dia, d.n, d.total::bigint
  from por_dia d
  join public.alumnos al on al.id = d.alumno_id
  join public.cursos c on c.id = d.curso_id
  where d.total >= 3 and d.n >= 3 and d.n::numeric / d.total >= 0.6
  order by d.n desc, al.apellido;
$$;

revoke execute on function public.firmar_con_autor() from anon, authenticated, public;
revoke execute on function public.franja_firmar() from anon, authenticated, public;
revoke execute on function public.franja_borrada_avisar() from anon, authenticated, public;
revoke execute on function public.franja_marcar_reservada() from anon, authenticated, public;
revoke execute on function public.revisar_alertas_tempranas() from anon, authenticated, public;
revoke execute on function public.reservar_entrevista(uuid, uuid, text) from anon, public;
revoke execute on function public.cancelar_entrevista(uuid) from anon, public;
revoke execute on function public.patrones_ausentismo(date, date) from anon, public;
grant execute on function public.reservar_entrevista(uuid, uuid, text) to authenticated;
grant execute on function public.cancelar_entrevista(uuid) to authenticated;
grant execute on function public.patrones_ausentismo(date, date) to authenticated;

commit;
