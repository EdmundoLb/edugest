// PostgREST (Supabase) devuelve como máximo 1000 filas por consulta y corta
// el resto en silencio. Para consultas que pueden superar ese límite, se
// pide de a páginas con .range() hasta que una venga incompleta.
// `crearConsulta` tiene que devolver un query builder nuevo en cada llamada
// (un builder ya ejecutado no se puede reutilizar).

const TAMANO_PAGINA = 1000

export async function traerTodo(crearConsulta) {
  const filas = []
  for (let desde = 0; ; desde += TAMANO_PAGINA) {
    const { data, error } = await crearConsulta().range(desde, desde + TAMANO_PAGINA - 1)
    if (error) throw error
    filas.push(...(data || []))
    if (!data || data.length < TAMANO_PAGINA) return filas
  }
}
