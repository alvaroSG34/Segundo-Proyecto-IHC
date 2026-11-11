-- =============================================================================
-- UniSport · Base de datos compartida en Supabase (PostgreSQL)
--
-- Cómo usarlo: Supabase -> SQL Editor -> New query -> pegar TODO este archivo
-- -> Run. Se puede volver a ejecutar sin perder datos.
--
-- Las reglas de negocio se aplican aquí en el servidor (con los mismos mensajes
-- que lib/modelos/modelo_partido.dart), así se respetan aunque varios teléfonos
-- actúen al mismo tiempo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tablas
-- -----------------------------------------------------------------------------

-- Datos públicos de cada estudiante. El correo y la contraseña los guarda
-- Supabase Auth (tabla auth.users), con la contraseña cifrada.
create table if not exists public.perfiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  nombre           text not null,
  correo           text not null,
  carrera          text not null default 'Ingeniería',
  deporte_favorito text not null default 'Futsal',
  creado_en        timestamptz not null default now()
);

create table if not exists public.partidos (
  id                 uuid primary key default gen_random_uuid(),
  organizador_id     uuid not null references public.perfiles (id) on delete cascade,
  organizador_nombre text not null,
  titulo             text not null check (char_length(trim(titulo)) >= 3),
  disciplina         text not null,
  ubicacion          text not null,
  fecha_inicio       timestamptz not null,
  cupos_totales      int  not null check (cupos_totales between 2 and 30),
  cupos_ocupados     int  not null default 1,
  estado             text not null default 'cuposAbiertos'
                     check (estado in ('cuposAbiertos', 'equipoCompleto')),
  -- Columna calculada para poder filtrar "con cupos" desde la consulta
  hay_cupos          boolean generated always as (cupos_ocupados < cupos_totales) stored,
  creado_en          timestamptz not null default now(),
  check (cupos_ocupados between 0 and cupos_totales)
);

-- Quién se unió a qué partido (desde "Explorar")
create table if not exists public.inscripciones (
  partido_id     uuid not null references public.partidos (id) on delete cascade,
  jugador_id     uuid not null references public.perfiles (id) on delete cascade,
  jugador_nombre text not null,
  creado_en      timestamptz not null default now(),
  primary key (partido_id, jugador_id)
);

-- Suplentes en orden de llegada. El id creciente conserva el turno incluso
-- cuando varias personas se anotan casi al mismo tiempo.
create table if not exists public.lista_espera (
  id             bigint generated always as identity primary key,
  partido_id     uuid not null references public.partidos (id) on delete cascade,
  jugador_id     uuid not null references public.perfiles (id) on delete cascade,
  jugador_nombre text not null,
  creado_en      timestamptz not null default now(),
  unique (partido_id, jugador_id)
);

-- Eventos de analitica. La tabla no se expone directamente: las escrituras y
-- los conteos pasan por funciones que toman el usuario de la sesion.
create table if not exists public.eventos (
  id         bigint generated always as identity primary key,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  evento     text not null
             check (evento in ('union_iniciada', 'partido_unido')),
  props      jsonb not null default '{}'::jsonb,
  fecha      timestamptz not null default now(),
  check (jsonb_typeof(props) = 'object')
);
create index if not exists eventos_evento_fecha_idx
  on public.eventos(evento, fecha);

alter table public.eventos enable row level security;
revoke all on public.eventos from public, anon, authenticated;

create or replace function public.track(p_evento text, p_props jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
begin
  if v_usuario is null then
    raise exception 'Debes iniciar sesion para registrar eventos.';
  end if;
  if p_evento not in ('union_iniciada', 'partido_unido') then
    raise exception 'Evento de analitica no permitido.';
  end if;
  if p_props is null or jsonb_typeof(p_props) <> 'object' then
    raise exception 'Las propiedades del evento deben ser un objeto.';
  end if;

  insert into public.eventos(usuario_id, evento, props)
  values (v_usuario, p_evento, p_props);
end;
$$;

create or replace function public.obtener_resumen_analitica()
returns jsonb
language plpgsql
stable
security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
  v_iniciadas bigint;
  v_finalizadas bigint;
begin
  if v_usuario is null then
    raise exception 'Debes iniciar sesion para consultar la analitica.';
  end if;

  select
    count(*) filter (where evento = 'union_iniciada'),
    count(*) filter (where evento = 'partido_unido')
  into v_iniciadas, v_finalizadas
  from public.eventos;

  return jsonb_build_object(
    'uniones_iniciadas', v_iniciadas,
    'partidos_unidos', v_finalizadas
  );
end;
$$;

create or replace function public.obtener_eventos_analitica()
returns table(evento text, props jsonb, fecha timestamptz)
language plpgsql
stable
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesion para consultar la analitica.';
  end if;

  return query
  select e.evento, e.props, e.fecha
  from public.eventos e
  order by e.fecha desc, e.id desc;
end;
$$;

revoke all on function public.track(text, jsonb) from public, anon;
revoke all on function public.obtener_resumen_analitica() from public, anon;
revoke all on function public.obtener_eventos_analitica() from public, anon;
grant execute on function public.track(text, jsonb) to authenticated;
grant execute on function public.obtener_resumen_analitica() to authenticated;
grant execute on function public.obtener_eventos_analitica() to authenticated;

-- La plaza se conserva hasta que cada titular responda a una reprogramación.
alter table public.partidos
  add column if not exists reprogramacion_motivo text,
  add column if not exists reprogramacion_fecha_anterior timestamptz,
  add column if not exists reprogramacion_ubicacion_anterior text,
  add column if not exists reconfirmaciones_pendientes int not null default 0;
alter table public.inscripciones
  add column if not exists reconfirmacion_pendiente boolean not null default false,
  add column if not exists reconfirmacion_aceptada boolean not null default false;

create index if not exists partidos_fecha_idx on public.partidos (fecha_inicio);
create index if not exists partidos_organizador_idx on public.partidos (organizador_id);
create index if not exists inscripciones_jugador_idx on public.inscripciones (jugador_id);
create index if not exists lista_espera_partido_idx on public.lista_espera (partido_id, id);

-- -----------------------------------------------------------------------------
-- Al registrarse, se crea su perfil con los datos enviados desde la app
-- -----------------------------------------------------------------------------
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, correo, carrera, deporte_favorito)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'nombre', ''), split_part(new.email, '@', 1)),
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'carrera', ''), 'Ingeniería'),
    coalesce(nullif(new.raw_user_meta_data ->> 'deporte_favorito', ''), 'Futsal')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- -----------------------------------------------------------------------------
