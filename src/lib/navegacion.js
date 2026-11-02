// Navegación de la app por rol: una sola fuente para la barra lateral
// (computadora), la barra inferior (celular) y la paleta de comandos (Ctrl+K).
// Funciones puras.

export const ROL_TEXTO = {
  estudiante: 'Estudiante',
  docente: 'Docente',
  admin: 'Administración',
  tutor: 'Familia',
}

const FAMILIAS_PERSONAL = {
  grupo: 'Familias',
  items: [
    {
      to: '/solicitudes',
      texto: 'Avisos de familias',
      corto: 'Avisos',
      icono: 'bandeja',
      badge: 'solicitudes',
    },
    { to: '/comunicados', texto: 'Comunicados', icono: 'comunicado' },
    { to: '/entrevistas', texto: 'Entrevistas', icono: 'chat' },
  ],
}

const REPORTES = {
  grupo: 'Reportes',
  items: [
    { to: '/Reportes/mensual', texto: 'Reporte mensual', corto: 'Reportes', icono: 'reportes' },
    { to: '/Reportes/institucional', texto: 'Resumen del mes', icono: 'actividad' },
    { to: '/MisReportes', texto: 'Asistencia por fecha', icono: 'documento' },
  ],
}

const MENU = {
  docente: [
    {
      grupo: 'Hoy',
      items: [
        { to: '/ProfesorDashboard', texto: 'Inicio', icono: 'inicio' },
        { to: '/LlamarLista', texto: 'Llamar lista', corto: 'Lista', icono: 'lista' },
        { to: '/calendario', texto: 'Calendario', icono: 'calendario' },
      ],
    },
    {
      grupo: 'Alumnos',
      items: [
        { to: '/MisCursos', texto: 'Mis cursos', icono: 'cursos' },
        { to: '/Estudiantes', texto: 'Alumnos', icono: 'alumnos' },
      ],
    },
    FAMILIAS_PERSONAL,
    REPORTES,
  ],
  admin: [
    {
      grupo: 'Hoy',
      items: [
        { to: '/admin', texto: 'Inicio', icono: 'inicio' },
        { to: '/calendario', texto: 'Calendario', icono: 'calendario' },
      ],
    },
    {
      grupo: 'Gestión',
      items: [
        { to: '/admin/cursos', texto: 'Cursos', icono: 'cursos' },
        { to: '/Estudiantes', texto: 'Alumnos', icono: 'alumnos' },
        { to: '/InformesAsistencia', texto: 'Informes', icono: 'documento' },
      ],
    },
    FAMILIAS_PERSONAL,
    REPORTES,
  ],
  tutor: [
    {
      grupo: 'Familia',
      items: [
        { to: '/familia', texto: 'Mis hijos', corto: 'Hijos', icono: 'familia' },
        {
          to: '/familia/comunicados',
          texto: 'Comunicados',
          icono: 'comunicado',
          badge: 'comunicados',
        },
        { to: '/familia/entrevistas', texto: 'Entrevistas', icono: 'chat' },
        { to: '/calendario', texto: 'Calendario', icono: 'calendario' },
        { to: '/familia/vincular', texto: 'Vincular alumno', corto: 'Vincular', icono: 'enlace' },
      ],
    },
  ],
  estudiante: [
    {
      grupo: 'Mi cuenta',
      items: [
        { to: '/MiAsistencia', texto: 'Mi asistencia', corto: 'Asistencia', icono: 'actividad' },
        { to: '/calendario', texto: 'Calendario', icono: 'calendario' },
      ],
    },
  ],
}

// Destinos fijos de la barra inferior del celular (el resto va en "Más").
const INFERIOR = {
  docente: ['/ProfesorDashboard', '/LlamarLista', '/Estudiantes', '/solicitudes'],
  admin: ['/admin', '/admin/cursos', '/Estudiantes', '/solicitudes'],
  tutor: ['/familia', '/familia/comunicados', '/familia/entrevistas', '/calendario'],
  estudiante: ['/MiAsistencia', '/calendario'],
}

export function menuPorRol(rol) {
  return MENU[rol] ?? []
}

export function entradasPorRol(rol) {
  return menuPorRol(rol).flatMap((g) => g.items.map((item) => ({ ...item, grupo: g.grupo })))
}

export function barraInferior(rol) {
  const todas = entradasPorRol(rol)
  const fijas = INFERIOR[rol] ?? []
  return {
    principales: fijas.map((to) => todas.find((e) => e.to === to)).filter(Boolean),
    resto: todas.filter((e) => !fijas.includes(e.to)),
  }
}

// Un link queda activo en su ruta y sus subrutas, salvo que otro link del
// menú sea más específico (ej. /familia vs /familia/comunicados).
export function esRutaActiva(path, to, entradas) {
  if (path !== to && !path.startsWith(`${to}/`)) return false
  return !entradas.some(
    (e) => e.to !== to && e.to.startsWith(to) && (path === e.to || path.startsWith(`${e.to}/`)),
  )
}

// Sin tildes ni mayúsculas, para comparar texto escrito a mano.
export function normalizar(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
}

// Puntaje de coincidencia: empieza igual > alguna palabra empieza igual >
// contiene > letras en orden (subsecuencia). 0 = no coincide.
export function puntajeCoincidencia(texto, consulta) {
  const t = normalizar(texto)
  const q = normalizar(consulta)
  if (!q) return 1
  if (t.startsWith(q)) return 4
  if (t.split(/\s+/).some((p) => p.startsWith(q))) return 3
  if (t.includes(q)) return 2
  let i = 0
  for (const c of t) if (c === q[i]) i++
  return i === q.length ? 1 : 0
}

export function filtrarComandos(entradas, consulta) {
  return entradas
    .map((e) => ({
      e,
      p: Math.max(
        puntajeCoincidencia(e.texto, consulta),
        puntajeCoincidencia(e.grupo ?? '', consulta) > 2 ? 1 : 0,
      ),
    }))
    .filter((x) => x.p > 0)
    .sort((a, b) => b.p - a.p)
    .map((x) => x.e)
}
