-- =========================================================================
-- Migración: RLS real + tabla de inscripciones + correcciones de esquema
-- Sistema de Asistencia — Centro Cultural Gymmart
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Es una sola transacción (BEGIN/COMMIT), si algo falla
--   no queda nada a medio aplicar.
--
-- QUÉ HACE (en orden):
--   1. Funciones helper (is_admin, current_profesor_id, current_alumno_id)
--   2. Trigger que impide que un usuario cambie su propio rol/activo
--   3. Arregla el FK horarios.curso_id (apuntaba a profesores, no a cursos)
--   4. Crea la tabla inscripciones (alumno_id <-> curso_id), que faltaba
--   5. Agrega UNIQUE(horario_id, alumno_id, fecha) en asistencia
--   6. Actualiza handle_new_user() para que también cree la fila en
--      profesores cuando el rol es docente, y use ci/apellido/telefono
--      reales si vienen en el signup (en vez de placeholders)
--   7. Reemplaza TODAS las políticas RLS actuales (que hoy son públicas
--      o inexistentes) por políticas reales basadas en rol/ownership
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Funciones helper (SECURITY DEFINER para evitar recursión de RLS)
-- -------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles where id = auth.uid() and rol = 'admin'
  );
$$;

create or replace function public.current_profesor_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from public.profesores where perfil_id = auth.uid();
$$;

create or replace function public.current_alumno_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from public.alumnos where perfil_id = auth.uid();
$$;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.current_profesor_id() to authenticated;
grant execute on function public.current_alumno_id() to authenticated;

-- -------------------------------------------------------------------------
-- 2) Evitar que un usuario se auto-ascienda cambiando su propio rol/activo
--    (hoy es posible: la policy de UPDATE en perfiles no restringe columnas)
-- -------------------------------------------------------------------------

create or replace function public.prevent_self_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if (new.rol is distinct from old.rol or new.activo is distinct from old.activo) then
    if not exists (select 1 from public.perfiles where id = auth.uid() and rol = 'admin') then
      new.rol := old.rol;
      new.activo := old.activo;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_self_privilege_escalation on public.perfiles;
create trigger trg_prevent_self_privilege_escalation
before update on public.perfiles
for each row
execute function public.prevent_self_privilege_escalation();

-- -------------------------------------------------------------------------
-- 3) Arreglar el FK de horarios.curso_id (apuntaba a profesores(id))
--    Si esto falla con "violates foreign key constraint", significa que
--    hay filas en horarios.curso_id que no son ids válidos de cursos —
--    hay que limpiar esos datos primero.
-- -------------------------------------------------------------------------

alter table public.horarios drop constraint if exists horarios_curso_id_fkey;
alter table public.horarios
  add constraint horarios_curso_id_fkey foreign key (curso_id) references public.cursos(id);

-- -------------------------------------------------------------------------
-- 4) Tabla de inscripciones (relación alumno <-> curso que faltaba)
-- -------------------------------------------------------------------------

create table if not exists public.inscripciones (
  id uuid not null default gen_random_uuid(),
  alumno_id uuid not null references public.alumnos(id) on delete cascade,
  curso_id uuid not null references public.cursos(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint inscripciones_pkey primary key (id),
  constraint inscripciones_alumno_curso_key unique (alumno_id, curso_id)
);

alter table public.inscripciones enable row level security;

-- -------------------------------------------------------------------------
-- 5) UNIQUE que necesita el upsert de LlamarLista.vue
--    (onConflict: 'horario_id,alumno_id,fecha')
-- -------------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'asistencia_horario_alumno_fecha_key'
  ) then
    alter table public.asistencia
      add constraint asistencia_horario_alumno_fecha_key unique (horario_id, alumno_id, fecha);
  end if;
end $$;

-- -------------------------------------------------------------------------
-- 6) handle_new_user: agregar rama docente + usar datos reales del signup
--    si vienen en options.data (nombre, apellido, ci, telefono, especialidad)
-- -------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  user_rol text;
  user_nombre text;
  user_apellido text;
  user_ci text;
  user_telefono text;
  user_especialidad text;
