import { supabase } from '@/lib/supabase'

// Cursos visibles para el usuario: admin ve todos; un docente, los que tiene
// en sus horarios (RLS igual filtra, esto es para armar el selector).
export async function cursosDelUsuario({ esAdmin, profesorId }) {
  if (esAdmin) {
    const { data, error } = await supabase.from('cursos').select('id, nombre').order('nombre')
    if (error) throw error
    return data || []
  }
  if (!profesorId) return []
  const { data, error } = await supabase
    .from('horarios')
    .select('cursos (id, nombre)')
    .eq('profesor_id', profesorId)
  if (error) throw error
  const vistos = new Set()
  return (data || [])
    .map((h) => h.cursos)
    .filter((c) => c && !vistos.has(c.id) && vistos.add(c.id))
    .sort((a, b) => a.nombre.localeCompare(b.nombre))
}
