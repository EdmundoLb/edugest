-- =========================================================================
-- Migración: portal de familias + endurecimiento de altas
-- Sistema de Asistencia — EduGest
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> New query -> pegar TODO este
--   archivo -> Run. Es una sola transacción (BEGIN/COMMIT). Idempotente.
--   Depende de 0012 (justificaciones, inscripciones.activa). Supabase avisa
--   "Potential issue detected" por los drop policy/constraint: es esperable,
--   se borran y se recrean, no se pierden datos.
--
-- QUÉ HACE:
--   A) Seguridad (Fase 0 del plan):
--      1. handle_new_user ignoraba qué rol pedía el registro: cualquiera podía
--         crearse una cuenta 'admin' llamando a la API de signUp con
--         options.data.rol = 'admin'. Ahora solo acepta estudiante, docente y
--         tutor (cualquier otra cosa queda como estudiante).
--      2. Los docentes que se registran solos quedan con perfiles.activo =
--         false hasta que un admin los apruebe.
--      3. perfiles.activo ahora tiene efecto: is_admin(), current_alumno_id()
--         y current_profesor_id() devuelven false/null si el perfil está
--         inactivo, así que RLS no le muestra nada.
--      4. Un alumno ya no puede cambiar por la API su ci, nombre, apellido,
--         telefono_padre ni historial_academico (antes podía cambiar el
--         teléfono al que la escuela manda los avisos).
--   B) Portal de familias (Fase 1):
--      - Rol 'tutor' (padre, madre o tutor) con login propio.
--      - tutores_alumnos: qué tutor ve a qué alumno.
--      - codigos_vinculacion: código de un solo uso (8 caracteres, vence a
--        los 14 días) que genera un admin para un alumno y entrega a la
--        familia. La familia lo canjea al registrarse o desde /familia.
--      - vincular_tutor(codigo): canje con límite de 10 intentos fallidos
--        por hora (para que no se puedan adivinar códigos).
--      - Políticas SELECT de solo lectura para el tutor en alumnos,
--        inscripciones, horarios, asistencia y justificaciones de sus hijos.
--      - El teléfono del tutor principal se copia a alumnos.telefono_padre,
--        así los avisos por WhatsApp existentes le llegan a quien corresponde.
--
-- REGLA ANTI-RECURSIÓN (docs/BASE_DE_DATOS.md): todo chequeo que cruza
-- tablas desde una policy va en una función SECURITY DEFINER.
-- =========================================================================

begin;

-- -------------------------------------------------------------------------
-- 1) Rol 'tutor'
-- -------------------------------------------------------------------------

alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check
  check (rol in ('admin', 'docente', 'estudiante', 'tutor'));

-- -------------------------------------------------------------------------
-- 2) Helpers que respetan perfiles.activo
-- -------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol = 'admin' and activo is not false
  );
$$;

create or replace function public.current_profesor_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select pr.id
  from public.profesores pr
  join public.perfiles p on p.id = pr.perfil_id
  where pr.perfil_id = auth.uid() and p.activo is not false;
$$;

create or replace function public.current_alumno_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select a.id
  from public.alumnos a
  join public.perfiles p on p.id = a.perfil_id
  where a.perfil_id = auth.uid() and p.activo is not false;
$$;

-- -------------------------------------------------------------------------
-- 3) Tablas del portal de familias
-- -------------------------------------------------------------------------

create table if not exists public.tutores_alumnos (
  id            uuid primary key default gen_random_uuid(),
  tutor_id      uuid not null references public.perfiles (id) on delete cascade,
  alumno_id     uuid not null references public.alumnos (id) on delete cascade,
  parentesco    text,
  principal     boolean not null default false,
  recibe_avisos boolean not null default true,
  created_at    timestamptz not null default now(),
  constraint tutores_alumnos_unico unique (tutor_id, alumno_id)
);

create index if not exists tutores_alumnos_alumno_idx
  on public.tutores_alumnos (alumno_id);

create table if not exists public.codigos_vinculacion (
  codigo      text primary key,
  alumno_id   uuid not null references public.alumnos (id) on delete cascade,
  creado_por  uuid default auth.uid() references public.perfiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  expira_at   timestamptz not null default now() + interval '14 days',
  usado_por   uuid references public.perfiles (id) on delete set null,
  usado_at    timestamptz
);