-- Seguridad por fila (RLS): cada usuario solo modifica lo suyo
-- -----------------------------------------------------------------------------
alter table public.perfiles      enable row level security;
alter table public.partidos      enable row level security;
alter table public.inscripciones enable row level security;
alter table public.lista_espera enable row level security;

drop policy if exists "perfiles: leer (con sesión)" on public.perfiles;
create policy "perfiles: leer (con sesión)" on public.perfiles
  for select to authenticated using (true);

drop policy if exists "perfiles: editar el propio" on public.perfiles;
create policy "perfiles: editar el propio" on public.perfiles
  for update to authenticated using (id = auth.uid());

drop policy if exists "partidos: leer (con sesión)" on public.partidos;
create policy "partidos: leer (con sesión)" on public.partidos
  for select to authenticated using (true);

drop policy if exists "partidos: crear como organizador" on public.partidos;
create policy "partidos: crear como organizador" on public.partidos
  for insert to authenticated
  with check (organizador_id = auth.uid() and cupos_ocupados = 1
              and estado = 'cuposAbiertos');

drop policy if exists "partidos: eliminar el propio" on public.partidos;
create policy "partidos: eliminar el propio" on public.partidos
  for delete to authenticated using (organizador_id = auth.uid());

-- No hay política de UPDATE en partidos ni de INSERT en inscripciones:
-- esos cambios solo se hacen mediante las funciones de abajo, que validan
-- las reglas de negocio.

drop policy if exists "inscripciones: leer (con sesión)" on public.inscripciones;
create policy "inscripciones: leer (con sesión)" on public.inscripciones
  for select to authenticated using (true);

drop policy if exists "lista de espera: leer (con sesión)" on public.lista_espera;
create policy "lista de espera: leer (con sesión)" on public.lista_espera
  for select to authenticated using (true);

-- -----------------------------------------------------------------------------
-- Funciones con las reglas de negocio (se llaman desde la app con rpc)
-- "for update" bloquea la fila del partido mientras dura la operación, así dos
-- teléfonos no pueden ocupar el mismo último cupo.
-- -----------------------------------------------------------------------------

