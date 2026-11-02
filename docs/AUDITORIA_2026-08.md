# Auditoría 2026-08: hallazgos y estado

Registro de la auditoría de seguridad/correctitud hecha en agosto de 2026. Sirve para que una auditoría futura no vuelva a gastar tiempo redescubriendo lo mismo, y para saber qué quedó pendiente a propósito.

**Metodología**: lectura completa del frontend (todas las vistas, router, store de auth) contra el esquema SQL provisto, más introspección directa de la base real vía scripts de solo lectura pegados en el SQL Editor de Supabase (no había ni CLI ni MCP de Supabase conectado — ver `docs/BASE_DE_DATOS.md` para los scripts). Después de aplicar los fixes, se probó el flujo completo con Chrome real (extensión `claude-in-chrome`): login de los 3 roles, tomar asistencia, ver reportes — eso encontró 2 bugs que el análisis estático no había detectado (ver más abajo).

## Hallazgos críticos — corregidos

1. **`alumnos` legible por cualquiera, sin login.** La policy RLS `"Anyone can view alumnos"` tenía `using: true` para el rol `public`. Cualquiera con la anon key (pública, está en el bundle del frontend) podía leer CI, dirección, fecha de nacimiento e historial académico de todos los alumnos, sin autenticarse. **Fix**: políticas RLS reales en `alumnos` (propio / admin / docente con alumno inscripto en su curso), restringidas a `authenticated`. Ver `docs/BASE_DE_DATOS.md`.
2. **Cualquier usuario podía auto-ascenderse a `admin`.** La policy de `UPDATE` en `perfiles` permitía a un usuario autenticado modificar su propia fila sin restringir qué columnas podía cambiar — `update perfiles set rol='admin' where id=auth.uid()` funcionaba desde la consola del navegador. Sumado a que la policy de `SELECT` también era pública (`"Anyone can view perfiles"`, `using: true`), exponía nombre/teléfono/rol de todos. **Fix**: políticas RLS reales + trigger `prevent_self_privilege_escalation` que revierte cualquier cambio a `rol`/`activo` que no venga de un admin.
3. **`asistencia` legible y escribible por cualquiera, sin login.** Policy `"Professors can manage asistencia"` cubría `ALL` (select/insert/update/delete) para `public` con `using: true` — el nombre sugería restricción por profesor, la condición real no filtraba nada. Cualquiera podía leer, crear, modificar o borrar asistencia de cualquier alumno/curso. **Fix**: políticas separadas por operación, restringidas a admin o al docente dueño del horario correspondiente.

## Hallazgos altos — corregidos

4. **`/admin` sin restricción de rol en el router.** Le faltaba `meta.rol: 'admin'` — cualquier usuario autenticado (estudiante o docente) podía navegar a `/admin` y ver estadísticas globales y los últimos registros de asistencia de todos los cursos.
5. **FK `horarios.curso_id` apuntaba a `profesores(id)` en vez de `cursos(id)`.** Confirmado contra la base real (no era un error de transcripción del esquema). Rompía silenciosamente cualquier embed de PostgREST `cursos(...)` a través de `horarios`.
6. **`cursos` no tenía ninguna policy RLS.** Con RLS activo y cero políticas, el acceso queda denegado por defecto para todos (admin incluido) — rompía cualquier consulta que necesitara el nombre de un curso.
7. **Alta de docentes rota.** El trigger `handle_new_user` solo creaba la fila en `alumnos` cuando el rol era estudiante; para `docente` no hacía nada, así que cualquiera que se registrara como docente quedaba con un login válido pero sin fila en `profesores`, bloqueado permanentemente ("No se encontró un docente asociado a este perfil"). Sumado a que `RegistroUsuarios.vue` hacía además un `insert` manual a `perfiles` con una columna `email` que no existe en esa tabla (fallaba siempre). **Fix**: trigger actualizado con rama docente + insert manual eliminado (ya es redundante, el trigger hace todo).

## Hallazgos medios — corregidos

8. **`asistencia` no tenía el `UNIQUE(horario_id, alumno_id, fecha)` que el `upsert` de `LlamarLista.vue` necesita** (`onConflict: 'horario_id,alumno_id,fecha'`). Sin ese constraint, Postgres tira `42P10` en cada guardado, o silenciosamente inserta duplicados en vez de sobrescribir.
9. **No existía relación `alumnos` ↔ `cursos`.** El código de `LlamarLista.vue` ya asumía un embed `cursos → alumnos` que nunca tuvo soporte en el esquema (ni columna `curso_id` en `alumnos`, ni tabla intermedia). Se creó `inscripciones`.
10. **Nada impedía (a nivel de base) que un docente marcara asistencia de un curso que no dicta.** La UI sí filtraba, pero llamando la API directo no había ninguna restricción real. Cerrado por las policies de escritura en `asistencia` (requieren ser dueño del horario, vía `docente_dicta_curso`/join con `horarios`).

## Hallazgos bajos — corregidos

11. `.env` no estaba en `.gitignore` (solo `*.local`). Agregado `.env` + `.env.*` (con excepción de `.env.example`).

## Bugs encontrados recién al probar en vivo (no visibles en el análisis estático)

