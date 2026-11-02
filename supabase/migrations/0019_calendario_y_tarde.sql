-- =========================================================================
-- Migración: calendario escolar y llegada tarde
-- Sistema de Asistencia — EduGest
--
-- CÓMO EJECUTAR:
--   SQL Editor -> pegar TODO -> Run. Una sola transacción. Idempotente.
--   Depende de 0012 (redefine las funciones de reportes que dejó 0012).
--
-- QUÉ HACE:
--   1. asistencia.estado acepta 'tarde' (llegó tarde). Cuenta como PRESENTE
--      en todos los porcentajes; solo se muestra distinto. Si un curso tiene
--      dos horarios el mismo día, el día se combina con prioridad
--      ausente > justificado > tarde > presente.
--   2. calendario_escolar: feriados, días sin clases (vacaciones, jornada
--      institucional), eventos y exámenes, para toda la institución o un
--      curso. Lo ve cualquier usuario logueado; lo edita admin (todo) o el
--      docente (solo eventos/exámenes de sus cursos).
--   3. Los días marcados como feriado o sin clases NO cuentan en los
--      reportes ni en las alertas aunque alguien haya tomado lista por error.
--   4. Redefine (misma firma y mismo tipo de retorno, así que no hace falta
--      tocar el frontend): resumen_asistencia_por_fecha,
--      asistencia_mensual_curso, resumen_asistencia_por_alumno y
--      alumnos_en_riesgo.
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Estado 'tarde'
-- -------------------------------------------------------------------------

alter table public.asistencia drop constraint if exists asistencia_estado_check;
alter table public.asistencia
  add constraint asistencia_estado_check
  check (estado in ('presente', 'ausente', 'justificado', 'tarde'));

-- -------------------------------------------------------------------------
-- 2) Calendario escolar
-- -------------------------------------------------------------------------

create table if not exists public.calendario_escolar (
  id          uuid primary key default gen_random_uuid(),
  desde       date not null,
  hasta       date not null,
  tipo        text not null,
  titulo      text not null,
  curso_id    uuid references public.cursos (id) on delete cascade, -- null = toda la institución
  creado_por  uuid default auth.uid() references public.perfiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint calendario_tipo check (tipo in ('feriado', 'sin_clases', 'evento', 'examen')),
  constraint calendario_rango check (hasta >= desde and hasta - desde <= 120),
  constraint calendario_titulo check (length(trim(titulo)) between 2 and 150)
);

create index if not exists calendario_fechas_idx on public.calendario_escolar (desde, hasta);

alter table public.calendario_escolar enable row level security;
revoke all on public.calendario_escolar from anon;

drop policy if exists "calendario_select_autenticados" on public.calendario_escolar;
drop policy if exists "calendario_insert_staff" on public.calendario_escolar;
drop policy if exists "calendario_delete_staff" on public.calendario_escolar;

create policy "calendario_select_autenticados"
on public.calendario_escolar for select
to authenticated
using (true);

-- Admin: todo. Docente: eventos y exámenes de un curso que dicta (un feriado
-- o un día sin clases afecta los reportes, lo decide administración).
create policy "calendario_insert_staff"
on public.calendario_escolar for insert
to authenticated
with check (
  creado_por = auth.uid()
  and (
    public.is_admin()
    or (
      tipo in ('evento', 'examen')
      and curso_id is not null
      and public.docente_dicta_curso(curso_id)
    )
  )
);

create policy "calendario_delete_staff"
on public.calendario_escolar for delete
to authenticated
using (public.is_admin() or (creado_por = auth.uid() and public.docente_dicta_curso(curso_id)));

-- true si ese día no hay clases para ese curso (feriado o sin clases).
create or replace function public.dia_sin_clases(p_fecha date, p_curso_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1 from public.calendario_escolar ce
    where ce.tipo in ('feriado', 'sin_clases')
      and p_fecha between ce.desde and ce.hasta
      and (ce.curso_id is null or ce.curso_id = p_curso_id)
  );
$$;

grant execute on function public.dia_sin_clases(date, uuid) to authenticated;

-- -------------------------------------------------------------------------
-- 3) Reportes: 'tarde' cuenta como presente y se ignoran los días sin clases
-- -------------------------------------------------------------------------

create or replace function public.resumen_asistencia_por_fecha(
  p_desde date,
  p_hasta date,
  p_curso_id uuid default null
)
returns table (
  curso_id uuid,
  curso_nombre text,
  fecha date,
  total bigint,
  presentes bigint,
  ausentes bigint,
  justificados bigint
)
language sql
stable
set search_path = public
as $$
  select
    c.id,
    c.nombre::text,
    a.fecha,
    count(*),
    count(*) filter (where a.estado in ('presente', 'tarde')),
    count(*) filter (where a.estado = 'ausente'),
    count(*) filter (where a.estado = 'justificado')
  from public.asistencia a
  join public.horarios h on h.id = a.horario_id
  join public.cursos c on c.id = h.curso_id
  where a.fecha between p_desde and p_hasta
    and (p_curso_id is null or c.id = p_curso_id)
    and not public.dia_sin_clases(a.fecha, c.id)
  group by c.id, c.nombre, a.fecha
  order by c.nombre, a.fecha desc;
$$;

