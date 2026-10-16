-- =========================================================================
-- Migración: alertas de inasistencia
-- Sistema de Asistencia — Centro Cultural Gymmart
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Depende de 0004 (asistencia.estado). Idempotente.
--
-- QUÉ CREA:
--   alumnos_en_riesgo(desde, hasta, umbral_pct, faltas_seguidas, minimo_clases)
--     Una fila por alumno+curso que cumple AL MENOS una condición:
--       a) porcentaje de asistencia en el período < umbral_pct (con al menos
--          minimo_clases clases registradas, para que una sola falta al
--          principio de mes no dispare la alerta), o
--       b) las últimas `faltas_seguidas` clases (o más) registradas hasta
--          `hasta` fueron ausencias sin justificar, seguidas.
--
--   Porcentaje = presentes / (total - justificados), igual que en el resto
--   del sistema. Una falta justificada corta la racha de faltas seguidas.
--   Si un curso tiene dos horarios el mismo día, ese día cuenta una vez
--   (ausente > justificado > presente), igual que en el reporte mensual.
--
-- SEGURIDAD:
--   SECURITY INVOKER: RLS filtra como en cualquier consulta. Admin ve todos
--   los alumnos; un docente, solo los de sus cursos; un estudiante, solo él.
-- =========================================================================

begin;

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
        else 'presente'
      end as estado
    from public.asistencia a
    join public.horarios h on h.id = a.horario_id
    where a.fecha <= p_hasta
    group by h.curso_id, a.alumno_id, a.fecha
  ),
  -- Racha actual: recorriendo de la fecha más reciente hacia atrás, las
  -- filas antes del primer día que no fue 'ausente'.
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
      count(*) filter (where d.estado = 'presente') as presentes,
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
  where (x.total >= p_minimo_clases and x.pct < p_umbral_pct)
     or x.seguidas >= p_faltas_seguidas
  order by x.seguidas desc, x.pct asc nulls last, al.apellido, al.nombre;
$$;

revoke execute on function public.alumnos_en_riesgo(date, date, numeric, integer, integer) from anon, public;
grant execute on function public.alumnos_en_riesgo(date, date, numeric, integer, integer) to authenticated;

commit;

-- =========================================================================
-- Prueba (solo lectura), alertas del mes en curso:
--   select * from public.alumnos_en_riesgo(date_trunc('month', current_date)::date, current_date);
-- (Desde el SQL Editor corre como postgres, sin RLS: ve todos los cursos.)
-- =========================================================================
