-- =========================================================================
-- Migración: justificaciones de faltas por rango + bajas de inscripción
-- Sistema de Asistencia — Centro Cultural Gymmart
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Es una sola transacción (BEGIN/COMMIT).
--   Depende de 0008 (asistencia_mensual_curso) y redefine funciones de 0008
--   y 0011, así que va DESPUÉS de las dos. Es idempotente.
--
-- QUÉ HACE:
--   1. Bajas: inscripciones.activa / fecha_baja / motivo_baja. Dar de baja a
--      un alumno de un curso es un UPDATE (activa = false), no un DELETE:
--      su historial de asistencia sigue apareciendo en los reportes de los
--      meses en que estuvo inscripto, y deja de aparecer al tomar lista.
--   2. Redefine resumen_asistencia_por_alumno (0008) para devolver activa y
--      fecha_baja, e incluir a los dados de baja solo si tienen registros en
--      el período o se dieron de baja dentro de él.
--   3. Redefine alumnos_en_riesgo (0011) para ignorar inscripciones dadas
--      de baja.
--   4. Tabla justificaciones (alumno, curso opcional, desde, hasta, motivo):
--      ej. un certificado médico que cubre varios días.
--        - Al crearla, las faltas ('ausente') ya cargadas en ese rango pasan
--          a 'justificado' y quedan enlazadas (asistencia.justificacion_id).
--        - Las faltas que se carguen DESPUÉS dentro del rango también se
--          justifican solas (trigger sobre asistencia).
--        - Al anularla (DELETE), las asistencias que justificó vuelven a
--          'ausente' (salvo que otra justificación vigente las cubra).
--
-- SEGURIDAD:
--   - justificaciones tiene RLS: la ve admin, el propio alumno y los docentes
--     que tienen a ese alumno; la crea admin, o un docente para un curso que
--     dicta y un alumno suyo; la anula admin o quien la creó. Sin UPDATE
--     (para corregir, se anula y se carga de nuevo).
--   - Los triggers son SECURITY DEFINER porque tienen que tocar asistencia
--     de horarios que pueden no ser del usuario; el alcance ya quedó
--     validado por la política de INSERT/DELETE de justificaciones, y solo
--     cambian ausente <-> justificado dentro de ese alcance.
--   - asistencia.justificacion_id NO tiene FK a propósito: con una FK
--     "on delete set null" el enlace se borraría antes de que el trigger de
--     anulación pueda usarlo para revertir. La integridad la mantiene ese
--     mismo trigger.
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Bajas de inscripción
-- -------------------------------------------------------------------------

alter table public.inscripciones
  add column if not exists activa boolean not null default true,
  add column if not exists fecha_baja date,
  add column if not exists motivo_baja text;

create index if not exists inscripciones_curso_activa_idx
  on public.inscripciones (curso_id) where activa;

-- -------------------------------------------------------------------------
-- 2) resumen_asistencia_por_alumno con estado de la inscripción
--    (cambia el tipo de retorno: hay que borrarla y crearla de nuevo)
-- -------------------------------------------------------------------------

drop function if exists public.resumen_asistencia_por_alumno(uuid, date, date);

create function public.resumen_asistencia_por_alumno(
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
    count(d.fecha) filter (where d.estado = 'presente'),
    count(d.fecha) filter (where d.estado = 'ausente'),
    count(d.fecha) filter (where d.estado = 'justificado'),
    round(
      100.0 * count(d.fecha) filter (where d.estado = 'presente')
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

grant execute on function public.resumen_asistencia_por_alumno(uuid, date, date) to authenticated;
revoke execute on function public.resumen_asistencia_por_alumno(uuid, date, date) from anon, public;

-- -------------------------------------------------------------------------
-- 3) alumnos_en_riesgo sin las inscripciones dadas de baja
--    (misma firma y cuerpo que 0011, más el filtro final)
-- -------------------------------------------------------------------------

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
  where ((x.total >= p_minimo_clases and x.pct < p_umbral_pct)
     or x.seguidas >= p_faltas_seguidas)
    and not exists (
      select 1 from public.inscripciones i
      where i.alumno_id = x.alumno_id and i.curso_id = x.curso_id and not i.activa
    )
  order by x.seguidas desc, x.pct asc nulls last, al.apellido, al.nombre;
$$;

revoke execute on function public.alumnos_en_riesgo(date, date, numeric, integer, integer) from anon, public;
grant execute on function public.alumnos_en_riesgo(date, date, numeric, integer, integer) to authenticated;

-- -------------------------------------------------------------------------
-- 4) Justificaciones
-- -------------------------------------------------------------------------

create table if not exists public.justificaciones (
  id          uuid primary key default gen_random_uuid(),
  alumno_id   uuid not null references public.alumnos (id) on delete cascade,
  curso_id    uuid references public.cursos (id) on delete cascade, -- null = todos sus cursos
  desde       date not null,
  hasta       date not null,
  motivo      text not null,
  creado_por  uuid default auth.uid() references public.perfiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint justificaciones_rango check (hasta >= desde),
  constraint justificaciones_motivo check (length(trim(motivo)) > 0)
);

create index if not exists justificaciones_alumno_idx
  on public.justificaciones (alumno_id, desde, hasta);

alter table public.justificaciones enable row level security;
revoke all on public.justificaciones from anon;