begin
  user_rol := coalesce(new.raw_user_meta_data->>'rol', 'estudiante');
  user_nombre := coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1));
  user_apellido := coalesce(new.raw_user_meta_data->>'apellido', '');
  user_telefono := new.raw_user_meta_data->>'telefono';
  user_ci := coalesce(new.raw_user_meta_data->>'ci', 'PENDIENTE-' || upper(substring(new.id::text, 1, 8)));
  user_especialidad := new.raw_user_meta_data->>'especialidad';

  insert into public.perfiles (id, user_id, nombre, apellido, rol, telefono, activo, created_at)
  values (new.id, new.id, user_nombre, user_apellido, user_rol, user_telefono, true, now())
  on conflict (id) do nothing;

  if user_rol = 'estudiante' then
    insert into public.alumnos (perfil_id, nombre, apellido, ci, telefono)
    values (new.id, user_nombre, user_apellido, user_ci, user_telefono)
    on conflict do nothing;
  elsif user_rol = 'docente' then
    insert into public.profesores (perfil_id, nombre, apellido, ci, telefono, especialidad)
    values (new.id, user_nombre, user_apellido, user_ci, user_telefono, user_especialidad)
    on conflict do nothing;
  end if;

  return new;
end;
$function$;

-- -------------------------------------------------------------------------
-- 7) Políticas RLS reales — se borran TODAS las actuales y se recrean
-- -------------------------------------------------------------------------

-- perfiles ------------------------------------------------------------
drop policy if exists "Admins can view all profiles" on public.perfiles;
drop policy if exists "Users can view own profile" on public.perfiles;
drop policy if exists "Anyone can view perfiles" on public.perfiles;
drop policy if exists "Users can update own profile" on public.perfiles;
drop policy if exists "Users can update own perfil" on public.perfiles;
drop policy if exists "perfiles_select_own_or_admin" on public.perfiles;
drop policy if exists "perfiles_update_own_or_admin" on public.perfiles;

create policy "perfiles_select_own_or_admin"
on public.perfiles for select
to authenticated
using (id = auth.uid() or public.is_admin());

create policy "perfiles_update_own_or_admin"
on public.perfiles for update
to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

-- alumnos ---------------------------------------------------------------
drop policy if exists "Anyone can view alumnos" on public.alumnos;
drop policy if exists "Users can view own alumno" on public.alumnos;
drop policy if exists "Users can update own alumno" on public.alumnos;
drop policy if exists "alumnos_select_own_staff_or_admin" on public.alumnos;
drop policy if exists "alumnos_update_own_or_admin" on public.alumnos;
drop policy if exists "alumnos_insert_admin" on public.alumnos;
drop policy if exists "alumnos_delete_admin" on public.alumnos;

create policy "alumnos_select_own_staff_or_admin"
on public.alumnos for select
to authenticated
using (
  perfil_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1 from public.inscripciones i
    join public.horarios h on h.curso_id = i.curso_id
    where i.alumno_id = alumnos.id
      and h.profesor_id = public.current_profesor_id()
  )
);

create policy "alumnos_update_own_or_admin"
on public.alumnos for update
to authenticated
using (perfil_id = auth.uid() or public.is_admin())
with check (perfil_id = auth.uid() or public.is_admin());

create policy "alumnos_insert_admin"
on public.alumnos for insert
to authenticated
with check (public.is_admin());

create policy "alumnos_delete_admin"
on public.alumnos for delete
to authenticated
using (public.is_admin());

-- profesores --------------------------------------------------------------
drop policy if exists "Anyone can view profesores" on public.profesores;
drop policy if exists "profesores_select_own_or_admin" on public.profesores;
drop policy if exists "profesores_update_own_or_admin" on public.profesores;
drop policy if exists "profesores_insert_admin" on public.profesores;
drop policy if exists "profesores_delete_admin" on public.profesores;

create policy "profesores_select_own_or_admin"
on public.profesores for select
to authenticated
using (perfil_id = auth.uid() or public.is_admin());

create policy "profesores_update_own_or_admin"
on public.profesores for update
to authenticated
using (perfil_id = auth.uid() or public.is_admin())
with check (perfil_id = auth.uid() or public.is_admin());

create policy "profesores_insert_admin"
on public.profesores for insert
to authenticated
with check (public.is_admin());

create policy "profesores_delete_admin"
on public.profesores for delete
to authenticated
using (public.is_admin());

