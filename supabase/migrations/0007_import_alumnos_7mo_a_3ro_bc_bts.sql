-- Importación de 7 cursos nuevos (Séptimo, Octavo, Noveno, Primer/Segundo/Tercer
-- Curso-BC, Primer Curso-BTS) con sus alumnos reales. Fuentes: "SEPTIMO - Sheet1.csv",
-- "OCTAVO - Sheet1.csv", "NOVENO - Sheet1.csv", "PRIMERO BC - Sheet1.csv",
-- "SEGUNDO BC - Sheet1.csv", "TERCERO BC - Sheet1.csv", "PRIMERO BTS - Sheet1.csv".
-- Mismo patrón que 0003/0006: cuentas de alumno con email placeholder
-- <ci>@alumno.ccg.local y contraseña temporal 'Prueba123!' (no pensadas para login
-- real todavía). A diferencia de 0006, estos cursos NO existen todavía: esta
-- migración los crea en public.cursos y les carga horario (Lunes a Viernes
-- 07:15-11:15, turno Matutino, docente Edmundo López) antes de inscribir alumnos.
--
-- 4 alumnos sin C.I. en la planilla original quedaron AFUERA de este import
-- (agregarlos en una migración futura cuando se tenga el dato):
--   - "Aguilera Duarte, Berna Betharran" (Noveno)
--   - "Aguilera Duarte, Xiomara Jeanette Eilen" y "Aguilera Duarte, Xiomara
--     Nathalie Eilen" (Primero BC — parecen mellizas)
--   - "Cabello Figler, Guilianna Jeanett" (Primero BTS)
--
-- "Valencia Guerrero, Victor Jose" (Noveno) tiene ci "26537015-2" en la planilla
-- original (formato distinto a una cédula típica) — se dejó tal cual, confirmado
-- como correcto.
--
-- Idempotente para alumnos/inscripciones: si un alumno ya existe (por `ci`) no se
-- recrea la cuenta, solo se asegura su inscripción; on conflict do nothing en
-- inscripciones. Los CURSOS y HORARIOS no son idempotentes (no hay UNIQUE en
-- cursos.nombre): si esta migración se corre dos veces, los cursos y horarios se
-- duplican. No volver a correr esta migración si ya se aplicó.

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
      "nombre": "(7º) Séptimo Curso",
      "alumnos": [
        {"nombre":"Elias Aaron","apellido":"Acosta Saavedra","ci":"7899209"},
        {"nombre":"Alfredo Anibal","apellido":"Aquino Franco","ci":"7666388"},
        {"nombre":"Santiago Gael","apellido":"Aveiro Arias","ci":"7953539"},
        {"nombre":"Marcos Daniel","apellido":"Ayala Duarte","ci":"7985856"},
        {"nombre":"Lucia Valentina","apellido":"Azopardo Dluzniewski","ci":"8543457"},
        {"nombre":"Mathias Enmanuel","apellido":"Balbuena Rodríguez","ci":"8025423"},
        {"nombre":"Valentina Abigail","apellido":"Benitez Franco","ci":"8200245"},
        {"nombre":"Kurt Matheo","apellido":"Bertrand Godoy","ci":"7847384"},
        {"nombre":"Carlos Abel","apellido":"Bogado Ortiz","ci":"7965795"},
        {"nombre":"Mariano Rafael","apellido":"Cabrera Godoy","ci":"8003604"},
        {"nombre":"Fausto Rafael","apellido":"Cano Cataldo","ci":"7711949"},
        {"nombre":"Cecilia Natali","apellido":"Castillo Arce","ci":"8045700"},
        {"nombre":"Sofia Victoria","apellido":"Castillo Miño","ci":"7965436"},
        {"nombre":"Brianna Adebel","apellido":"Corvalan Gauto","ci":"7955163"},
        {"nombre":"Paula Nicoli","apellido":"De Castro Fariña","ci":"7954088"},
        {"nombre":"Nicole Nazarenha","apellido":"Flores Estigarribia","ci":"7761322"},
        {"nombre":"Thiago Daniel","apellido":"Gamarra Franco","ci":"7571843"},
        {"nombre":"Maia Fernanda","apellido":"Garcia Escobar","ci":"7672667"},
        {"nombre":"Darmy Rossana","apellido":"Gimenez Miranda","ci":"8141790"},
        {"nombre":"Arturo Benjamin","apellido":"Gomez Melgarejo","ci":"7663784"},
        {"nombre":"Maria Ines","apellido":"Guillén Dávalos","ci":"7520281"},
        {"nombre":"Milagros Araceli","apellido":"Jara Peralta","ci":"8167994"},
        {"nombre":"Holder Alexander","apellido":"Kennedy Cardozo","ci":"7552534"},
        {"nombre":"Jorge Sebastian","apellido":"Martinez Gonzalez","ci":"7757587"},
        {"nombre":"Renzo Gael","apellido":"Medina Gimenez","ci":"8106471"},
        {"nombre":"Mathias Amir","apellido":"Mendez Godoy","ci":"7724530"},
        {"nombre":"Dante Emanuel","apellido":"Mendoza Godoy","ci":"7492572"},
        {"nombre":"Luana Gissell","apellido":"Mendoza Villasanti","ci":"7529226"},
        {"nombre":"Fabian","apellido":"Moran Cabrera","ci":"7473359"},
        {"nombre":"Maximiliano David","apellido":"Morel Fernandez","ci":"7670469"},
        {"nombre":"Gerardo Matheo","apellido":"Ortiz Torres","ci":"7499724"},
        {"nombre":"Ian Gael","apellido":"Palmerola Gonzalez","ci":"8167922"},
        {"nombre":"Gaspar","apellido":"Panotto Bauducco","ci":"7410886"},
        {"nombre":"Maria Fernanda","apellido":"Paredes Contrera","ci":"7742600"},
        {"nombre":"Milena Monserrat","apellido":"Pattenden Paredes","ci":"8121056"},
        {"nombre":"Santiago Nicolás","apellido":"Saiz Butterworth","ci":"7874892"},
        {"nombre":"Santiago Rafael","apellido":"Servin Mendoza","ci":"7597122"},
        {"nombre":"Ana Paula","apellido":"Silguero Alegre","ci":"7847316"},
        {"nombre":"Lujan Abigail","apellido":"Vera Flores","ci":"7815027"},
        {"nombre":"Emma Alessandra","apellido":"Villalba Galeano","ci":"7884730"},
        {"nombre":"Zaira Carolina","apellido":"Zena Saldivar","ci":"7542714"}
      ]
    },
    {
      "nombre": "(8º) Octavo Curso",
      "alumnos": [
        {"nombre":"Hellen Abigahl","apellido":"Bedoya Bareiro","ci":"7604803"},
        {"nombre":"Mildret Maximiliano","apellido":"Benítez Giménez","ci":"7593742"},
        {"nombre":"Alma Abigahl","apellido":"Cáceres Coronel","ci":"7234293"},
        {"nombre":"Luana Lisette","apellido":"Cano Cuenca","ci":"7411578"},
        {"nombre":"Adriana Belén","apellido":"Casco Recalde","ci":"7183290"},
        {"nombre":"Josías Emanuel","apellido":"Coronel Samudio","ci":"8241115"},
        {"nombre":"Jesús Eleazar","apellido":"Duarte Silva","ci":"7766756"},
        {"nombre":"Diana Katherine","apellido":"Elizeche Duarte","ci":"7592983"},
        {"nombre":"Sara Abigahl","apellido":"Ferreira Ortíz","ci":"7331768"},
        {"nombre":"Facundo Jesús","apellido":"Ferreira Rojas","ci":"7535535"},
        {"nombre":"Lucas Javier","apellido":"Figueredo Núñez","ci":"8056346"},
        {"nombre":"Sofia Ayelén","apellido":"Gamarra Franco","ci":"7347272"},
        {"nombre":"Fiorella Montserrat","apellido":"Godoy Molinas","ci":"7324254"},
        {"nombre":"Martina Luján","apellido":"Ledesma Bareiro","ci":"7493551"},
        {"nombre":"Lucas Emmanuel","apellido":"Martínez Carballo","ci":"8540941"},
        {"nombre":"Nicolás Samuel","apellido":"Martínez Guillén","ci":"7909992"},
        {"nombre":"Facundo Rafael","apellido":"Patiño González","ci":"7499598"},
        {"nombre":"Amir Santiago","apellido":"Portillo Chávez","ci":"7857690"},
        {"nombre":"Victor Jesús","apellido":"Ríos","ci":"7481287"},
        {"nombre":"Maria Cecilia","apellido":"Samudio Franco","ci":"7664791"},
        {"nombre":"Jesús José David","apellido":"Segovia Paredes","ci":"7359735"},
        {"nombre":"Thiago Alexander","apellido":"Segovia Segovia","ci":"7461289"},
        {"nombre":"Ian Santiago","apellido":"Vera Peña","ci":"7912838"},
        {"nombre":"Raúl Emiliano","apellido":"Villalba Servián","ci":"7899199"}
      ]
    },
    {
      "nombre": "(9º) Noveno Curso",
      "alumnos": [
        {"nombre":"Vanina Sophia","apellido":"Acosta Samudio","ci":"7828356"},
        {"nombre":"Maximiliano Javier","apellido":"Avalos Osorio","ci":"7445769"},
        {"nombre":"Fiorella Yeruti","apellido":"Baez Brizuela","ci":"7524688"},
        {"nombre":"Alam Jonás","apellido":"Castillo Benítez","ci":"7115022"},
        {"nombre":"Julio Bautista","apellido":"Chávez Prieto","ci":"7288530"},
        {"nombre":"Bruno Israel","apellido":"Diaz Segovia","ci":"7283468"},
        {"nombre":"Fernando","apellido":"Franco Aquino","ci":"7507843"},
        {"nombre":"Zoe Nicole","apellido":"Goiris Ledesma","ci":"7593777"},
        {"nombre":"Kevin Ramón","apellido":"Gómez Barrios","ci":"7058149"},
        {"nombre":"Victor Manuel","apellido":"Gonzalez Gavilan","ci":"7372503"},
        {"nombre":"Yanina Fiorella","apellido":"Méndez Godoy","ci":"7666931"},
        {"nombre":"Alexis Josué","apellido":"Ortíz Murray","ci":"7154840"},
        {"nombre":"Diego Armando","apellido":"Ortíz Recalde","ci":"7181999"},
        {"nombre":"Iker Abel","apellido":"Palmerola Gonzalez","ci":"9403866"},
        {"nombre":"Felipe Agustín","apellido":"Ramoa Durli","ci":"7330150"},
        {"nombre":"Dylan Josué","apellido":"Reyes Escobar","ci":"7217145"},
        {"nombre":"Micaela Arami","apellido":"Rojas Gonzalez","ci":"7321971"},
        {"nombre":"José Giovanni","apellido":"Rolón Ávalos","ci":"7461610"},
        {"nombre":"Zoe Luana","apellido":"Rolón Coronel","ci":"7150507"},
        {"nombre":"Luciana Camila","apellido":"Romero Curtido","ci":"7349337"},
        {"nombre":"Fiorella Nicole","apellido":"Romero Dávalos","ci":"7478939"},
        {"nombre":"Emma Martina","apellido":"Salgueiro Ortega","ci":"7225419"},
        {"nombre":"Stiven Sebastián","apellido":"Sanabria Domínguez","ci":"7188936"},
        {"nombre":"Kimey Annabella","apellido":"Silva Gonzalez","ci":"7636401"},
        {"nombre":"Luis Ramiro","apellido":"Sosa Smith","ci":"7221732"},
        {"nombre":"Camila Agustina","apellido":"Torales Aranda","ci":"7259892"},
        {"nombre":"Thiago Santino","apellido":"Urunaga Garcete","ci":"7115059"},
        {"nombre":"Victor Jose","apellido":"Valencia Guerrero","ci":"26537015-2"},
        {"nombre":"Mauricio Iván","apellido":"Vargas González","ci":"7737159"},
        {"nombre":"David Sebastián","apellido":"Vázquez Garcete","ci":"7398127"},
        {"nombre":"Sebastián Nahuel","apellido":"Villalba Centurión","ci":"7980244"}
      ]
    },
    {
      "nombre": "(1º) Primer Curso-BC",
      "alumnos": [
        {"nombre":"Oscar David","apellido":"Amarilla Ortiz","ci":"7061426"},
        {"nombre":"Bruno Javier","apellido":"Avalos Osorio","ci":"6940928"},
        {"nombre":"Rania","apellido":"Bartomeu Rios","ci":"6779021"},
        {"nombre":"Ricardo Alexander","apellido":"Becker Fox","ci":"7389566"},
        {"nombre":"Douglas Josue","apellido":"Dickel Fox","ci":"7157024"},
        {"nombre":"Elsa Marianela","apellido":"Duarte Barreto","ci":"7966846"},
        {"nombre":"Enzo Andrés","apellido":"Duarte Florentín","ci":"7023067"},
        {"nombre":"Ruth Florencia","apellido":"Florentín Aguilera","ci":"6978619"},
        {"nombre":"Juan Luis","apellido":"Gomez Duarte","ci":"7626666"},
        {"nombre":"Evelin Carolina","apellido":"Gomez Meza","ci":"6932605"},
        {"nombre":"Paula Luján","apellido":"Isasi Martínez","ci":"7958117"},
        {"nombre":"Thiago José","apellido":"Lezcano Santacruz","ci":"7041332"},
        {"nombre":"Jimmy Patricio","apellido":"Lopez Ramirez","ci":"7194820"},
        {"nombre":"Mathías Benjamín","apellido":"López Ruiz Díaz","ci":"6959673"},
        {"nombre":"Jorge David","apellido":"Martinez Gonzalez","ci":"7426537"},
        {"nombre":"Mathias David","apellido":"Ovelar Franco","ci":"7115598"},
        {"nombre":"Elias Maximiliano","apellido":"Ramirez Gonzalez","ci":"7010609"},
        {"nombre":"Mirian Sofía","apellido":"Ramírez Recalde","ci":"7017636"},
        {"nombre":"Ian Samuel","apellido":"Serrati Martínez","ci":"6848215"}
      ]
    },
    {
      "nombre": "(2º) Segundo Curso-BC",
      "alumnos": [
        {"nombre":"Franco Sebastian","apellido":"Barrios Invernizzi","ci":"7095710"},
        {"nombre":"Milagros Maria Luana","apellido":"Benitez Santos","ci":"7077528"},
        {"nombre":"Viviana Jazmín","apellido":"Cárdenas Villalba","ci":"6604746"},
        {"nombre":"Antonio Alejandro","apellido":"Castillo Arce","ci":"7050294"},
        {"nombre":"Armando De Jesus","apellido":"Chamorro Mendoza","ci":"7268802"},
        {"nombre":"Xiomara Maribel","apellido":"Diaz De Vivar Torales","ci":"7024285"},
        {"nombre":"Milagros Araceli","apellido":"Encina Ovando","ci":"7325402"},
        {"nombre":"Cielo Jazmín","apellido":"Flor Barreto","ci":"8055701"},
        {"nombre":"Pablo Rafael","apellido":"Galeano Ferreira","ci":"7063739"},
        {"nombre":"Enzo David","apellido":"Kim Aquino","ci":"6910684"},
        {"nombre":"Jose Manuel","apellido":"Mendoza Sanchez","ci":"6663479"},
        {"nombre":"Alan Samir","apellido":"Mereles Galeaño","ci":"6975745"},
        {"nombre":"Lucas Giovani","apellido":"Miranda Burgos","ci":"7277122"},
        {"nombre":"Cauam Cleber","apellido":"Potulski Ramos","ci":"6921093"},
        {"nombre":"Pío Uriel","apellido":"Ramos Santacruz","ci":"7371434"},
        {"nombre":"Mia Fiorella","apellido":"Rodriguez Varela","ci":"6772662"},
        {"nombre":"Luana Maylem","apellido":"Saiz Butterworth","ci":"6691177"},
        {"nombre":"Jesus Sebastian","apellido":"Santos Garcete","ci":"8003646"},
        {"nombre":"Mateo Luis","apellido":"Serrati Martinez","ci":"6853463"},
        {"nombre":"Yamila Ayelen","apellido":"Silva Godoy","ci":"6588792"},
        {"nombre":"Silvio Manuel","apellido":"Thompson Quiñonez","ci":"6538346"},
        {"nombre":"Ximena Alexandra","apellido":"Villalba Bogado","ci":"7534438"}
      ]
    },
    {
      "nombre": "(3º) Tercer Curso-BC",
      "alumnos": [
        {"nombre":"Adalberto Nicolas","apellido":"Britos Lopez","ci":"7625254"},
        {"nombre":"Mariam Fiorella","apellido":"Burgos Ayala","ci":"6175681"},
        {"nombre":"Gilberto Matias","apellido":"Caballero Cáceres","ci":"6853564"},
        {"nombre":"Mateo Constantino","apellido":"Chávez Martínez","ci":"7263199"},
        {"nombre":"Cecilia Anahí","apellido":"Duarte Martínez","ci":"6571742"},
        {"nombre":"Gloria Antonella","apellido":"Dure Barrientos","ci":"8363500"},
        {"nombre":"Fernando Rafael","apellido":"Espinola Penayo","ci":"6567367"},
        {"nombre":"Sofia Lujan","apellido":"Fabio Vera","ci":"6297965"},
        {"nombre":"Emanuel","apellido":"Fernandez Servin","ci":"6821736"},
        {"nombre":"Cecilia Montserrat","apellido":"Franco Rojas","ci":"7067944"},
        {"nombre":"Cesar Gabriel","apellido":"Frutos Mereles","ci":"7156859"},
        {"nombre":"Blas Antonio","apellido":"Godoy Duarte","ci":"6201034"},
        {"nombre":"Juan Carlos","apellido":"Gonzalez Ayala","ci":"6228949"},
        {"nombre":"Milagros Ayelen","apellido":"Medina Giménez","ci":"6849723"},
        {"nombre":"Milagros Beatriz","apellido":"Mendoza Villalba","ci":"6306582"},
        {"nombre":"Dahiana Lujan","apellido":"Roa Aguirre","ci":"6781718"},
        {"nombre":"Adolfo Israel","apellido":"Rojas Roman","ci":"7098814"},
        {"nombre":"Valeria Alejandra","apellido":"Sanchez Castillo","ci":"6257271"},
        {"nombre":"Lucas Eduardo","apellido":"Santacruz Garcete","ci":"7742068"},
        {"nombre":"Ana Valentina","apellido":"Silguero Alegre","ci":"7837839"},
        {"nombre":"Juan Manuel","apellido":"Varela Vázquez","ci":"7295252"},
        {"nombre":"Enrique","apellido":"Villagra Vázquez","ci":"6315284"},
        {"nombre":"Felix Andrés","apellido":"Yinde Rojas","ci":"6867014"}
      ]
    },
    {
      "nombre": "(1º) Primer Curso-BTS",
      "alumnos": [
        {"nombre":"Luna Mariel","apellido":"Alfonzo Prieto","ci":"7903449"},
        {"nombre":"Celso Alejandro","apellido":"Burgos Miltos","ci":"7849410"},
        {"nombre":"Valentina Antonia","apellido":"Castillo Míno","ci":"7965431"},
        {"nombre":"Iris Monserrat","apellido":"Mendoza Villalba","ci":"6925958"},
        {"nombre":"Giuliana Fiorella","apellido":"Ramirez Martínez","ci":"6724114"},
        {"nombre":"José Osvaldo","apellido":"Rivas Franco","ci":"7654273"},
        {"nombre":"Génesis Victoria","apellido":"Rodríguez Suárez","ci":"7215933"},
        {"nombre":"Valentina Aylen","apellido":"Sanabria Caceres","ci":"6847796"}
      ]
    }
  ]'::jsonb;
begin
  for v_curso in select * from jsonb_array_elements(v_cursos)
  loop
    insert into public.cursos (nombre)
    values (v_curso->>'nombre')
    returning id into v_curso_id;

    -- Horarios Lunes a Viernes 07:15-11:15, turno Matutino, docente Edmundo López
    insert into public.horarios (profesor_id, curso_id, dia_semana, hora_inicio, hora_fin, turno)
    select
      '327bcb06-1601-48a8-8a5a-53c676703aa5'::uuid, v_curso_id, dia, time '07:15', time '11:15', 'Matutino'
    from unnest(array['Lunes','Martes','Miercoles','Jueves','Viernes']) as dia;

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