12. **Recursión infinita entre las policies de `horarios` e `inscripciones`.** Cada una consultaba la tabla de la otra directamente dentro de su propio `using`, así que Postgres entraba en loop evaluando una contra la otra (`42P17: infinite recursion detected in policy for relation "inscripciones"`). Rompía `/admin` (conteos en 0 o error 500/503) y el login de estudiantes (colgado indefinidamente en "Ingresando..."). Encontrado recién al testear en Chrome real después de aplicar la primera tanda de RLS — el error solo aparece al ejecutar la query, no es visible leyendo el SQL de una policy aislada. **Fix**: migración `0002_fix_recursion_rls.sql`, funciones `SECURITY DEFINER` que cortan el ciclo (ver `docs/BASE_DE_DATOS.md`, sección RLS).
13. **Fechas corridas un día según la zona horaria del navegador.** `new Date().toISOString().split('T')[0]` (para "hoy") y `new Date("YYYY-MM-DD")` (para mostrar una fecha guardada) operan en UTC; combinados con `toLocaleDateString()` en la zona local del navegador, una fecha guardada como `2026-08-10` se mostraba como "domingo 9 de agosto" en vez de "lunes 10". Afectaba `LlamarLista.vue` (fecha por defecto), `MiAsistencia.vue`, `MisReportes.vue` y `AdminDashboard.vue`. **Fix**: `src/lib/fecha.js` (`hoyLocal`, `parseFechaLocal`, `formatearFecha`), usado en los 4 lugares.
14. **`LlamarLista.vue` nunca marcaba "Presente" por defecto en la primera pasada de lista.** `asistenciaExistente` (resultado de un `select`) es siempre un array, aunque esté vacío — el `if (asistenciaExistente)` de la lógica original era `true` incluso sin registros previos, así que la rama que default-marca presente a todos nunca corría. Corregido a `if (asistenciaExistente && asistenciaExistente.length > 0)`.

## Hallazgos posteriores (revisión 2026-10)

15. **Cuentas de alumnos importados con contraseña fija y pública.** Las migraciones 0003, 0006 y 0007 crean ~200 cuentas `<ci>@alumno.ccg.local` con contraseña `Prueba123!` (escrita en el repo). Cualquiera que sepa la cédula de un alumno puede iniciar sesión como él; RLS le deja ver su asistencia y **modificar su propia fila de `alumnos`, incluido `telefono_padre`**, que es el número al que administración manda los avisos por WhatsApp. **Fix propuesto**: `0010_seguridad_cuentas_alumnos.sql` (contraseña aleatoria). No se aplicó: hay que decidir si algún alumno real usa esas cuentas. Además, conviene restringir en RLS qué columnas de `alumnos` puede editar el propio alumno (hoy puede editar todas, incluida `ci`).
16. **Reportes truncados en silencio a 1000 filas** (límite por defecto de PostgREST) en `MisReportes.vue`. **Fix**: paginación (`src/lib/paginar.js`) y agregación en SQL (`0008_reportes.sql`).
17. **"¿Olvidaste tu contraseña?" llevaba a una ruta inexistente** (`/reset-password`). **Fix**: vista `RestablecerContrasena.vue`. Requiere agregar `<url-de-la-app>/reset-password` en Supabase → Authentication → URL Configuration → Redirect URLs.
18. **Migraciones 0002 y 0004 sobrescritas por error** en el working tree (contenían un `git clone` y una lista de nombres). Restauradas desde git.
19. **`perfiles.activo` no se usa en ningún lado**: ninguna policy ni el frontend lo consultan, así que "desactivar" un usuario no tendría efecto. **Corregido en 0013**: `is_admin()`/`current_*_id()`/`tutor_de_alumno()` lo tienen en cuenta y el router/login muestran "cuenta pendiente de aprobación".
20. **(Crítico, 2026-11) Cualquiera podía registrarse como admin.** `handle_new_user` copiaba `raw_user_meta_data->>'rol'` sin validar, así que un `supabase.auth.signUp({..., options: { data: { rol: 'admin' } } })` hecho a mano (con la anon key pública) creaba un perfil admin con acceso total. **Fix**: 0013 solo acepta `estudiante`/`docente`/`tutor`. Al 2026-11-01 la base tenía 1 solo admin (el legítimo).

## Pendiente / a criterio del equipo (no se tocó)

- ~~**No hay UI de administración** para cursos, horarios e inscripciones~~ — resuelto en 2026-10: `/admin/cursos` (ver `src/views/admin/`).
- **Política de contraseña** sigue en mínimo 6 caracteres (default de Supabase Auth). No se subió porque no se pidió explícitamente.
- ~~**Alta pública de docentes sin aprobación**~~ — resuelto en 0013: el docente que se registra solo queda con `activo = false` y lo aprueba un admin desde `/admin` (`CuentasPendientes.vue`). Texto original: cualquiera puede autoregistrarse como `docente` desde `/Registro` y queda con acceso inmediato a las pantallas de docente (aunque sin horarios asignados, así que no puede tomar asistencia de nada hasta que un admin le asigne un curso a mano). Si el negocio requiere aprobación previa de un admin antes de habilitar una cuenta docente, es una funcionalidad nueva, no un bug — no se implementó porque no se definió el flujo de aprobación deseado.
- **Columnas `profesores.create_at` / `profesores.undated_at`** tienen un typo en el nombre desde el esquema original. No se renombraron para no romper nada que ya las use; si se corrige alguna vez, hacerlo en una migración dedicada y actualizar todo el código que las referencia.
