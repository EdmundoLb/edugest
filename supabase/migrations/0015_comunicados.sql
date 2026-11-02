-- =========================================================================
-- Migración: cuaderno de comunicaciones digital
-- Sistema de Asistencia — EduGest
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Una sola transacción. Idempotente. Depende de 0013
--   (tutores_alumnos, tutor_de_alumno).
--
-- QUÉ HACE:
--   Admin o docente manda un comunicado a las familias de toda la
--   institución, de un curso o de un alumno. Cada familia destinataria tiene
--   una fila en comunicados_destinatarios (una por hijo: una autorización se
--   firma por cada alumno) con acuse de lectura y, según el tipo, respuesta:
--     - aviso:        solo "leído".
--     - autorizacion: Autorizo / No autorizo (firma digital simple: quién y
--                     cuándo).
--     - encuesta:     opciones que define quien lo manda (2 a 6).
--     - citacion:     confirmar asistencia a una reunión.
--   Los destinatarios se calculan al publicar (trigger). Si una familia se
--   vincula después, recibe los comunicados de los últimos 30 días que
--   todavía no vencieron.
--
-- QUIÉN PUEDE PUBLICAR:
--   - admin: a cualquier audiencia;
--   - docente: a un curso que dicta o a un alumno suyo.
--   No hay UPDATE de comunicados (lo leído/firmado no debe cambiar): para
--   corregir, se borra y se publica de nuevo.
--
-- LECTURA Y RESPUESTA: solo con las RPC marcar_comunicado_leido() y
-- responder_comunicado(), que validan la opción y la fecha límite.
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Tablas
-- -------------------------------------------------------------------------

create table if not exists public.comunicados (
  id            uuid primary key default gen_random_uuid(),
  titulo        text not null,
  cuerpo        text not null,
  tipo          text not null default 'aviso',
  audiencia     text not null,
  curso_id      uuid references public.cursos (id) on delete cascade,
  alumno_id     uuid references public.alumnos (id) on delete cascade,
  opciones      jsonb,
  fecha_limite  date,
  autor_id      uuid not null default auth.uid() references public.perfiles (id) on delete cascade,
  autor_nombre  text, -- firma visible para la familia (la completa el trigger)
  created_at    timestamptz not null default now(),
  constraint comunicados_tipo check (tipo in ('aviso', 'autorizacion', 'encuesta', 'citacion')),
  constraint comunicados_audiencia check (
    (audiencia = 'institucion' and curso_id is null and alumno_id is null)
    or (audiencia = 'curso' and curso_id is not null and alumno_id is null)
    or (audiencia = 'alumno' and alumno_id is not null)
  ),
  constraint comunicados_titulo check (length(trim(titulo)) between 3 and 150),
  constraint comunicados_cuerpo check (length(trim(cuerpo)) between 1 and 5000),
  constraint comunicados_opciones check (
    (tipo = 'aviso' and opciones is null)
    or (
      tipo <> 'aviso'
      and jsonb_typeof(opciones) = 'array'
      and jsonb_array_length(opciones) between 2 and 6
    )
  )
);

create index if not exists comunicados_autor_idx on public.comunicados (autor_id, created_at desc);

create table if not exists public.comunicados_destinatarios (
  id             uuid primary key default gen_random_uuid(),
  comunicado_id  uuid not null references public.comunicados (id) on delete cascade,
  tutor_id       uuid not null references public.perfiles (id) on delete cascade,
  alumno_id      uuid not null references public.alumnos (id) on delete cascade,
  leido_at       timestamptz,
  respuesta      text,
  respondido_at  timestamptz,
  constraint comunicados_destinatarios_unico unique (comunicado_id, tutor_id, alumno_id)
);

create index if not exists comunicados_destinatarios_tutor_idx
  on public.comunicados_destinatarios (tutor_id, leido_at);

alter table public.comunicados enable row level security;
alter table public.comunicados_destinatarios enable row level security;
revoke all on public.comunicados from anon;
revoke all on public.comunicados_destinatarios from anon;

-- -------------------------------------------------------------------------
-- 2) Helpers SECURITY DEFINER (las policies de las dos tablas se cruzan)
-- -------------------------------------------------------------------------

create or replace function public.es_destinatario_comunicado(p_comunicado_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.comunicados_destinatarios
    where comunicado_id = p_comunicado_id and tutor_id = auth.uid()
  );
$$;

create or replace function public.es_autor_comunicado(p_comunicado_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.comunicados
    where id = p_comunicado_id and autor_id = auth.uid()
  );
$$;

