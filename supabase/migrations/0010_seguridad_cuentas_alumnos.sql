-- =========================================================================
-- Migración: cerrar el acceso con contraseña fija de los alumnos importados
-- Sistema de Asistencia — Centro Cultural Gymmart
--
-- PROBLEMA:
--   Las importaciones 0003, 0006 y 0007 crearon las cuentas de los alumnos
--   con email <ci>@alumno.ccg.local y la contraseña fija 'Prueba123!' (que
--   además está escrita en el repositorio). Cualquiera que conozca la cédula
--   de un alumno puede iniciar sesión como él. Con esa sesión, RLS le permite
--   ver su asistencia y MODIFICAR SU PROPIA FILA de `alumnos` — incluido
--   `telefono_padre`, que es el número al que administración le manda los
--   avisos de asistencia por WhatsApp.
--
-- QUÉ HACE:
--   Reemplaza la contraseña de todas las cuentas @alumno.ccg.local por una
--   aleatoria que nadie conoce. Las cuentas siguen existiendo (se necesitan
--   para el FK de alumnos), los datos y la asistencia no se tocan; solo deja
--   de poder usarse 'Prueba123!' para entrar con ellas.
--
-- ANTES DE CORRERLA:
--   Si algún alumno real YA está usando su cuenta <ci>@alumno.ccg.local con
--   'Prueba123!' para ver su asistencia, va a dejar de poder entrar. Para
--   darle acceso habría que asignarle un email real y que use "¿Olvidaste tu
--   contraseña?" (o que se registre normalmente).
--
-- CÓMO EJECUTAR:
--   Supabase Dashboard -> SQL Editor -> pegar TODO este archivo -> Run.
--   Se puede correr más de una vez sin problema.
-- =========================================================================

begin;

update auth.users
set encrypted_password = extensions.crypt(
      encode(extensions.gen_random_bytes(32), 'base64'),
      extensions.gen_salt('bf')
    ),
    updated_at = now()
where email like '%@alumno.ccg.local';

commit;

-- =========================================================================
-- Verificación (solo lectura): cuántas cuentas de alumno importadas hay.
--   select count(*) from auth.users where email like '%@alumno.ccg.local';
-- =========================================================================
