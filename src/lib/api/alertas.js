// Alertas de inasistencia (función SQL de 0011_alertas_inasistencia.sql).
// RLS decide qué alumnos ve cada usuario.

import { supabase } from '@/lib/supabase'

export const UMBRAL_PORCENTAJE = 75
export const FALTAS_SEGUIDAS = 3

// Por defecto: los últimos 30 días hasta hoy.
export async function alumnosEnRiesgo({ desde, hasta }) {
  const { data, error } = await supabase.rpc('alumnos_en_riesgo', {
    p_desde: desde,
    p_hasta: hasta,
    p_umbral_pct: UMBRAL_PORCENTAJE,
    p_faltas_seguidas: FALTAS_SEGUIDAS,
  })
  if (error) throw error
  return data || []
}

// Motivos legibles de una alerta.
export function motivosRiesgo(fila) {
  const motivos = []
  if (Number(fila.faltas_seguidas) >= FALTAS_SEGUIDAS) {
    motivos.push(`${fila.faltas_seguidas} faltas seguidas`)
  }
  if (fila.porcentaje !== null && Number(fila.porcentaje) < UMBRAL_PORCENTAJE) {
    motivos.push(`${Math.round(Number(fila.porcentaje))}% de asistencia`)
  }
  return motivos
}