-- cursos (no tenía NINGUNA política -> hoy nadie puede leerla) ------------
drop policy if exists "cursos_select_authenticated" on public.cursos;
drop policy if exists "cursos_insert_admin" on public.cursos;
drop policy if exists "cursos_update_admin" on public.cursos;
drop policy if exists "cursos_delete_admin" on public.cursos;

create policy "cursos_select_authenticated"
on public.cursos for select
to authenticated
using (true);

create policy "cursos_insert_admin"
on public.cursos for insert
to authenticated
with check (public.is_admin());

create policy "cursos_update_admin"
on public.cursos for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "cursos_delete_admin"
on public.cursos for delete
to authenticated
using (public.is_admin());

-- horarios ------------------------------------------------------------------
drop policy if exists "Professors view own horarios" on public.horarios;
drop policy if exists "horarios_select_scoped" on public.horarios;
drop policy if exists "horarios_insert_admin" on public.horarios;
drop policy if exists "horarios_update_admin" on public.horarios;
drop policy if exists "horarios_delete_admin" on public.horarios;

create policy "horarios_select_scoped"
on public.horarios for select
to authenticated
using (
  public.is_admin()
  or profesor_id = public.current_profesor_id()
  or exists (
    select 1 from public.inscripciones i
    where i.curso_id = horarios.curso_id
      and i.alumno_id = public.current_alumno_id()
  )
);

create policy "horarios_insert_admin"
on public.horarios for insert
to authenticated
with check (public.is_admin());

create policy "horarios_update_admin"
on public.horarios for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "horarios_delete_admin"
on public.horarios for delete
to authenticated
using (public.is_admin());

-- inscripciones (tabla nueva) -----------------------------------------------
drop policy if exists "inscripciones_select_scoped" on public.inscripciones;
drop policy if exists "inscripciones_insert_admin" on public.inscripciones;
drop policy if exists "inscripciones_update_admin" on public.inscripciones;
drop policy if exists "inscripciones_delete_admin" on public.inscripciones;

create policy "inscripciones_select_scoped"
on public.inscripciones for select
to authenticated
using (
  public.is_admin()
  or alumno_id = public.current_alumno_id()
  or exists (
    select 1 from public.horarios h
    where h.curso_id = inscripciones.curso_id
      and h.profesor_id = public.current_profesor_id()
  )
);

create policy "inscripciones_insert_admin"
on public.inscripciones for insert
to authenticated
with check (public.is_admin());

create policy "inscripciones_update_admin"
on public.inscripciones for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "inscripciones_delete_admin"
on public.inscripciones for delete
to authenticated
using (public.is_admin());

-- asistencia ------------------------------------------------------------------
drop policy if exists "Professors can manage asistencia" on public.asistencia;
drop policy if exists "Alumnos can view own asistencia" on public.asistencia;
drop policy if exists "asistencia_select_scoped" on public.asistencia;
drop policy if exists "asistencia_insert_docente_or_admin" on public.asistencia;
drop policy if exists "asistencia_update_docente_or_admin" on public.asistencia;
drop policy if exists "asistencia_delete_docente_or_admin" on public.asistencia;

create policy "asistencia_select_scoped"
on public.asistencia for select
to authenticated
using (
  public.is_admin()
  or alumno_id = public.current_alumno_id()
  or exists (
    select 1 from public.horarios h
    where h.id = asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
);

create policy "asistencia_insert_docente_or_admin"
on public.asistencia for insert
to authenticated
with check (
  public.is_admin()
  or exists (
    select 1 from public.horarios h
    where h.id = asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
);

create policy "asistencia_update_docente_or_admin"
on public.asistencia for update
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.horarios h
    where h.id = asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
)
with check (
  public.is_admin()
  or exists (
    select 1 from public.horarios h
    where h.id = asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
);

create policy "asistencia_delete_docente_or_admin"
on public.asistencia for delete
to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.horarios h
    where h.id = asistencia.horario_id
      and h.profesor_id = public.current_profesor_id()
  )
);

commit;

-- =========================================================================
-- Verificación rápida post-migración (opcional, solo lectura):
--   select tablename, policyname, cmd, roles from pg_policies
--   where schemaname = 'public' order by tablename, cmd;
-- =========================================================================
