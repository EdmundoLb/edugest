-- Reemplaza asistencia.presente (boolean) por asistencia.estado (varchar),
-- agregando un tercer estado 'justificado' además de 'presente'/'ausente'.
-- Sigue el mismo patrón de enum-por-CHECK que ya usan perfiles.rol,
-- horarios.dia_semana y horarios.turno (ver docs/BASE_DE_DATOS.md).

begin;

alter table public.asistencia add column estado varchar;

update public.asistencia
set estado = case when presente then 'presente' else 'ausente' end;

alter table public.asistencia alter column estado set not null;

alter table public.asistencia
  add constraint asistencia_estado_check check (estado in ('presente', 'ausente', 'justificado'));

alter table public.asistencia drop column presente;

commit;