create index if not exists codigos_vinculacion_alumno_idx
  on public.codigos_vinculacion (alumno_id);

-- Solo la usa vincular_tutor() (SECURITY DEFINER); sin políticas = nadie la
-- lee ni escribe por la API.
create table if not exists public.intentos_vinculacion (
  id          bigint generated always as identity primary key,
  perfil_id   uuid not null references public.perfiles (id) on delete cascade,
  exitoso     boolean not null,
  created_at  timestamptz not null default now()
);

create index if not exists intentos_vinculacion_perfil_idx
  on public.intentos_vinculacion (perfil_id, created_at);

alter table public.tutores_alumnos enable row level security;
alter table public.codigos_vinculacion enable row level security;
alter table public.intentos_vinculacion enable row level security;
revoke all on public.tutores_alumnos from anon;
revoke all on public.codigos_vinculacion from anon;
revoke all on public.intentos_vinculacion from anon, authenticated;

-- -------------------------------------------------------------------------
-- 4) Helpers del tutor (SECURITY DEFINER: sin recursión de RLS)
-- -------------------------------------------------------------------------

create or replace function public.tutor_de_alumno(p_alumno_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.tutores_alumnos ta
    join public.perfiles p on p.id = ta.tutor_id
    where ta.tutor_id = auth.uid()
      and ta.alumno_id = p_alumno_id
      and p.rol = 'tutor'
      and p.activo is not false
  );
$$;

create or replace function public.tutor_ve_curso(p_curso_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.tutores_alumnos ta
    join public.perfiles p on p.id = ta.tutor_id
    join public.inscripciones i on i.alumno_id = ta.alumno_id
    where ta.tutor_id = auth.uid()
      and i.curso_id = p_curso_id
      and p.rol = 'tutor'
      and p.activo is not false
  );
$$;

grant execute on function public.tutor_de_alumno(uuid) to authenticated;
grant execute on function public.tutor_ve_curso(uuid) to authenticated;
revoke execute on function public.tutor_de_alumno(uuid) from anon, public;
revoke execute on function public.tutor_ve_curso(uuid) from anon, public;

-- -------------------------------------------------------------------------
-- 5) Políticas de las tablas nuevas
-- -------------------------------------------------------------------------

drop policy if exists "tutores_alumnos_select_scoped" on public.tutores_alumnos;
drop policy if exists "tutores_alumnos_insert_admin" on public.tutores_alumnos;
drop policy if exists "tutores_alumnos_update_admin" on public.tutores_alumnos;
drop policy if exists "tutores_alumnos_delete_admin_o_propio" on public.tutores_alumnos;

create policy "tutores_alumnos_select_scoped"
on public.tutores_alumnos for select
to authenticated
using (
  tutor_id = auth.uid()
  or public.is_admin()
  or public.docente_tiene_alumno(alumno_id)
);

-- El tutor no inserta directo: canjea un código con vincular_tutor().
create policy "tutores_alumnos_insert_admin"
on public.tutores_alumnos for insert
to authenticated
with check (public.is_admin());

create policy "tutores_alumnos_update_admin"
on public.tutores_alumnos for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "tutores_alumnos_delete_admin_o_propio"
on public.tutores_alumnos for delete
to authenticated
using (public.is_admin() or tutor_id = auth.uid());

drop policy if exists "codigos_vinculacion_select_admin" on public.codigos_vinculacion;
drop policy if exists "codigos_vinculacion_delete_admin" on public.codigos_vinculacion;

create policy "codigos_vinculacion_select_admin"
on public.codigos_vinculacion for select
to authenticated
using (public.is_admin());

create policy "codigos_vinculacion_delete_admin"
on public.codigos_vinculacion for delete
to authenticated
using (public.is_admin());

-- -------------------------------------------------------------------------
-- 6) Lectura para el tutor en las tablas existentes (se recrean las
--    políticas SELECT con la misma lógica de antes + la cláusula del tutor)
-- -------------------------------------------------------------------------

drop policy if exists "alumnos_select_own_staff_or_admin" on public.alumnos;
create policy "alumnos_select_own_staff_or_admin"
on public.alumnos for select
to authenticated
using (
  perfil_id = auth.uid()
  or public.is_admin()
  or public.docente_tiene_alumno(alumnos.id)
  or public.tutor_de_alumno(alumnos.id)
);