-- Regla de unión (issues #2 y #7, requisito #5)
create or replace function public.unirse_a_partido(p_partido uuid)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_jugador uuid := auth.uid();
  v_partido public.partidos;
  v_nombre  text;
begin
  if v_jugador is null then
    raise exception 'Debes iniciar sesión para unirte.';
  end if;

  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then
    raise exception 'Este partido ya no existe.';
  end if;

  if v_partido.organizador_id = v_jugador or exists (
       select 1 from public.inscripciones
       where partido_id = p_partido and jugador_id = v_jugador) then
    raise exception 'Ya formas parte de este equipo.';
  end if;
  if exists (select 1 from public.lista_espera
             where partido_id = p_partido and jugador_id = v_jugador) then
    raise exception 'Ya estás en la lista de suplentes.';
  end if;
  if v_partido.fecha_inicio < now() then
    raise exception 'El partido ya se jugó: su fecha ya pasó.';
  end if;
  if v_partido.estado = 'equipoCompleto' then
    if v_partido.cupos_ocupados >= v_partido.cupos_totales then
      raise exception 'Convocatoria cerrada: el equipo ya está completo.';
    end if;
    raise exception 'Convocatoria cerrada por el organizador.';
  end if;
  if v_partido.cupos_ocupados >= v_partido.cupos_totales then
    raise exception 'Cupos agotados: se alcanzó el límite máximo de jugadores.';
  end if;

  select nombre into v_nombre from public.perfiles where id = v_jugador;
  insert into public.inscripciones (partido_id, jugador_id, jugador_nombre)
  values (p_partido, v_jugador, coalesce(v_nombre, ''));

  update public.partidos
     set cupos_ocupados = cupos_ocupados + 1,
         estado = case when cupos_ocupados + 1 >= cupos_totales
                       then 'equipoCompleto' else estado end
   where id = p_partido
  returning * into v_partido;

  return v_partido;
end;
$$;

-- Elimina la acción antigua que ocupaba cupos sin crear inscripciones.
drop function if exists public.agregar_jugador_sin_cuenta(uuid);

-- El organizador puede cerrar manualmente la convocatoria sin ocupar cupos.
create or replace function public.completar_equipo(p_partido uuid)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_partido public.partidos;
  v_jugador uuid := auth.uid();
begin
  if v_jugador is null then
    raise exception 'Debes iniciar sesión para cerrar la convocatoria.';
  end if;

  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then
    raise exception 'Este partido ya no existe.';
  end if;
  if v_partido.organizador_id <> v_jugador then
    raise exception 'Solo el organizador puede cerrar la convocatoria.';
  end if;
  if v_partido.fecha_inicio < now() then
    raise exception 'El partido ya se jugó: su fecha ya pasó.';
  end if;
  if v_partido.estado = 'equipoCompleto' then
    raise exception 'La convocatoria ya está cerrada.';
  end if;
  if v_partido.cupos_ocupados >= v_partido.cupos_totales then
    raise exception 'El equipo ya está completo.';
  end if;

  update public.partidos
     set estado = 'equipoCompleto'
   where id = p_partido
  returning * into v_partido;
  return v_partido;
end;
$$;

revoke all on function public.completar_equipo(uuid) from public, anon;

-- Organizador: editar datos del partido (regla de edición de cupos)
create or replace function public.editar_partido(
  p_partido       uuid,
  p_titulo        text,
  p_disciplina    text,
  p_ubicacion     text,
  p_fecha_inicio  timestamptz,
  p_cupos_totales int
)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_partido public.partidos;
begin
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found or v_partido.organizador_id <> auth.uid() then
    raise exception 'Solo el organizador puede editar el partido.';
  end if;

  if (p_fecha_inicio is distinct from v_partido.fecha_inicio
      or p_ubicacion is distinct from v_partido.ubicacion)
     and (v_partido.reconfirmaciones_pendientes > 0 or exists (
       select 1 from public.inscripciones where partido_id = p_partido
     )) then
    raise exception 'Usa Reprogramar para cambiar fecha o lugar y avisar al equipo.';
  end if;

  if p_cupos_totales <> v_partido.cupos_totales then
    if v_partido.estado = 'equipoCompleto' then
      raise exception 'El equipo ya está completo: no se pueden cambiar los cupos.';
    end if;
    if p_cupos_totales < v_partido.cupos_ocupados then
      raise exception 'No puedes dejar menos cupos (%) que jugadores inscritos (%).',
        p_cupos_totales, v_partido.cupos_ocupados;
    end if;
  end if;

  update public.partidos
     set titulo        = p_titulo,
         disciplina    = p_disciplina,
         ubicacion     = p_ubicacion,
         fecha_inicio  = p_fecha_inicio,
         cupos_totales = p_cupos_totales,
         estado = case when cupos_ocupados >= p_cupos_totales
                       then 'equipoCompleto' else estado end
   where id = p_partido
  returning * into v_partido;
  return v_partido;
end;
$$;

-- El organizador cambia fecha/hora o lugar. Una sola operación guarda el cambio
-- y marca pendientes a los titulares; sus cupos siguen ocupados.
create or replace function public.reprogramar_partido(
  p_partido uuid, p_fecha_inicio timestamptz, p_ubicacion text, p_motivo text
)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_partido public.partidos;
  v_pendientes int;
begin
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found or v_partido.organizador_id <> auth.uid() then
    raise exception 'Solo el organizador puede reprogramar el partido.';
  end if;
  if v_partido.fecha_inicio <= now() then
    raise exception 'No se puede reprogramar un partido que ya pasó.';
  end if;
  if v_partido.reconfirmaciones_pendientes > 0 then
    raise exception 'Espera las respuestas pendientes antes de volver a reprogramar.';
  end if;
  if p_fecha_inicio is null or p_fecha_inicio <= now() then
    raise exception 'La nueva fecha debe ser futura.';
  end if;
  if nullif(trim(p_ubicacion), '') is null or nullif(trim(p_motivo), '') is null then
    raise exception 'Indica el lugar y el motivo de la reprogramación.';
  end if;
  if p_fecha_inicio = v_partido.fecha_inicio and trim(p_ubicacion) = v_partido.ubicacion then
    raise exception 'Cambia la fecha, la hora o el lugar del partido.';
  end if;

  update public.inscripciones
     set reconfirmacion_pendiente = true, reconfirmacion_aceptada = false
   where partido_id = p_partido;
  get diagnostics v_pendientes = row_count;

  update public.partidos
     set fecha_inicio = p_fecha_inicio,
         ubicacion = trim(p_ubicacion),
         reprogramacion_motivo = trim(p_motivo),
         reprogramacion_fecha_anterior = v_partido.fecha_inicio,
         reprogramacion_ubicacion_anterior = v_partido.ubicacion,
         reconfirmaciones_pendientes = v_pendientes
   where id = p_partido
  returning * into v_partido;
  return v_partido;
end;
$$;

-- Cada respuesta es única. Al retirarse un titular, el primer suplente ocupa
-- su plaza y queda pendiente de confirmar la nueva fecha.
create or replace function public.responder_reprogramacion(p_partido uuid, p_acepta boolean)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_partido public.partidos;
  v_suplente public.lista_espera;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión para responder.';
  end if;
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then
    raise exception 'Este partido ya no existe.';
  end if;
  if v_partido.fecha_inicio <= now() then
    raise exception 'El partido ya se jugó: su fecha ya pasó.';
  end if;
  if not exists (
    select 1 from public.inscripciones
     where partido_id = p_partido and jugador_id = auth.uid()
       and reconfirmacion_pendiente
  ) then
    raise exception 'No tienes una reconfirmación pendiente.';
  end if;

  if p_acepta then
    update public.inscripciones
       set reconfirmacion_pendiente = false, reconfirmacion_aceptada = true
     where partido_id = p_partido and jugador_id = auth.uid();
    update public.partidos
       set reconfirmaciones_pendientes = reconfirmaciones_pendientes - 1
     where id = p_partido returning * into v_partido;
  else
    delete from public.inscripciones
     where partido_id = p_partido and jugador_id = auth.uid();
    select * into v_suplente from public.lista_espera
     where partido_id = p_partido order by id limit 1;
    if found then
      delete from public.lista_espera where id = v_suplente.id;
      insert into public.inscripciones
        (partido_id, jugador_id, jugador_nombre, reconfirmacion_pendiente)
      values (p_partido, v_suplente.jugador_id, v_suplente.jugador_nombre, true);
      -- Una respuesta pendiente sale y otra entra: el contador y el cupo no cambian.
    else
      update public.partidos
         set cupos_ocupados = cupos_ocupados - 1,
             reconfirmaciones_pendientes = reconfirmaciones_pendientes - 1,
             estado = case
               when v_partido.estado = 'equipoCompleto'
                    and v_partido.cupos_ocupados < v_partido.cupos_totales
                 then 'equipoCompleto'
               else 'cuposAbiertos'
             end
       where id = p_partido returning * into v_partido;
    end if;
  end if;
  return v_partido;
end;
$$;

-- Salir del partido (H3 Control y libertad): quien se unió puede retirarse
create or replace function public.salir_del_partido(p_partido uuid)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_jugador uuid := auth.uid();
  v_partido public.partidos;
  v_suplente public.lista_espera;
  v_estaba_pendiente boolean;
begin
  if v_jugador is null then
    raise exception 'Debes iniciar sesión para salir del partido.';
  end if;

  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then
    raise exception 'Este partido ya no existe.';
  end if;
  if v_partido.organizador_id = v_jugador then
    raise exception 'El organizador no puede salir de su propio partido: elimínalo si ya no se realizará.';
  end if;
  if not exists (select 1 from public.inscripciones
                 where partido_id = p_partido and jugador_id = v_jugador) then
    raise exception 'No formas parte de este equipo.';
  end if;
  if v_partido.fecha_inicio < now() then
    raise exception 'El partido ya se jugó: su fecha ya pasó.';
  end if;

  select reconfirmacion_pendiente into v_estaba_pendiente
    from public.inscripciones
   where partido_id = p_partido and jugador_id = v_jugador;

  delete from public.inscripciones
   where partido_id = p_partido and jugador_id = v_jugador;

  -- El bloqueo del partido mantiene el orden y evita ocupar dos veces el cupo.
  select * into v_suplente from public.lista_espera
   where partido_id = p_partido order by id limit 1;
  if found then
    delete from public.lista_espera where id = v_suplente.id;
    insert into public.inscripciones
      (partido_id, jugador_id, jugador_nombre, reconfirmacion_pendiente)
    values (p_partido, v_suplente.jugador_id, v_suplente.jugador_nombre,
            v_partido.reconfirmaciones_pendientes > 0);
    update public.partidos
       set reconfirmaciones_pendientes = reconfirmaciones_pendientes
           - case when v_estaba_pendiente then 1 else 0 end
           + case when v_partido.reconfirmaciones_pendientes > 0 then 1 else 0 end
     where id = p_partido returning * into v_partido;
    -- Sale un titular y entra un suplente: el número de cupos no cambia.
  else
    update public.partidos
       set cupos_ocupados = cupos_ocupados - 1,
           reconfirmaciones_pendientes = reconfirmaciones_pendientes
             - case when v_estaba_pendiente then 1 else 0 end,
           estado = case
             when v_partido.estado = 'equipoCompleto'
                  and v_partido.cupos_ocupados < v_partido.cupos_totales
               then 'equipoCompleto'
             else 'cuposAbiertos'
           end
     where id = p_partido
    returning * into v_partido;
  end if;
  return v_partido;
end;
$$;

-- Anotarse o retirarse de la lista solo mediante estas funciones.
create or replace function public.entrar_lista_espera(p_partido uuid)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_jugador uuid := auth.uid();
  v_partido public.partidos;
  v_nombre text;
begin
  if v_jugador is null then
    raise exception 'Debes iniciar sesión para anotarte como suplente.';
  end if;
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then
    raise exception 'Este partido ya no existe.';
  end if;
  if v_partido.fecha_inicio < now() then
    raise exception 'El partido ya se jugó: su fecha ya pasó.';
  end if;
  if v_partido.organizador_id = v_jugador or exists (
    select 1 from public.inscripciones
    where partido_id = p_partido and jugador_id = v_jugador
  ) then
    raise exception 'Ya formas parte de este equipo.';
  end if;
  if exists (
    select 1 from public.lista_espera
    where partido_id = p_partido and jugador_id = v_jugador
  ) then
    raise exception 'Ya estás en la lista de suplentes.';
  end if;
  if v_partido.estado <> 'equipoCompleto' then
    raise exception 'El equipo todavía tiene cupos: puedes unirte directamente.';
  end if;

  select nombre into v_nombre from public.perfiles where id = v_jugador;
  insert into public.lista_espera (partido_id, jugador_id, jugador_nombre)
  values (p_partido, v_jugador, coalesce(v_nombre, ''));
  return v_partido;
end;
$$;

create or replace function public.salir_lista_espera(p_partido uuid)
returns public.partidos
language plpgsql
security definer set search_path = public
as $$
declare
  v_jugador uuid := auth.uid();
  v_partido public.partidos;
begin
  if v_jugador is null then
    raise exception 'Debes iniciar sesión para cancelar la espera.';
  end if;
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then
    raise exception 'Este partido ya no existe.';
  end if;
  delete from public.lista_espera
   where partido_id = p_partido and jugador_id = v_jugador;
  if not found then
    raise exception 'No estás en la lista de suplentes.';
  end if;
  return v_partido;
end;
$$;

grant execute on function public.unirse_a_partido(uuid)           to authenticated;
grant execute on function public.salir_del_partido(uuid)           to authenticated;
grant execute on function public.entrar_lista_espera(uuid)         to authenticated;
grant execute on function public.salir_lista_espera(uuid)          to authenticated;
grant execute on function public.editar_partido(uuid, text, text, text, timestamptz, int)
  to authenticated;
grant execute on function public.completar_equipo(uuid)              to authenticated;
revoke all on function public.reprogramar_partido(uuid, timestamptz, text, text) from public, anon;
revoke all on function public.responder_reprogramacion(uuid, boolean) from public, anon;
grant execute on function public.reprogramar_partido(uuid, timestamptz, text, text) to authenticated;
grant execute on function public.responder_reprogramacion(uuid, boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- Historial de participación (Clase 16 · Tarea 4)
-- Devuelve los partidos donde el usuario participó (como organizador o inscrito),
-- ordenados con los más recientes primero.
-- -----------------------------------------------------------------------------
create or replace function public.obtener_historial_usuario()
returns table (
  id uuid,
  titulo text,
  disciplina text,
  ubicacion text,
  fecha_inicio timestamptz,
  cupos_totales int,
  cupos_ocupados int,
  estado text,
  organizador_id uuid,
  organizador_nombre text,
  rol text
)
language plpgsql
security definer set search_path = public
as $$
declare
  v_usuario uuid := auth.uid();
begin
  if v_usuario is null then
    raise exception 'Debes iniciar sesión para consultar tu historial.';
  end if;

  return query
  select 
    p.id,
    p.titulo,
    p.disciplina,
    p.ubicacion,
    p.fecha_inicio,
    p.cupos_totales,
    p.cupos_ocupados,
    p.estado,
    p.organizador_id,
    p.organizador_nombre,
    case when p.organizador_id = v_usuario then 'organizador' else 'jugador' end as rol
  from public.partidos p
  where p.organizador_id = v_usuario
     or exists (select 1 from public.inscripciones i where i.partido_id = p.id and i.jugador_id = v_usuario)
  order by p.fecha_inicio desc;
end;
$$;

grant execute on function public.obtener_historial_usuario() to authenticated;


-- Propuesta sencilla: una por partido, reemplazada en cada envío.
create table if not exists public.propuestas_equipos (
  partido_id uuid primary key references public.partidos(id) on delete cascade,
  revision uuid not null default gen_random_uuid(),
  equipo_a uuid[] not null,
  equipo_b uuid[] not null,
  capitan_rival_id uuid not null references public.perfiles(id),
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'aceptada', 'rechazada'))
);
alter table public.propuestas_equipos enable row level security;
-- Las escrituras solo se realizan mediante las funciones de abajo.
revoke all on public.propuestas_equipos from public, anon, authenticated;
grant select on public.propuestas_equipos to authenticated;
drop policy if exists "equipos: leer participantes" on public.propuestas_equipos;
create policy "equipos: leer participantes" on public.propuestas_equipos
for select to authenticated using (
  exists (select 1 from public.partidos p
    where p.id = partido_id and p.organizador_id = auth.uid())
  or exists (select 1 from public.inscripciones i
    where i.partido_id = propuestas_equipos.partido_id and i.jugador_id = auth.uid())
);

