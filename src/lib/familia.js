// Resumen de un hijo para la tarjeta del portal de familias. Recibe los días
// del mes ya combinados (combinarPorDia), del más nuevo al más viejo.

import { contar, resumirPorCurso } from '@/lib/historial'

export function resumirHijo(dias, hoy) {
  const porCurso = resumirPorCurso(dias)
  return {
    ...contar(dias),
    hoy: dias
      .filter((d) => d.fecha === hoy)
      .map(({ cursoId, cursoNombre, estado, observacion }) => ({
        cursoId,
        cursoNombre,
        estado,
        observacion,
      })),
    faltasSeguidas: Math.max(0, ...porCurso.map((c) => c.faltasSeguidas)),
    ultimaClase: dias[0]?.fecha ?? null,
  }
}