create or replace function public.asistencia_mensual_curso(
  p_curso_id uuid,
  p_desde date,
  p_hasta date
)
returns table (
  alumno_id uuid,
  fecha date,
  estado text,
  observacion text
)
language sql
stable
set search_path = public
as $$
  select
    a.alumno_id,
    a.fecha,
    case
      when bool_or(a.estado = 'ausente') then 'ausente'
      when bool_or(a.estado = 'justificado') then 'justificado'
      when bool_or(a.estado = 'tarde') then 'tarde'
      else 'presente'
    end,
    string_agg(nullif(trim(a.observacion), ''), ' / ')
  from public.asistencia a
  join public.horarios h on h.id = a.horario_id
  where h.curso_id = p_curso_id
    and a.fecha between p_desde and p_hasta
    and not public.dia_sin_clases(a.fecha, p_curso_id)
  group by a.alumno_id, a.fecha
  order by a.fecha, a.alumno_id;
$$;

-- Igual que en 0012, contando 'tarde' como presente.
create or replace function public.resumen_asistencia_por_alumno(
  p_curso_id uuid,
  p_desde date,
  p_hasta date
)
returns table (
  alumno_id uuid,
  nombre text,
  apellido text,
  ci text,
  total bigint,
  presentes bigint,
  ausentes bigint,
  justificados bigint,
  porcentaje numeric,
  activa boolean,
  fecha_baja date
)
language sql
stable
set search_path = public
as $$
  with dias as (
    select * from public.asistencia_mensual_curso(p_curso_id, p_desde, p_hasta)
  )
  select
    al.id,
    al.nombre::text,
    al.apellido::text,
    al.ci::text,
    count(d.fecha),
    count(d.fecha) filter (where d.estado in ('presente', 'tarde')),
    count(d.fecha) filter (where d.estado = 'ausente'),
    count(d.fecha) filter (where d.estado = 'justificado'),
    round(
      100.0 * count(d.fecha) filter (where d.estado in ('presente', 'tarde'))
      / nullif(count(d.fecha) - count(d.fecha) filter (where d.estado = 'justificado'), 0),
      1
    ),
    i.activa,
    i.fecha_baja
  from public.inscripciones i
  join public.alumnos al on al.id = i.alumno_id
  left join dias d on d.alumno_id = al.id
  where i.curso_id = p_curso_id
  group by al.id, al.nombre, al.apellido, al.ci, i.activa, i.fecha_baja
  having i.activa
      or i.fecha_baja >= p_desde
      or count(d.fecha) > 0
  order by al.apellido, al.nombre;
$$;

create or replace function public.alumnos_en_riesgo(
  p_desde date,
  p_hasta date,
  p_umbral_pct numeric default 75,
  p_faltas_seguidas integer default 3,
  p_minimo_clases integer default 3
)
returns table (
  alumno_id uuid,
  nombre text,
  apellido text,
  telefono_padre text,
  curso_id uuid,
  curso_nombre text,
  total bigint,
  presentes bigint,
  ausentes bigint,
  justificados bigint,
  porcentaje numeric,
  faltas_seguidas bigint,
  ultima_falta date
)
language sql
stable
set search_path = public
as $$
  with dias as (
    select
      h.curso_id,
      a.alumno_id,
      a.fecha,
      case
        when bool_or(a.estado = 'ausente') then 'ausente'
        when bool_or(a.estado = 'justificado') then 'justificado'
        when bool_or(a.estado = 'tarde') then 'tarde'
        else 'presente'
      end as estado
    from public.asistencia a
    join public.horarios h on h.id = a.horario_id
    where a.fecha <= p_hasta
      and not public.dia_sin_clases(a.fecha, h.curso_id)
    group by h.curso_id, a.alumno_id, a.fecha
  ),
  marcados as (
    select
      d.curso_id,
      d.alumno_id,
      d.fecha,
      sum(case when d.estado <> 'ausente' then 1 else 0 end)
        over (partition by d.curso_id, d.alumno_id order by d.fecha desc) as cortes
    from dias d
  ),
  racha as (
    select m.curso_id, m.alumno_id, count(*) as seguidas, max(m.fecha) as ultima
    from marcados m
    where m.cortes = 0
    group by m.curso_id, m.alumno_id
  ),
  periodo as (
    select
      d.curso_id,
      d.alumno_id,
      count(*) as total,
      count(*) filter (where d.estado in ('presente', 'tarde')) as presentes,
      count(*) filter (where d.estado = 'ausente') as ausentes,
      count(*) filter (where d.estado = 'justificado') as justificados
    from dias d
    where d.fecha >= p_desde
    group by d.curso_id, d.alumno_id
  ),
  calculado as (
    select
      p.*,
      round(100.0 * p.presentes / nullif(p.total - p.justificados, 0), 1) as pct,
      coalesce(r.seguidas, 0) as seguidas,
      r.ultima
    from periodo p
    left join racha r on r.curso_id = p.curso_id and r.alumno_id = p.alumno_id
  )
  select
    al.id,
    al.nombre::text,
    al.apellido::text,
    al.telefono_padre::text,
    c.id,
    c.nombre::text,
    x.total,
    x.presentes,
    x.ausentes,
    x.justificados,
    x.pct,
    x.seguidas,
    x.ultima
  from calculado x
  join public.alumnos al on al.id = x.alumno_id
  join public.cursos c on c.id = x.curso_id
  where ((x.total >= p_minimo_clases and x.pct < p_umbral_pct)
     or x.seguidas >= p_faltas_seguidas)
    and not exists (
      select 1 from public.inscripciones i
      where i.alumno_id = x.alumno_id and i.curso_id = x.curso_id and not i.activa
    )
  order by x.seguidas desc, x.pct asc nulls last, al.apellido, al.nombre;
$$;

commit;