create or replace function public.obtener_participantes_equipos(p_partido uuid)
returns table(id uuid, nombre text, es_organizador boolean)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.partidos p where p.id = p_partido and
      (p.organizador_id = auth.uid() or exists (
        select 1 from public.inscripciones i
        where i.partido_id = p.id and i.jugador_id = auth.uid()))
  ) then
    raise exception 'Solo los participantes pueden consultar los equipos.';
  end if;
  return query
    select p.organizador_id, p.organizador_nombre, true
      from public.partidos p where p.id = p_partido
    union all
    select i.jugador_id, i.jugador_nombre, false
      from public.inscripciones i where i.partido_id = p_partido;
end;
$$;

create or replace function public.guardar_propuesta_equipos(
  p_partido uuid, p_equipo_a uuid[], p_equipo_b uuid[], p_capitan_rival uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_partido public.partidos;
  v_actuales uuid[];
  v_todos uuid[];
begin
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then raise exception 'Este partido ya no existe.'; end if;
  if auth.uid() is null or v_partido.organizador_id <> auth.uid() then
    raise exception 'Solo el organizador puede proponer equipos.';
  end if;
  if v_partido.fecha_inicio <= now() then
    raise exception 'El partido ya comenzó.';
  end if;
  if v_partido.estado <> 'equipoCompleto' then
    raise exception 'Cierra la convocatoria antes de proponer equipos.';
  end if;
  select array_agg(id) into v_actuales
    from public.obtener_participantes_equipos(p_partido);
  v_todos := p_equipo_a || p_equipo_b;
  if p_equipo_a is null or p_equipo_b is null or p_capitan_rival is null
    or cardinality(p_equipo_b) = 0
    or not (v_partido.organizador_id = any(p_equipo_a))
    or p_capitan_rival = v_partido.organizador_id
    or not (p_capitan_rival = any(p_equipo_b))
    or array_position(v_todos, null) is not null
    or cardinality(v_todos) <> cardinality(v_actuales)
    or (select count(distinct x) from unnest(v_todos) x) <> cardinality(v_todos)
    or not (v_todos @> v_actuales and v_actuales @> v_todos) then
    raise exception 'Asigna a todos una sola vez, deja al organizador en A y elige un capitán del B.';
  end if;
  insert into public.propuestas_equipos
    (partido_id, equipo_a, equipo_b, capitan_rival_id)
  values (p_partido, p_equipo_a, p_equipo_b, p_capitan_rival)
  on conflict (partido_id) do update set
    revision = gen_random_uuid(), equipo_a = excluded.equipo_a,
    equipo_b = excluded.equipo_b, capitan_rival_id = excluded.capitan_rival_id,
    estado = 'pendiente';
end;
$$;

create or replace function public.responder_propuesta_equipos(
  p_partido uuid, p_revision uuid, p_acepta boolean
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_partido public.partidos;
  v_propuesta public.propuestas_equipos;
begin
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then raise exception 'Este partido ya no existe.'; end if;
  if v_partido.fecha_inicio <= now() then raise exception 'El partido ya comenzó.'; end if;
  select * into v_propuesta from public.propuestas_equipos where partido_id = p_partido;
  if not found or p_revision is distinct from v_propuesta.revision then
    raise exception 'La propuesta cambió. Vuelve a abrir los equipos.';
  end if;
  if auth.uid() is null or auth.uid() <> v_propuesta.capitan_rival_id then
    raise exception 'Solo el capitán rival puede responder.';
  end if;
  if v_propuesta.estado <> 'pendiente' then
    raise exception 'Esta propuesta ya tiene respuesta.';
  end if;
  if p_acepta is null then raise exception 'Indica si aceptas o rechazas.'; end if;
  update public.propuestas_equipos set estado =
    case when p_acepta then 'aceptada' else 'rechazada' end
    where partido_id = p_partido;
end;
$$;

-- Los cambios de participantes usan el mismo bloqueo de partido que las RPC.
-- Los UPDATE de reconfirmación no modifican el reparto.
create or replace function public.invalidar_equipos_inscripcion()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if TG_OP = 'DELETE' then v_id := old.partido_id;
  else v_id := new.partido_id; end if;
  perform 1 from public.partidos where id = v_id for update;
  delete from public.propuestas_equipos where partido_id = v_id;
  return null;
end;
$$;
drop trigger if exists invalidar_equipos_inscripcion on public.inscripciones;
create trigger invalidar_equipos_inscripcion
  after insert or delete on public.inscripciones
  for each row execute function public.invalidar_equipos_inscripcion();

create or replace function public.invalidar_equipos_reprogramacion()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.fecha_inicio is distinct from old.fecha_inicio
    or new.ubicacion is distinct from old.ubicacion then
    delete from public.propuestas_equipos where partido_id = new.id;
  end if;
  return null;
end;
$$;
drop trigger if exists invalidar_equipos_reprogramacion on public.partidos;
create trigger invalidar_equipos_reprogramacion
  after update on public.partidos
  for each row execute function public.invalidar_equipos_reprogramacion();

revoke all on function public.obtener_participantes_equipos(uuid) from public, anon;
revoke all on function public.guardar_propuesta_equipos(uuid, uuid[], uuid[], uuid) from public, anon;
revoke all on function public.responder_propuesta_equipos(uuid, uuid, boolean) from public, anon;
revoke all on function public.invalidar_equipos_inscripcion() from public, anon, authenticated;
revoke all on function public.invalidar_equipos_reprogramacion() from public, anon, authenticated;
grant execute on function public.obtener_participantes_equipos(uuid) to authenticated;
grant execute on function public.guardar_propuesta_equipos(uuid, uuid[], uuid[], uuid) to authenticated;
grant execute on function public.responder_propuesta_equipos(uuid, uuid, boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- Tarea 8 · Resultado validado entre los capitanes
-- Solo un resultado confirmado por el capitán rival se considera definitivo.
-- -----------------------------------------------------------------------------
create table if not exists public.resultados_partido (
  partido_id uuid primary key references public.partidos(id) on delete cascade,
  revision uuid not null default gen_random_uuid(),
  marcador_equipo_a int not null check (marcador_equipo_a between 0 and 999),
  marcador_equipo_b int not null check (marcador_equipo_b between 0 and 999),
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'disputado', 'confirmado')),
  motivo_disputa text,
  actualizado_en timestamptz not null default now()
);

create table if not exists public.historial_resultados (
  id bigint generated always as identity primary key,
  partido_id uuid not null references public.partidos(id) on delete cascade,
  revision uuid not null,
  accion text not null
    check (accion in ('registrado', 'disputado', 'corregido', 'confirmado')),
  marcador_equipo_a int not null check (marcador_equipo_a between 0 and 999),
  marcador_equipo_b int not null check (marcador_equipo_b between 0 and 999),
  motivo text,
  actor_id uuid references public.perfiles(id) on delete set null,
  actor_nombre text not null,
  creado_en timestamptz not null default now()
);
create index if not exists historial_resultados_partido_idx
  on public.historial_resultados(partido_id, creado_en, id);

alter table public.resultados_partido enable row level security;
alter table public.historial_resultados enable row level security;
revoke all on public.resultados_partido from public, anon, authenticated;
revoke all on public.historial_resultados from public, anon, authenticated;
grant select on public.resultados_partido to authenticated;
grant select on public.historial_resultados to authenticated;

drop policy if exists "resultados: leer participantes" on public.resultados_partido;
create policy "resultados: leer participantes" on public.resultados_partido
for select to authenticated using (
  exists (select 1 from public.partidos p
    where p.id = partido_id and p.organizador_id = auth.uid())
  or exists (select 1 from public.inscripciones i
    where i.partido_id = resultados_partido.partido_id
      and i.jugador_id = auth.uid())
);

drop policy if exists "historial resultados: leer participantes" on public.historial_resultados;
create policy "historial resultados: leer participantes" on public.historial_resultados
for select to authenticated using (
  exists (select 1 from public.partidos p
    where p.id = partido_id and p.organizador_id = auth.uid())
  or exists (select 1 from public.inscripciones i
    where i.partido_id = historial_resultados.partido_id
      and i.jugador_id = auth.uid())
);

create or replace function public.registrar_resultado_partido(
  p_partido uuid, p_marcador_a int, p_marcador_b int
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_partido public.partidos;
  v_resultado public.resultados_partido;
  v_revision uuid := gen_random_uuid();
  v_accion text;
  v_nombre text;
begin
  if p_marcador_a is null or p_marcador_b is null
    or p_marcador_a not between 0 and 999
    or p_marcador_b not between 0 and 999 then
    raise exception 'El marcador debe contener valores entre 0 y 999.';
  end if;
  select * into v_partido from public.partidos where id = p_partido for update;
  if not found then raise exception 'Este partido ya no existe.'; end if;
  if auth.uid() is null or v_partido.organizador_id <> auth.uid() then
    raise exception 'Solo el organizador puede registrar o corregir el marcador.';
  end if;
  if v_partido.fecha_inicio > now() then
    raise exception 'Registra el marcador cuando el partido haya terminado.';
  end if;
  if not exists (select 1 from public.propuestas_equipos pe
    where pe.partido_id = p_partido and pe.estado = 'aceptada') then
    raise exception 'Los equipos deben estar aceptados antes de registrar el marcador.';
  end if;

  select * into v_resultado from public.resultados_partido
    where partido_id = p_partido for update;
  if found then
    if v_resultado.estado = 'confirmado' then
      raise exception 'El resultado confirmado es definitivo.';
    elsif v_resultado.estado <> 'disputado' then
      raise exception 'Espera la respuesta del capitán rival.';
    end if;
    v_accion := 'corregido';
    update public.resultados_partido set
      revision = v_revision,
      marcador_equipo_a = p_marcador_a,
      marcador_equipo_b = p_marcador_b,
      estado = 'pendiente',
      motivo_disputa = null,
      actualizado_en = now()
    where partido_id = p_partido;
  else
    v_accion := 'registrado';
    insert into public.resultados_partido
      (partido_id, revision, marcador_equipo_a, marcador_equipo_b)
    values (p_partido, v_revision, p_marcador_a, p_marcador_b);
  end if;

  select nombre into v_nombre from public.perfiles where id = auth.uid();
  insert into public.historial_resultados
    (partido_id, revision, accion, marcador_equipo_a, marcador_equipo_b,
     actor_id, actor_nombre)
  values (p_partido, v_revision, v_accion, p_marcador_a, p_marcador_b,
          auth.uid(), coalesce(v_nombre, v_partido.organizador_nombre));
end;
$$;

create or replace function public.disputar_resultado_partido(
  p_partido uuid, p_revision uuid, p_motivo text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_resultado public.resultados_partido;
  v_propuesta public.propuestas_equipos;
  v_nombre text;
begin
  perform 1 from public.partidos where id = p_partido for update;
  if not found then raise exception 'Este partido ya no existe.'; end if;
  select * into v_propuesta from public.propuestas_equipos
    where partido_id = p_partido;
  if not found or auth.uid() is null or auth.uid() <> v_propuesta.capitan_rival_id then
    raise exception 'Solo el capitán rival puede confirmar o disputar el resultado.';
  end if;
  select * into v_resultado from public.resultados_partido
    where partido_id = p_partido for update;
  if not found or p_revision is distinct from v_resultado.revision then
    raise exception 'El marcador cambió. Vuelve a cargar el resultado.';
  end if;
  if v_resultado.estado <> 'pendiente' then
    raise exception 'Este marcador ya tiene respuesta.';
  end if;
  if nullif(trim(p_motivo), '') is null then
    raise exception 'Explica el motivo de la disputa.';
  end if;
  update public.resultados_partido set estado = 'disputado',
    motivo_disputa = trim(p_motivo), actualizado_en = now()
    where partido_id = p_partido;
  select nombre into v_nombre from public.perfiles where id = auth.uid();
  insert into public.historial_resultados
    (partido_id, revision, accion, marcador_equipo_a, marcador_equipo_b,
     motivo, actor_id, actor_nombre)
  values (p_partido, v_resultado.revision, 'disputado',
          v_resultado.marcador_equipo_a, v_resultado.marcador_equipo_b,
          trim(p_motivo), auth.uid(), coalesce(v_nombre, 'Capitán rival'));
end;
$$;

create or replace function public.confirmar_resultado_partido(
  p_partido uuid, p_revision uuid
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_resultado public.resultados_partido;
  v_propuesta public.propuestas_equipos;
  v_nombre text;
begin
  perform 1 from public.partidos where id = p_partido for update;
  if not found then raise exception 'Este partido ya no existe.'; end if;
  select * into v_propuesta from public.propuestas_equipos
    where partido_id = p_partido;
  if not found or auth.uid() is null or auth.uid() <> v_propuesta.capitan_rival_id then
    raise exception 'Solo el capitán rival puede confirmar o disputar el resultado.';
  end if;
  select * into v_resultado from public.resultados_partido
    where partido_id = p_partido for update;
  if not found or p_revision is distinct from v_resultado.revision then
    raise exception 'El marcador cambió. Vuelve a cargar el resultado.';
  end if;
  if v_resultado.estado <> 'pendiente' then
    raise exception 'Este marcador ya tiene respuesta.';
  end if;
  update public.resultados_partido set estado = 'confirmado',
    motivo_disputa = null, actualizado_en = now()
    where partido_id = p_partido;
  select nombre into v_nombre from public.perfiles where id = auth.uid();
  insert into public.historial_resultados
    (partido_id, revision, accion, marcador_equipo_a, marcador_equipo_b,
     actor_id, actor_nombre)
  values (p_partido, v_resultado.revision, 'confirmado',
          v_resultado.marcador_equipo_a, v_resultado.marcador_equipo_b,
          auth.uid(), coalesce(v_nombre, 'Capitán rival'));
end;
$$;

revoke all on function public.registrar_resultado_partido(uuid, int, int) from public, anon;
revoke all on function public.disputar_resultado_partido(uuid, uuid, text) from public, anon;
revoke all on function public.confirmar_resultado_partido(uuid, uuid) from public, anon;
grant execute on function public.registrar_resultado_partido(uuid, int, int) to authenticated;
grant execute on function public.disputar_resultado_partido(uuid, uuid, text) to authenticated;
grant execute on function public.confirmar_resultado_partido(uuid, uuid) to authenticated;
