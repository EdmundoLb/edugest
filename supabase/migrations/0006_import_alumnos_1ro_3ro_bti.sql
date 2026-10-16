-- Importación de alumnos de "1ro Bti" y "3ro Bti" (fuentes: 1RO BTI.csv, 3RO BTI.csv).
-- Mismo patrón que 0003_import_alumnos_2do_curso.sql: cuentas de alumno con email
-- placeholder <ci>@alumno.ccg.local y contraseña temporal 'Prueba123!' (mismo patrón
-- que las cuentas de prueba de la auditoría 2026-08) — no pensadas para login real
-- todavía, solo para satisfacer el FK alumnos.perfil_id -> perfiles.id -> auth.users.id.
-- Horarios Lunes a Viernes 07:15-11:15, turno Matutino, docente Edmundo López (igual
-- que el 2do curso).
--
-- Cursos destino (ids confirmados vía `select id, nombre from public.cursos`):
--   a2879dac-d1fb-4e02-be44-b62fb00d942a -- "(1º) Primer Curso-BTI"
--   674fc6be-2f0a-4672-bf12-c71a5ff1cdec -- "(3º) Tercer Curso-BTI"
--
-- Idempotente: si un alumno ya existe (por `ci`) no se recrea la cuenta, solo se
-- asegura su inscripción; los horarios no se duplican si la migración se corre de nuevo.

begin;

do $$
declare
  v_curso_id uuid;
  v_user_id uuid;
  v_alumno_id uuid;
  v_item jsonb;
  v_curso jsonb;
  v_cursos jsonb := '[
    {
      "curso_id": "a2879dac-d1fb-4e02-be44-b62fb00d942a",
      "alumnos": [
        {"nombre":"Diego Armando","apellido":"Ayala Duarte","ci":"7985857"},
        {"nombre":"Alejandro Martin","apellido":"Cuenca Ojeda","ci":"6726676"},
        {"nombre":"Erick Maximiliano","apellido":"Garza Mascareño","ci":"8211653"},
        {"nombre":"Maria Paula","apellido":"Ortiz Recalde","ci":"7312555"},
        {"nombre":"Valeria Isabel","apellido":"Patiño Gonzalez","ci":"7041491"},
        {"nombre":"Santiago Emanuel","apellido":"Torres Arriola","ci":"7473130"},
        {"nombre":"Carlos Anibal","apellido":"Vazquez Vega","ci":"7671642"},
        {"nombre":"Sebastian Manuel","apellido":"Villalba Zelaya","ci":"7315559"}
      ]
    },
    {
      "curso_id": "674fc6be-2f0a-4672-bf12-c71a5ff1cdec",
      "alumnos": [
        {"nombre":"Dayanara Patricia","apellido":"Aguiar Gauto","ci":"6533787"},
        {"nombre":"Bastian Arturo","apellido":"Chaparro Torres","ci":"6595967"},
        {"nombre":"Mia Fiorella","apellido":"Davalos Torales","ci":"8188736"},
        {"nombre":"Milena Abigail","apellido":"Dominguez Mendoza","ci":"6729146"},
        {"nombre":"Alejandra Anabeli","apellido":"Elizeche Duarte","ci":"6230374"},
        {"nombre":"David Ezequiel","apellido":"Gonzalez Gabilan","ci":"6582976"},
        {"nombre":"Lucas Armando","apellido":"Ortiz Sandoval","ci":"7350646"},
        {"nombre":"Milton Imanol","apellido":"Otazo Benitez","ci":"7784443"},
        {"nombre":"Lucas Gabriel","apellido":"Ramirez Recalde","ci":"7017602"},
        {"nombre":"Benjamin Otoniel","apellido":"Rodriguez Lopez","ci":"7059389"},
        {"nombre":"Martin Rene","apellido":"Rodriguez Rojas","ci":"6764700"},
        {"nombre":"Joel Isaias","apellido":"Tiecher Samaniego","ci":"6698692"},
        {"nombre":"Maria Lurdes","apellido":"Vega Portillo","ci":"7373572"}
      ]
    }
  ]'::jsonb;
begin
  for v_curso in select * from jsonb_array_elements(v_cursos)
  loop
    v_curso_id := (v_curso->>'curso_id')::uuid;

    -- Horarios Lunes a Viernes 07:15-11:15, turno Matutino, docente Edmundo López
    insert into public.horarios (profesor_id, curso_id, dia_semana, hora_inicio, hora_fin, turno)
    select
      '327bcb06-1601-48a8-8a5a-53c676703aa5'::uuid, v_curso_id, dia, time '07:15', time '11:15', 'Matutino'
    from unnest(array['Lunes','Martes','Miercoles','Jueves','Viernes']) as dia
    where not exists (
      select 1 from public.horarios h
      where h.curso_id = v_curso_id and h.dia_semana = dia
    );

    for v_item in select * from jsonb_array_elements(v_curso->'alumnos')
    loop
      select a.id into v_alumno_id
      from public.alumnos a
      where a.ci = (v_item->>'ci');

      if v_alumno_id is null then
        v_user_id := gen_random_uuid();

        insert into auth.users (
          instance_id, id, aud, role, email, encrypted_password,
          email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
          created_at, updated_at, confirmation_token, email_change,
          email_change_token_new, recovery_token
        ) values (
          '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
          (v_item->>'ci') || '@alumno.ccg.local',
          crypt('Prueba123!', gen_salt('bf')),
          now(),
          '{"provider":"email","providers":["email"]}'::jsonb,
          jsonb_build_object(
            'rol', 'estudiante',
            'nombre', v_item->>'nombre',
            'apellido', v_item->>'apellido',
            'ci', v_item->>'ci'
          ),
          now(), now(), '', '', '', ''
        );

        insert into auth.identities (
          id, provider_id, user_id, identity_data, provider, created_at, updated_at
        ) values (
          gen_random_uuid(), v_user_id::text, v_user_id,
          jsonb_build_object('sub', v_user_id::text, 'email', (v_item->>'ci') || '@alumno.ccg.local'),
          'email', now(), now()
        );

        select a.id into v_alumno_id
        from public.alumnos a
        where a.perfil_id = v_user_id;
      end if;

      insert into public.inscripciones (alumno_id, curso_id)
      values (v_alumno_id, v_curso_id)
      on conflict (alumno_id, curso_id) do nothing;
    end loop;
  end loop;
end $$;

commit;
