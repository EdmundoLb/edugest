-- =========================================================================
-- Migración: solicitudes de justificación de la familia
-- Sistema de Asistencia — EduGest
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Una sola transacción. Idempotente. Depende de 0012
--   (justificaciones) y 0013 (tutor_de_alumno).
--
-- QUÉ HACE:
--   La familia (rol tutor) avisa una ausencia o pide justificar faltas por
--   rango de fechas, con un certificado opcional (PDF o foto). Puede ser un
--   aviso anticipado ("mañana tiene turno médico"): el docente lo ve al
--   tomar lista. Admin, o el docente del curso, la aprueba o la rechaza con
--   resolver_solicitud(): al aprobarla se crea la fila en `justificaciones`
--   y los triggers de 0012 pasan las faltas del rango a 'justificado' (no se
--   repite esa lógica acá).
--
--   - solicitudes_justificacion: la solicitud, con estado pendiente /
--     aprobada / rechazada / cancelada.
--   - Bucket privado `certificados` (5 MB, PDF/JPG/PNG/WEBP). Ruta
--     obligatoria: <alumno_id>/<archivo>. Lo sube el tutor del alumno; lo
--     leen el tutor, el admin y los docentes del alumno.
--
-- QUIÉN PUEDE APROBAR (igual que la policy de INSERT de justificaciones):
--   - admin: cualquiera;
--   - docente: solo si la solicitud es de un curso que dicta. Las que valen
--     para "todos los cursos" (curso_id null) las resuelve administración.
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Helpers
-- -------------------------------------------------------------------------

-- Primer segmento de una ruta de Storage como uuid (null si no lo es), para
-- no romper una policy con un cast inválido.
create or replace function public.alumno_de_ruta(p_ruta text)
returns uuid
language sql
immutable
set search_path = public
as $$
  select case
    when split_part(p_ruta, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_ruta, '/', 1)::uuid
  end;
$$;

create or replace function public.inscripcion_activa(p_alumno_id uuid, p_curso_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.inscripciones
    where alumno_id = p_alumno_id and curso_id = p_curso_id and activa
  );
$$;

grant execute on function public.alumno_de_ruta(text) to authenticated;
grant execute on function public.inscripcion_activa(uuid, uuid) to authenticated;
revoke execute on function public.inscripcion_activa(uuid, uuid) from anon, public;

-- -------------------------------------------------------------------------
-- 2) Tabla
-- -------------------------------------------------------------------------

create table if not exists public.solicitudes_justificacion (
  id               uuid primary key default gen_random_uuid(),
  alumno_id        uuid not null references public.alumnos (id) on delete cascade,
  curso_id         uuid references public.cursos (id) on delete cascade, -- null = todos sus cursos
  desde            date not null,
  hasta            date not null,
  motivo           text not null,
  adjunto_path     text,
  estado           text not null default 'pendiente',
  respuesta        text,
  creada_por       uuid not null default auth.uid() references public.perfiles (id) on delete cascade,
  created_at       timestamptz not null default now(),
  revisada_por     uuid references public.perfiles (id) on delete set null,
  revisada_at      timestamptz,
  justificacion_id uuid, -- la que creó al aprobarse (sin FK: se puede anular aparte)
  constraint solicitudes_estado check (estado in ('pendiente', 'aprobada', 'rechazada', 'cancelada')),
  constraint solicitudes_rango check (hasta >= desde and hasta - desde <= 60),
  constraint solicitudes_motivo check (length(trim(motivo)) between 3 and 500)
);

create index if not exists solicitudes_alumno_idx
  on public.solicitudes_justificacion (alumno_id, desde, hasta);
create index if not exists solicitudes_pendientes_idx
  on public.solicitudes_justificacion (created_at) where estado = 'pendiente';

alter table public.solicitudes_justificacion enable row level security;
revoke all on public.solicitudes_justificacion from anon;

drop policy if exists "solicitudes_select_scoped" on public.solicitudes_justificacion;
drop policy if exists "solicitudes_insert_tutor" on public.solicitudes_justificacion;
drop policy if exists "solicitudes_update_cancelar" on public.solicitudes_justificacion;

create policy "solicitudes_select_scoped"
on public.solicitudes_justificacion for select
to authenticated
using (
  public.is_admin()
  or public.tutor_de_alumno(alumno_id)
  or public.docente_tiene_alumno(alumno_id)
);

-- La familia crea solicitudes pendientes de sus hijos, para un curso en el
-- que el alumno está inscripto (o para todos), no más de 60 días hacia
-- atrás ni hacia adelante, y con el adjunto en la carpeta del alumno.
create policy "solicitudes_insert_tutor"
on public.solicitudes_justificacion for insert
to authenticated
with check (
  creada_por = auth.uid()
  and estado = 'pendiente'
  and respuesta is null
  and revisada_por is null
  and justificacion_id is null
  and public.tutor_de_alumno(alumno_id)
  and (curso_id is null or public.inscripcion_activa(alumno_id, curso_id))
  and desde >= current_date - 60
  and hasta <= current_date + 60
  and (adjunto_path is null or public.alumno_de_ruta(adjunto_path) = alumno_id)
);