grant execute on function public.es_destinatario_comunicado(uuid) to authenticated;
grant execute on function public.es_autor_comunicado(uuid) to authenticated;
revoke execute on function public.es_destinatario_comunicado(uuid) from anon, public;
revoke execute on function public.es_autor_comunicado(uuid) from anon, public;

-- -------------------------------------------------------------------------
-- 3) Políticas
-- -------------------------------------------------------------------------

drop policy if exists "comunicados_select_scoped" on public.comunicados;
drop policy if exists "comunicados_insert_staff" on public.comunicados;
drop policy if exists "comunicados_delete_autor_o_admin" on public.comunicados;

create policy "comunicados_select_scoped"
on public.comunicados for select
to authenticated
using (
  public.is_admin()
  or autor_id = auth.uid()
  or public.es_destinatario_comunicado(id)
);

create policy "comunicados_insert_staff"
on public.comunicados for insert
to authenticated
with check (
  autor_id = auth.uid()
  and (
    public.is_admin()
    or (audiencia = 'curso' and public.docente_dicta_curso(curso_id))
    or (audiencia = 'alumno' and public.docente_tiene_alumno(alumno_id))
  )
);

create policy "comunicados_delete_autor_o_admin"
on public.comunicados for delete
to authenticated
using (public.is_admin() or autor_id = auth.uid());

drop policy if exists "destinatarios_select_scoped" on public.comunicados_destinatarios;

create policy "destinatarios_select_scoped"
on public.comunicados_destinatarios for select
to authenticated
using (
  tutor_id = auth.uid()
  or public.is_admin()
  or public.es_autor_comunicado(comunicado_id)
);

-- -------------------------------------------------------------------------
-- 4) Firma y destinatarios al publicar
-- -------------------------------------------------------------------------

create or replace function public.comunicado_firmar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select case
           when p.rol = 'admin' then 'Administración'
           else trim(p.nombre || ' ' || coalesce(p.apellido, ''))
         end
    into new.autor_nombre
  from public.perfiles p
  where p.id = new.autor_id;
  return new;
end;
$$;

drop trigger if exists trg_comunicado_firmar on public.comunicados;
create trigger trg_comunicado_firmar
before insert on public.comunicados
for each row execute function public.comunicado_firmar();

create or replace function public.comunicado_destinatarios_al_publicar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.comunicados_destinatarios (comunicado_id, tutor_id, alumno_id)
  select distinct new.id, ta.tutor_id, ta.alumno_id
  from public.tutores_alumnos ta
  join public.perfiles p on p.id = ta.tutor_id and p.activo is not false
  where case new.audiencia
    when 'alumno' then ta.alumno_id = new.alumno_id
    when 'curso' then exists (
      select 1 from public.inscripciones i
      where i.alumno_id = ta.alumno_id and i.curso_id = new.curso_id and i.activa
    )
    else exists (
      select 1 from public.inscripciones i
      where i.alumno_id = ta.alumno_id and i.activa
    )
  end
  on conflict do nothing;
  return null;
end;
$$;

drop trigger if exists trg_comunicado_destinatarios on public.comunicados;
create trigger trg_comunicado_destinatarios
after insert on public.comunicados
for each row execute function public.comunicado_destinatarios_al_publicar();

-- Familia que se vincula después: recibe lo reciente que le corresponde.
create or replace function public.comunicados_para_tutor_nuevo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.comunicados_destinatarios (comunicado_id, tutor_id, alumno_id)
  select c.id, new.tutor_id, new.alumno_id
  from public.comunicados c
  where c.created_at > now() - interval '30 days'
    and (c.fecha_limite is null or c.fecha_limite >= current_date)
    and case c.audiencia
      when 'alumno' then c.alumno_id = new.alumno_id
      when 'curso' then exists (
        select 1 from public.inscripciones i
        where i.alumno_id = new.alumno_id and i.curso_id = c.curso_id and i.activa
      )
      else exists (
        select 1 from public.inscripciones i
        where i.alumno_id = new.alumno_id and i.activa
      )
    end
  on conflict do nothing;
  return null;
end;
$$;

drop trigger if exists trg_comunicados_para_tutor_nuevo on public.tutores_alumnos;
create trigger trg_comunicados_para_tutor_nuevo
after insert on public.tutores_alumnos
for each row execute function public.comunicados_para_tutor_nuevo();

-- -------------------------------------------------------------------------
-- 5) RPC de la familia
-- -------------------------------------------------------------------------

