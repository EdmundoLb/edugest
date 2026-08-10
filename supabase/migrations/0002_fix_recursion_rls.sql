-- =========================================================================
-- Fix: recursión infinita entre las políticas de horarios <-> inscripciones
-- (error Postgres 42P17: "infinite recursion detected in policy for
-- relation inscripciones", visto al cargar /admin y al loguearse como
-- estudiante).
--
-- Causa: las políticas de horarios e inscripciones se consultaban una a la
-- otra directamente (sin pasar por una función SECURITY DEFINER), así que
-- Postgres evaluaba horarios -> inscripciones -> horarios -> ... sin fin.
--
-- Solución: envolver esos chequeos cruzados en funciones SECURITY DEFINER
-- (mismo patrón que is_admin()), que al ejecutarse como dueños de la tabla
-- no vuelven a pasar por RLS y cortan el ciclo.
--
-- CÓMO EJECUTAR: pegar entero en el SQL Editor de Supabase -> Run.
-- =========================================================================

begin;

create or replace function public.docente_dicta_curso(p_curso_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.horarios h
    where h.curso_id = p_curso_id
      and h.profesor_id = public.current_profesor_id()
  );
$$;

create or replace function public.alumno_inscripto_en_curso(p_curso_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.inscripciones i
    where i.curso_id = p_curso_id
      and i.alumno_id = public.current_alumno_id()
  );
$$;

create or replace function public.docente_tiene_alumno(p_alumno_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.inscripciones i
    join public.horarios h on h.curso_id = i.curso_id
    where i.alumno_id = p_alumno_id
      and h.profesor_id = public.current_profesor_id()
  );
$$;

grant execute on function public.docente_dicta_curso(uuid) to authenticated;
grant execute on function public.alumno_inscripto_en_curso(uuid) to authenticated;
grant execute on function public.docente_tiene_alumno(uuid) to authenticated;

-- horarios: ya no consulta inscripciones directamente
drop policy if exists "horarios_select_scoped" on public.horarios;
create policy "horarios_select_scoped"
on public.horarios for select
to authenticated
using (
  public.is_admin()
  or profesor_id = public.current_profesor_id()
  or public.alumno_inscripto_en_curso(horarios.curso_id)
);

-- inscripciones: ya no consulta horarios directamente
drop policy if exists "inscripciones_select_scoped" on public.inscripciones;
create policy "inscripciones_select_scoped"
on public.inscripciones for select
to authenticated
using (
  public.is_admin()
  or alumno_id = public.current_alumno_id()
  or public.docente_dicta_curso(inscripciones.curso_id)
);

-- alumnos: ya no consulta inscripciones/horarios directamente
drop policy if exists "alumnos_select_own_staff_or_admin" on public.alumnos;
create policy "alumnos_select_own_staff_or_admin"
on public.alumnos for select
to authenticated
using (
  perfil_id = auth.uid()
  or public.is_admin()
  or public.docente_tiene_alumno(alumnos.id)
);

commit;
