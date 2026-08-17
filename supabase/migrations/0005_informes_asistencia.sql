-- =========================================================================
-- Migración: informes diarios de asistencia (profesor -> admin -> padres)
-- Sistema de Asistencia — Centro Cultural Gymmart
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Es una sola transacción (BEGIN/COMMIT).
--
-- QUÉ HACE:
--   1. alumnos.telefono_padre (texto libre, para armar el link de WhatsApp)
--   2. Tabla informes_asistencia: el profesor "remite" la asistencia de un
--      horario+fecha a administración; el admin la marca como revisada
--      después de avisarle a los padres.
--   3. Políticas RLS de informes_asistencia. Sigue el mismo patrón que ya
--      usa `asistencia` (subquery directo contra horarios en el using/
--      with_check, sin función SECURITY DEFINER nueva) porque
--      informes_asistencia es una tabla hoja: ninguna policy de horarios
--      la consulta a ella, así que no hay ciclo posible (ver
--      docs/BASE_DE_DATOS.md, sección RLS, y 0002_fix_recursion_rls.sql
--      para el caso en que sí hizo falta una función).
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Teléfono del padre/tutor (texto libre, igual que alumnos.telefono)
-- -------------------------------------------------------------------------

alter table public.alumnos add column if not exists telefono_padre text;

-- -------------------------------------------------------------------------
-- 2) Tabla informes_asistencia
-- -------------------------------------------------------------------------

create table if not exists public.informes_asistencia (
  id uuid not null default gen_random_uuid(),
  horario_id uuid not null references public.horarios(id),
  fecha date not null,
  profesor_id uuid not null references public.profesores(id),
  estado varchar not null default 'pendiente',
  creado_at timestamptz not null default now(),
  revisado_at timestamptz,
  revisado_por uuid references public.perfiles(id),
  constraint informes_asistencia_pkey primary key (id),
  constraint informes_asistencia_horario_fecha_key unique (horario_id, fecha),
  constraint informes_asistencia_estado_check check (estado in ('pendiente', 'revisado'))
);

alter table public.informes_asistencia enable row level security;

-- -------------------------------------------------------------------------
-- 3) Políticas RLS
-- -------------------------------------------------------------------------

drop policy if exists "informes_select_scoped" on public.informes_asistencia;
drop policy if exists "informes_insert_docente_or_admin" on public.informes_asistencia;
drop policy if exists "informes_update_docente_or_admin" on public.informes_asistencia;
drop policy if exists "informes_delete_admin" on public.informes_asistencia;

create policy "informes_select_scoped"
on public.informes_asistencia for select
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.horarios h
    where h.id = informes_asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
);

create policy "informes_insert_docente_or_admin"
on public.informes_asistencia for insert
to authenticated
with check (
  public.is_admin()
  or (
    profesor_id = public.current_profesor_id()
    and exists (
      select 1 from public.horarios h
      where h.id = informes_asistencia.horario_id
        and h.profesor_id = public.current_profesor_id()
    )
  )
);

create policy "informes_update_docente_or_admin"
on public.informes_asistencia for update
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.horarios h
    where h.id = informes_asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
)
with check (
  public.is_admin()
  or exists (
    select 1 from public.horarios h
    where h.id = informes_asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
);

create policy "informes_delete_admin"
on public.informes_asistencia for delete
to authenticated
using (public.is_admin());

commit;

-- =========================================================================
-- Verificación rápida post-migración (opcional, solo lectura):
--   select tablename, policyname, cmd, roles from pg_policies
--   where schemaname = 'public' and tablename = 'informes_asistencia';
-- =========================================================================