-- Marca leídas todas las filas del tutor para ese comunicado (una por hijo).
create or replace function public.marcar_comunicado_leido(p_comunicado_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.comunicados_destinatarios
  set leido_at = now()
  where comunicado_id = p_comunicado_id
    and tutor_id = auth.uid()
    and leido_at is null;
$$;

create or replace function public.responder_comunicado(p_destinatario_id uuid, p_respuesta text)
returns public.comunicados_destinatarios
language plpgsql
security definer
set search_path = public
as $$
declare
  d public.comunicados_destinatarios;
  c public.comunicados;
begin
  select * into d from public.comunicados_destinatarios
  where id = p_destinatario_id and tutor_id = auth.uid()
  for update;
  if d.id is null then
    raise exception 'No encontramos ese comunicado' using errcode = '42501';
  end if;

  select * into c from public.comunicados where id = d.comunicado_id;
  if c.tipo = 'aviso' then
    raise exception 'Este comunicado no lleva respuesta' using errcode = '22023';
  end if;
  if c.fecha_limite is not null and c.fecha_limite < current_date then
    raise exception 'Venció el plazo para responder' using errcode = '22023';
  end if;
  if p_respuesta is null or not (c.opciones ? p_respuesta) then
    raise exception 'Respuesta no válida' using errcode = '22023';
  end if;

  update public.comunicados_destinatarios
  set respuesta = p_respuesta,
      respondido_at = now(),
      leido_at = coalesce(leido_at, now())
  where id = d.id
  returning * into d;
  return d;
end;
$$;

-- -------------------------------------------------------------------------
-- 6) RPC de quien publica
-- -------------------------------------------------------------------------

-- Comunicados enviados con su avance (el admin ve todos; el docente, los suyos).
create or replace function public.comunicados_enviados()
returns table (
  id uuid,
  titulo text,
  tipo text,
  audiencia text,
  curso_nombre text,
  alumno_nombre text,
  autor_nombre text,
  fecha_limite date,
  created_at timestamptz,
  destinatarios bigint,
  leidos bigint,
  respondidos bigint
)
language sql
security definer
stable
set search_path = public
as $$
  select
    c.id, c.titulo, c.tipo, c.audiencia,
    cu.nombre::text,
    (a.nombre || ' ' || a.apellido)::text,
    c.autor_nombre, c.fecha_limite, c.created_at,
    count(d.id),
    count(d.leido_at),
    count(d.respondido_at)
  from public.comunicados c
  left join public.cursos cu on cu.id = c.curso_id
  left join public.alumnos a on a.id = c.alumno_id
  left join public.comunicados_destinatarios d on d.comunicado_id = c.id
  where public.is_admin() or c.autor_id = auth.uid()
  group by c.id, cu.nombre, a.nombre, a.apellido
  order by c.created_at desc
  limit 200;
$$;

-- Detalle por familia (con teléfono para mandar un recordatorio).
create or replace function public.destinatarios_de_comunicado(p_comunicado_id uuid)
returns table (
  id uuid,
  tutor_nombre text,
  telefono text,
  alumno_nombre text,
  leido_at timestamptz,
  respuesta text,
  respondido_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    d.id,
    trim(p.nombre || ' ' || coalesce(p.apellido, ''))::text,
    p.telefono::text,
    (a.nombre || ' ' || a.apellido)::text,
    d.leido_at, d.respuesta, d.respondido_at
  from public.comunicados_destinatarios d
  join public.perfiles p on p.id = d.tutor_id
  join public.alumnos a on a.id = d.alumno_id
  where d.comunicado_id = p_comunicado_id
    and (public.is_admin() or public.es_autor_comunicado(p_comunicado_id))
  order by a.apellido, a.nombre, p.nombre;
$$;

revoke execute on function public.comunicado_firmar() from anon, authenticated, public;
revoke execute on function public.comunicado_destinatarios_al_publicar() from anon, authenticated, public;
revoke execute on function public.comunicados_para_tutor_nuevo() from anon, authenticated, public;
revoke execute on function public.marcar_comunicado_leido(uuid) from anon, public;
revoke execute on function public.responder_comunicado(uuid, text) from anon, public;
revoke execute on function public.comunicados_enviados() from anon, public;
revoke execute on function public.destinatarios_de_comunicado(uuid) from anon, public;
grant execute on function public.marcar_comunicado_leido(uuid) to authenticated;
grant execute on function public.responder_comunicado(uuid, text) to authenticated;
grant execute on function public.comunicados_enviados() to authenticated;
grant execute on function public.destinatarios_de_comunicado(uuid) to authenticated;

commit;