drop policy if exists "justificaciones_select_scoped" on public.justificaciones;
drop policy if exists "justificaciones_insert_scoped" on public.justificaciones;
drop policy if exists "justificaciones_delete_scoped" on public.justificaciones;

create policy "justificaciones_select_scoped"
on public.justificaciones for select
to authenticated
using (
  public.is_admin()
  or alumno_id = public.current_alumno_id()
  or public.docente_tiene_alumno(alumno_id)
);

create policy "justificaciones_insert_scoped"
on public.justificaciones for insert
to authenticated
with check (
  creado_por = auth.uid()
  and (
    public.is_admin()
    or (
      curso_id is not null
      and public.docente_dicta_curso(curso_id)
      and public.docente_tiene_alumno(alumno_id)
    )
  )
);

create policy "justificaciones_delete_scoped"
on public.justificaciones for delete
to authenticated
using (public.is_admin() or creado_por = auth.uid());

alter table public.asistencia
  add column if not exists justificacion_id uuid;

create index if not exists asistencia_justificacion_idx
  on public.asistencia (justificacion_id) where justificacion_id is not null;

-- 4a) Asistencia que se carga o cambia a 'ausente' dentro de un rango
--     justificado -> pasa a 'justificado'.
create or replace function public.asistencia_aplicar_justificacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_motivo text;
begin
  if new.estado = 'presente' then
    new.justificacion_id := null;
    return new;
  end if;

  if new.estado <> 'ausente' then
    return new;
  end if;

  select j.id, j.motivo
    into v_id, v_motivo
  from public.justificaciones j
  join public.horarios h on h.id = new.horario_id
  where j.alumno_id = new.alumno_id
    and new.fecha between j.desde and j.hasta
    and (j.curso_id is null or j.curso_id = h.curso_id)
  order by j.created_at desc
  limit 1;

  if v_id is null then
    new.justificacion_id := null;
  else
    new.estado := 'justificado';
    new.justificacion_id := v_id;
    if coalesce(trim(new.observacion), '') = '' then
      new.observacion := 'Justificado: ' || v_motivo;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_asistencia_aplicar_justificacion on public.asistencia;
create trigger trg_asistencia_aplicar_justificacion
before insert or update of estado, fecha, alumno_id, horario_id on public.asistencia
for each row execute function public.asistencia_aplicar_justificacion();

-- 4b) Nueva justificación -> justifica las faltas ya cargadas en el rango.
create or replace function public.justificacion_al_crear()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.asistencia a
  set estado = 'justificado',
      justificacion_id = new.id,
      observacion = coalesce(nullif(trim(a.observacion), ''), 'Justificado: ' || new.motivo)
  from public.horarios h
  where h.id = a.horario_id
    and a.alumno_id = new.alumno_id
    and a.fecha between new.desde and new.hasta
    and a.estado = 'ausente'
    and (new.curso_id is null or h.curso_id = new.curso_id);
  return null;
end;
$$;

drop trigger if exists trg_justificacion_al_crear on public.justificaciones;
create trigger trg_justificacion_al_crear
after insert on public.justificaciones
for each row execute function public.justificacion_al_crear();

-- 4c) Justificación anulada -> sus asistencias vuelven a 'ausente'. Corre
--     AFTER DELETE, así que el trigger 4a ya no la encuentra; si otra
--     justificación vigente cubre ese día, 4a la vuelve a justificar.
create or replace function public.justificacion_al_anular()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.asistencia
  set estado = 'ausente',
      justificacion_id = null,
      observacion = case
        when observacion = 'Justificado: ' || old.motivo then null
        else observacion
      end
  where justificacion_id = old.id;
  return null;
end;
$$;

drop trigger if exists trg_justificacion_al_anular on public.justificaciones;
create trigger trg_justificacion_al_anular
after delete on public.justificaciones
for each row execute function public.justificacion_al_anular();

-- Las funciones de trigger no tienen por qué ser llamables por RPC.
revoke execute on function public.asistencia_aplicar_justificacion() from anon, authenticated, public;
revoke execute on function public.justificacion_al_crear() from anon, authenticated, public;
revoke execute on function public.justificacion_al_anular() from anon, authenticated, public;

commit;

-- =========================================================================
-- Verificación (solo lectura, UNA consulta que devuelve todo junto):
--
-- select jsonb_pretty(jsonb_build_object(
--   'columnas_inscripciones', (
--     select jsonb_agg(column_name order by column_name)
--     from information_schema.columns
--     where table_schema = 'public' and table_name = 'inscripciones'
--       and column_name in ('activa', 'fecha_baja', 'motivo_baja')),
--   'tabla_justificaciones_rls', (
--     select relrowsecurity from pg_class
--     where oid = 'public.justificaciones'::regclass),
--   'politicas_justificaciones', (
--     select jsonb_agg(policyname order by policyname)
--     from pg_policies where tablename = 'justificaciones'),
--   'triggers', (
--     select jsonb_agg(tgname order by tgname) from pg_trigger
--     where tgname in ('trg_asistencia_aplicar_justificacion',
--                      'trg_justificacion_al_crear',
--                      'trg_justificacion_al_anular')),
--   'resumen_por_alumno_tiene_activa', (
--     select pg_get_function_result(oid) like '%activa%' from pg_proc
--     where proname = 'resumen_asistencia_por_alumno')
-- )) as resultado;
--
-- Esperado: 3 columnas, rls true, 3 políticas, 3 triggers, true.
-- =========================================================================