-- Lo único que se actualiza por la API es cancelar una pendiente propia; el
-- trigger de abajo impide tocar cualquier otra columna.
create policy "solicitudes_update_cancelar"
on public.solicitudes_justificacion for update
to authenticated
using (creada_por = auth.uid() and estado = 'pendiente')
with check (creada_por = auth.uid() and estado = 'cancelada');

create or replace function public.solicitud_solo_cancelar()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if (new.alumno_id, new.curso_id, new.desde, new.hasta, new.motivo, new.adjunto_path,
        new.respuesta, new.creada_por, new.revisada_por, new.revisada_at, new.justificacion_id)
       is distinct from
       (old.alumno_id, old.curso_id, old.desde, old.hasta, old.motivo, old.adjunto_path,
        old.respuesta, old.creada_por, old.revisada_por, old.revisada_at, old.justificacion_id)
    then
      raise exception 'Solo se puede cancelar la solicitud' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_solicitud_solo_cancelar on public.solicitudes_justificacion;
create trigger trg_solicitud_solo_cancelar
before update on public.solicitudes_justificacion
for each row execute function public.solicitud_solo_cancelar();

-- -------------------------------------------------------------------------
-- 3) Aprobar / rechazar
-- -------------------------------------------------------------------------

create or replace function public.resolver_solicitud(
  p_id uuid,
  p_aprobar boolean,
  p_respuesta text default null
)
returns public.solicitudes_justificacion
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.solicitudes_justificacion;
  v_justificacion_id uuid;
begin
  select * into s from public.solicitudes_justificacion where id = p_id for update;

  if s.id is null then
    raise exception 'La solicitud no existe' using errcode = '22023';
  end if;

  if not (
    public.is_admin()
    or (
      s.curso_id is not null
      and public.docente_dicta_curso(s.curso_id)
      and public.docente_tiene_alumno(s.alumno_id)
    )
  ) then
    raise exception 'No podés resolver esta solicitud (las de todos los cursos las resuelve administración)'
      using errcode = '42501';
  end if;

  if s.estado <> 'pendiente' then
    raise exception 'La solicitud ya fue %', s.estado using errcode = '22023';
  end if;

  if not p_aprobar and nullif(trim(p_respuesta), '') is null then
    raise exception 'Para rechazar hay que indicar el motivo' using errcode = '22023';
  end if;

  if p_aprobar then
    insert into public.justificaciones (alumno_id, curso_id, desde, hasta, motivo, creado_por)
    values (s.alumno_id, s.curso_id, s.desde, s.hasta, 'Familia: ' || trim(s.motivo), auth.uid())
    returning id into v_justificacion_id;
  end if;

  update public.solicitudes_justificacion
  set estado = case when p_aprobar then 'aprobada' else 'rechazada' end,
      respuesta = nullif(trim(p_respuesta), ''),
      revisada_por = auth.uid(),
      revisada_at = now(),
      justificacion_id = v_justificacion_id
  where id = p_id
  returning * into s;

  return s;
end;
$$;

revoke execute on function public.resolver_solicitud(uuid, boolean, text) from anon, public;
grant execute on function public.resolver_solicitud(uuid, boolean, text) to authenticated;
revoke execute on function public.solicitud_solo_cancelar() from anon, authenticated, public;

-- -------------------------------------------------------------------------
-- 4) Storage: bucket privado de certificados
-- -------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'certificados', 'certificados', false, 5242880,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "certificados_insert_tutor" on storage.objects;
drop policy if exists "certificados_select_scoped" on storage.objects;

create policy "certificados_insert_tutor"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'certificados'
  and public.tutor_de_alumno(public.alumno_de_ruta(name))
);

create policy "certificados_select_scoped"
on storage.objects for select
to authenticated
using (
  bucket_id = 'certificados'
  and (
    public.is_admin()
    or public.tutor_de_alumno(public.alumno_de_ruta(name))
    or public.docente_tiene_alumno(public.alumno_de_ruta(name))
  )
);

commit;

-- =========================================================================
-- Verificación (solo lectura):
--   select jsonb_pretty(jsonb_build_object(
--     'tabla', exists (select 1 from information_schema.tables where table_name = 'solicitudes_justificacion'),
--     'resolver', exists (select 1 from pg_proc where proname = 'resolver_solicitud'),
--     'bucket', (select to_jsonb(b) from storage.buckets b where id = 'certificados'),
--     'politicas_storage', (select jsonb_agg(policyname) from pg_policies where schemaname = 'storage')
--   )) as resultado;
-- =========================================================================