drop policy if exists "inscripciones_select_scoped" on public.inscripciones;
create policy "inscripciones_select_scoped"
on public.inscripciones for select
to authenticated
using (
  public.is_admin()
  or alumno_id = public.current_alumno_id()
  or public.docente_dicta_curso(inscripciones.curso_id)
  or public.tutor_de_alumno(inscripciones.alumno_id)
);

drop policy if exists "horarios_select_scoped" on public.horarios;
create policy "horarios_select_scoped"
on public.horarios for select
to authenticated
using (
  public.is_admin()
  or profesor_id = public.current_profesor_id()
  or public.alumno_inscripto_en_curso(horarios.curso_id)
  or public.tutor_ve_curso(horarios.curso_id)
);

drop policy if exists "asistencia_select_scoped" on public.asistencia;
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
  or public.tutor_de_alumno(asistencia.alumno_id)
);

drop policy if exists "justificaciones_select_scoped" on public.justificaciones;
create policy "justificaciones_select_scoped"
on public.justificaciones for select
to authenticated
using (
  public.is_admin()
  or alumno_id = public.current_alumno_id()
  or public.docente_tiene_alumno(alumno_id)
  or public.tutor_de_alumno(alumno_id)
);

-- -------------------------------------------------------------------------
-- 7) El alumno no puede cambiar sus datos de identidad ni el contacto de
--    la familia. SECURITY INVOKER a propósito: `current_user` es
--    'authenticated' cuando el UPDATE viene de la API, y el dueño de la
--    función (postgres) cuando viene de una función SECURITY DEFINER o del
--    SQL Editor, que sí pueden.
-- -------------------------------------------------------------------------

create or replace function public.proteger_columnas_alumno()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    new.perfil_id := old.perfil_id;
    new.ci := old.ci;
    new.nombre := old.nombre;
    new.apellido := old.apellido;
    new.telefono_padre := old.telefono_padre;
    new.historial_academico := old.historial_academico;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_columnas_alumno on public.alumnos;
create trigger trg_proteger_columnas_alumno
before update on public.alumnos
for each row execute function public.proteger_columnas_alumno();

-- -------------------------------------------------------------------------
-- 8) Teléfono de la familia: el del tutor principal pasa a
--    alumnos.telefono_padre (lo que usan los avisos por WhatsApp)
-- -------------------------------------------------------------------------

