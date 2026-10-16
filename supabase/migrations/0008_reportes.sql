-- =========================================================================
-- Migración: funciones de reportes de asistencia (agregación en la base)
-- Sistema de Asistencia — Centro Cultural Gymmart
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Es una sola transacción (BEGIN/COMMIT).
--   Depende de 0004 (asistencia.estado). Es idempotente (create or replace).
--
-- POR QUÉ:
--   Los reportes traían cada fila de `asistencia` al navegador y sumaban ahí.
--   PostgREST corta en 1000 filas por consulta, así que con ~200 alumnos los
--   totales quedaban mal en pocas semanas. Estas funciones agregan en
--   Postgres y devuelven pocas filas.
--
-- SEGURIDAD:
--   Son SECURITY INVOKER (el default): se ejecutan con los permisos de quien
--   llama, así que las políticas RLS de asistencia/horarios/cursos/alumnos
--   siguen filtrando igual que en una consulta normal. Un docente solo ve sus
--   cursos, un admin ve todo, un estudiante solo lo suyo. No hace falta
--   ninguna policy nueva.
--
-- QUÉ CREA:
--   1. resumen_asistencia_por_fecha(desde, hasta, curso?)
--        -> una fila por curso+fecha con totales (para "Reportes").
--   2. asistencia_mensual_curso(curso, desde, hasta)
--        -> una fila por alumno+fecha (para la grilla del reporte mensual).
--           Si un curso tiene dos horarios el mismo día, se combina en un
--           solo estado: ausente > justificado > presente.
--   3. resumen_asistencia_por_alumno(curso, desde, hasta)
--        -> totales y porcentaje por alumno inscripto en el curso.
--
-- Regla del porcentaje (la misma que ya usa el frontend):
--   presentes / (total - justificados). Las faltas justificadas no cuentan.
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Totales por curso y fecha
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
    count(*) filter (where a.estado = 'presente'),
    count(*) filter (where a.estado = 'ausente'),
    count(*) filter (where a.estado = 'justificado')
  from public.asistencia a
  join public.horarios h on h.id = a.horario_id
  join public.cursos c on c.id = h.curso_id
  where a.fecha between p_desde and p_hasta
    and (p_curso_id is null or c.id = p_curso_id)
  group by c.id, c.nombre, a.fecha
  order by c.nombre, a.fecha desc;
$$;

-- -------------------------------------------------------------------------
-- 2) Grilla alumno x día de un curso
-- -------------------------------------------------------------------------

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
      else 'presente'
    end,
    string_agg(nullif(trim(a.observacion), ''), ' / ')
  from public.asistencia a
  join public.horarios h on h.id = a.horario_id
  where h.curso_id = p_curso_id
    and a.fecha between p_desde and p_hasta
  group by a.alumno_id, a.fecha
  order by a.fecha, a.alumno_id;
$$;

-- -------------------------------------------------------------------------
-- 3) Totales por alumno de un curso (incluye inscriptos sin registros)
-- -------------------------------------------------------------------------

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
  porcentaje numeric
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
    count(d.fecha) filter (where d.estado = 'presente'),
    count(d.fecha) filter (where d.estado = 'ausente'),
    count(d.fecha) filter (where d.estado = 'justificado'),
    round(
      100.0 * count(d.fecha) filter (where d.estado = 'presente')
      / nullif(count(d.fecha) - count(d.fecha) filter (where d.estado = 'justificado'), 0),
      1
    )
  from public.inscripciones i
  join public.alumnos al on al.id = i.alumno_id
  left join dias d on d.alumno_id = al.id
  where i.curso_id = p_curso_id
  group by al.id, al.nombre, al.apellido, al.ci
  order by al.apellido, al.nombre;
$$;

grant execute on function public.resumen_asistencia_por_fecha(date, date, uuid) to authenticated;
grant execute on function public.asistencia_mensual_curso(uuid, date, date) to authenticated;
grant execute on function public.resumen_asistencia_por_alumno(uuid, date, date) to authenticated;

-- Nadie sin login tiene que poder llamarlas (RLS igual devolvería vacío,
-- pero no hay motivo para exponerlas).
revoke execute on function public.resumen_asistencia_por_fecha(date, date, uuid) from anon, public;
revoke execute on function public.asistencia_mensual_curso(uuid, date, date) from anon, public;
revoke execute on function public.resumen_asistencia_por_alumno(uuid, date, date) from anon, public;

commit;

-- =========================================================================
-- Verificación rápida post-migración (opcional, solo lectura):
--   select proname, prosecdef from pg_proc
--   where proname in ('resumen_asistencia_por_fecha',
--                     'asistencia_mensual_curso',
--                     'resumen_asistencia_por_alumno');
--   -- prosecdef debe ser false (SECURITY INVOKER) en las tres.
-- =========================================================================
