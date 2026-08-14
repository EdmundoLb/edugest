-- Limpieza de cursos duplicados (creados vacíos el 2026-06-16, 0 horarios / 0 inscripciones)
-- e importación del curso "2do - Gabinete de Informática" con sus 11 alumnos reales
-- (fuente: 2DO CURSO.csv). Cuentas de alumno creadas con email placeholder
-- <ci>@alumno.ccg.local y contraseña temporal 'Prueba123!' (mismo patrón que las
-- cuentas de prueba de la auditoría 2026-08) — no pensadas para login real todavía,
-- solo para satisfacer el FK alumnos.perfil_id -> perfiles.id -> auth.users.id.

begin;

-- 1) Borrar las 2 copias duplicadas y vacías de cada uno de "(1º)/(2º)/(3º) Curso"
--    (se deja la más antigua de cada nombre; "(2º) Segundo Curso" sobreviviente
--    es 3c58df76-66f8-45b7-bfa3-85a3b88825b1, el que usamos abajo)
delete from public.cursos where id in (
  'd1ff0639-9a2e-4906-93f2-c353028a26e3',
  '67b88271-e615-420b-8c10-192a99300dca',
  'e6e96683-d9f0-4273-8323-5709672551e7',
  '889b79ba-f6ab-4dd9-8aeb-44689027827d',
  '7382d350-6987-48e8-a8a3-8d564e5aa028',
  '0d43d06c-0117-4dd1-96c4-2342f05568f7'
);

-- 2) Horarios Lunes a Viernes 07:15-11:15, turno Matutino, docente Edmundo López
insert into public.horarios (profesor_id, curso_id, dia_semana, hora_inicio, hora_fin, turno)
select
  '327bcb06-1601-48a8-8a5a-53c676703aa5'::uuid, -- Edmundo López (profesores.id)
  '3c58df76-66f8-45b7-bfa3-85a3b88825b1'::uuid, -- "(2º) Segundo Curso"
  dia, time '07:15', time '11:15', 'Matutino'
from unnest(array['Lunes','Martes','Miercoles','Jueves','Viernes']) as dia;

-- 3) Alumnos: cuenta en auth.users (dispara handle_new_user -> perfiles + alumnos) + inscripción
do $$
declare
  v_curso_id uuid := '3c58df76-66f8-45b7-bfa3-85a3b88825b1';
  v_user_id uuid;
  v_item jsonb;
  alumnos_data jsonb := '[
    {"nombre":"Sofia Milagros","apellido":"Acosta Miranda","ci":"7119043"},
    {"nombre":"Michael Isaac","apellido":"Douglas Mendoza","ci":"6739071"},
    {"nombre":"Benjamin","apellido":"Frutos Burgos","ci":"6824594"},
    {"nombre":"Andrea Judith","apellido":"Galeano Recalde","ci":"7318139"},
    {"nombre":"Maximo David","apellido":"Galeano Torales","ci":"7427242"},
    {"nombre":"Tania Ines","apellido":"Irala Benitez","ci":"7015583"},
    {"nombre":"Melina Ailen","apellido":"Jimenez Ortiz","ci":"6687313"},
    {"nombre":"Pablo David","apellido":"Mendoza Chavez","ci":"6969391"},
    {"nombre":"Fiorella","apellido":"Ortiz de Almeida Santos","ci":"7055352"},
    {"nombre":"Miley Adriana","apellido":"Rodriguez Baez","ci":"7980321"},
    {"nombre":"Nathalia Jazmin","apellido":"Varela Martinez","ci":"8099359"}
  ]'::jsonb;
begin
  for v_item in select * from jsonb_array_elements(alumnos_data)
  loop
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

    insert into public.inscripciones (alumno_id, curso_id)
    select a.id, v_curso_id from public.alumnos a where a.perfil_id = v_user_id;
  end loop;
end $$;

commit;