create or replace function public._sincronizar_telefono_familia(p_alumno_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.alumnos a
  set telefono_padre = trim(p.telefono)
  from public.tutores_alumnos ta
  join public.perfiles p on p.id = ta.tutor_id
  where ta.alumno_id = p_alumno_id
    and ta.principal
    and a.id = ta.alumno_id
    and nullif(trim(p.telefono), '') is not null;
$$;

create or replace function public.tutor_telefono_actualizado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rol = 'tutor' and nullif(trim(new.telefono), '') is not null then
    update public.alumnos a
    set telefono_padre = trim(new.telefono)
    from public.tutores_alumnos ta
    where ta.tutor_id = new.id
      and ta.principal
      and a.id = ta.alumno_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_tutor_telefono_actualizado on public.perfiles;
create trigger trg_tutor_telefono_actualizado
after update of telefono on public.perfiles
for each row
when (new.telefono is distinct from old.telefono)
execute function public.tutor_telefono_actualizado();

-- Si se desvincula al tutor principal, pasa a serlo el más antiguo que quede.
create or replace function public.tutor_principal_al_desvincular()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.principal then
    update public.tutores_alumnos
    set principal = true
    where id = (
      select id from public.tutores_alumnos
      where alumno_id = old.alumno_id
      order by created_at
      limit 1
    );
    perform public._sincronizar_telefono_familia(old.alumno_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_tutor_principal_al_desvincular on public.tutores_alumnos;
create trigger trg_tutor_principal_al_desvincular
after delete on public.tutores_alumnos
for each row execute function public.tutor_principal_al_desvincular();

-- -------------------------------------------------------------------------
-- 9) Códigos de vinculación
-- -------------------------------------------------------------------------

-- 8 caracteres de un alfabeto de 32 sin I, O, 0 ni 1 (no se confunden al
-- dictarlos). 256 es múltiplo de 32, así que no hay sesgo.
create or replace function public._nuevo_codigo_vinculacion()
returns text
language plpgsql
volatile
set search_path = public, extensions
as $$
declare
  alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea := gen_random_bytes(8);
  resultado text := '';
begin
  for i in 0..7 loop
    resultado := resultado || substr(alfabeto, (get_byte(bytes, i) % 32) + 1, 1);
  end loop;
  return resultado;
end;
$$;

create or replace function public.generar_codigo_vinculacion(p_alumno_id uuid)
returns table (codigo text, expira_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede generar códigos de vinculación'
      using errcode = '42501';
  end if;
  if not exists (select 1 from public.alumnos where id = p_alumno_id) then
    raise exception 'El alumno no existe' using errcode = '22023';
  end if;

  loop
    v_codigo := public._nuevo_codigo_vinculacion();
    begin
      insert into public.codigos_vinculacion (codigo, alumno_id, creado_por)
      values (v_codigo, p_alumno_id, auth.uid());
      exit;
    exception when unique_violation then
      -- colisión (prácticamente imposible): se prueba con otro
      null;
    end;
  end loop;

  return query
    select c.codigo, c.expira_at from public.codigos_vinculacion c where c.codigo = v_codigo;
end;
$$;

-- Canje interno: lo usan vincular_tutor() y handle_new_user(). Devuelve el
-- alumno vinculado, o null si el código no sirve.
create or replace function public._canjear_codigo_vinculacion(p_tutor_id uuid, p_codigo text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  v_alumno_id uuid;
begin
  select c.alumno_id into v_alumno_id
  from public.codigos_vinculacion c
  where c.codigo = v_codigo and c.usado_at is null and c.expira_at > now()
  for update;

  if v_alumno_id is null then
    return null;
  end if;

  insert into public.tutores_alumnos (tutor_id, alumno_id, principal)
  values (
    p_tutor_id,
    v_alumno_id,
    not exists (select 1 from public.tutores_alumnos where alumno_id = v_alumno_id)
  )
  on conflict (tutor_id, alumno_id) do nothing;

  update public.codigos_vinculacion
  set usado_por = p_tutor_id, usado_at = now()
  where codigo = v_codigo;

  perform public._sincronizar_telefono_familia(v_alumno_id);
  return v_alumno_id;
end;
$$;

-- No lanza excepciones a propósito: si fallara, el intento fallido registrado
-- se desharía con el rollback y el límite de intentos no serviría.
create or replace function public.vincular_tutor(p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_alumno_id uuid;
begin
  if v_uid is null or not exists (
    select 1 from public.perfiles where id = v_uid and rol = 'tutor' and activo is not false
  ) then
    return jsonb_build_object('ok', false, 'error', 'Solo una cuenta de familia puede vincular alumnos.');
  end if;

  if (
    select count(*) from public.intentos_vinculacion
    where perfil_id = v_uid and not exitoso and created_at > now() - interval '1 hour'
  ) >= 10 then
    return jsonb_build_object(
      'ok', false,
      'error', 'Demasiados intentos fallidos. Probá de nuevo en una hora.'
    );
  end if;

  v_alumno_id := public._canjear_codigo_vinculacion(v_uid, p_codigo);

  insert into public.intentos_vinculacion (perfil_id, exitoso)
  values (v_uid, v_alumno_id is not null);

  if v_alumno_id is null then
    return jsonb_build_object(
      'ok', false,
      'error', 'El código no es válido, ya se usó o venció. Pedile uno nuevo a la institución.'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'alumno_id', v_alumno_id,
    'nombre', (select nombre || ' ' || apellido from public.alumnos where id = v_alumno_id)
  );
end;
$$;

-- Tutores de un alumno con sus datos de contacto (perfiles solo deja ver la
-- fila propia, por eso es una función). El email solo lo ve el admin.
create or replace function public.tutores_de_alumno(p_alumno_id uuid)
returns table (
  vinculo_id uuid,
  tutor_id uuid,
  nombre text,
  apellido text,
  telefono text,
  email text,
  parentesco text,
  principal boolean,
  vinculado_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    ta.id,
    p.id,
    p.nombre::text,
    p.apellido::text,
    p.telefono::text,
    case when public.is_admin() then u.email::text end,
    ta.parentesco,
    ta.principal,
    ta.created_at
  from public.tutores_alumnos ta
  join public.perfiles p on p.id = ta.tutor_id
  left join auth.users u on u.id = p.id
  where ta.alumno_id = p_alumno_id
    and (
      public.is_admin()
      or public.docente_tiene_alumno(p_alumno_id)
      or public.tutor_de_alumno(p_alumno_id)
    )
  order by ta.principal desc, ta.created_at;
$$;

revoke execute on function public._nuevo_codigo_vinculacion() from anon, authenticated, public;
revoke execute on function public._canjear_codigo_vinculacion(uuid, text) from anon, authenticated, public;
revoke execute on function public._sincronizar_telefono_familia(uuid) from anon, authenticated, public;
revoke execute on function public.tutor_telefono_actualizado() from anon, authenticated, public;
revoke execute on function public.tutor_principal_al_desvincular() from anon, authenticated, public;
revoke execute on function public.generar_codigo_vinculacion(uuid) from anon, public;
revoke execute on function public.vincular_tutor(text) from anon, public;
revoke execute on function public.tutores_de_alumno(uuid) from anon, public;
grant execute on function public.generar_codigo_vinculacion(uuid) to authenticated;
grant execute on function public.vincular_tutor(text) to authenticated;
grant execute on function public.tutores_de_alumno(uuid) to authenticated;

-- -------------------------------------------------------------------------
-- 10) handle_new_user: lista blanca de roles, docentes pendientes de
--     aprobación, rama tutor (con canje opcional del código de vinculación)
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
  user_codigo text;
begin
  user_rol := coalesce(new.raw_user_meta_data->>'rol', 'estudiante');
  -- 'admin' nunca se acepta desde el registro: se promueve a mano.
  if user_rol not in ('estudiante', 'docente', 'tutor') then
    user_rol := 'estudiante';
  end if;

  user_nombre := coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1));
  user_apellido := coalesce(new.raw_user_meta_data->>'apellido', '');
  user_telefono := new.raw_user_meta_data->>'telefono';
  user_ci := coalesce(new.raw_user_meta_data->>'ci', 'PENDIENTE-' || upper(substring(new.id::text, 1, 8)));
  user_especialidad := new.raw_user_meta_data->>'especialidad';
  user_codigo := new.raw_user_meta_data->>'codigo_vinculacion';

  insert into public.perfiles (id, user_id, nombre, apellido, rol, telefono, activo, created_at)
  values (
    new.id, new.id, user_nombre, user_apellido, user_rol, user_telefono,
    user_rol <> 'docente', -- un docente queda pendiente hasta que lo apruebe un admin
    now()
  )
  on conflict (id) do nothing;

  if user_rol = 'estudiante' then
    insert into public.alumnos (perfil_id, nombre, apellido, ci, telefono)
    values (new.id, user_nombre, user_apellido, user_ci, user_telefono)
    on conflict do nothing;
  elsif user_rol = 'docente' then
    insert into public.profesores (perfil_id, nombre, apellido, ci, telefono, especialidad)
    values (new.id, user_nombre, user_apellido, user_ci, user_telefono, user_especialidad)
    on conflict do nothing;
  elsif user_rol = 'tutor' and nullif(trim(user_codigo), '') is not null then
    -- Un código inválido no tiene que impedir crear la cuenta: se puede
    -- canjear después desde /familia/vincular.
    begin
      perform public._canjear_codigo_vinculacion(new.id, user_codigo);
    exception when others then
      null;
    end;
  end if;

  return new;
end;
$function$;

commit;

-- =========================================================================
-- Verificación (solo lectura):
--   select jsonb_pretty(jsonb_build_object(
--     'tablas', (select jsonb_agg(table_name) from information_schema.tables
--                where table_schema = 'public'
--                  and table_name in ('tutores_alumnos','codigos_vinculacion','intentos_vinculacion')),
--     'funciones', (select jsonb_agg(proname) from pg_proc
--                   where proname in ('tutor_de_alumno','tutor_ve_curso','vincular_tutor',
--                                     'generar_codigo_vinculacion','tutores_de_alumno')),
--     'check_rol', (select pg_get_constraintdef(oid) from pg_constraint where conname = 'perfiles_rol_check')
--   )) as resultado;
-- =========================================================================
