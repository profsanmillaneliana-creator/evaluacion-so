-- =====================================================================
--  CUESTIONARIO AUTOCORREGIBLE  ·  Base de datos para Supabase
--  Configuración y Adaptación de Sistemas Operativos
-- ---------------------------------------------------------------------
--  Cómo usarlo:
--    1. Antes de ejecutar, cambiá la CONTRASEÑA DOCENTE al final del archivo.
--    2. En Supabase: SQL Editor → New query → pegá TODO este archivo → Run.
--  Se puede volver a ejecutar: no borra alumnos ni resultados
--  (pero vuelve a poner la contraseña docente que figura al final).
-- =====================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- TABLAS
-- ---------------------------------------------------------------------

-- Configuración del examen (una sola fila)
create table if not exists public.examen (
  id                 int primary key default 1 check (id = 1),
  titulo             text    not null default 'Evaluación',
  abierto            boolean not null default true,   -- si los alumnos pueden rendir
  intentos_max       int     not null default 1,      -- intentos por alumno
  mostrar_correccion boolean not null default true,   -- mostrar respuestas correctas al terminar
  nota_aprobacion    numeric not null default 6,
  docente_hash       text,
  docente_fallos     int     not null default 0,
  docente_bloqueo    timestamptz
);

-- Alumnos habilitados (la contraseña se guarda cifrada, nunca en texto plano)
create table if not exists public.alumnos (
  usuario          text primary key,
  nombre           text not null,
  curso            text not null default '',
  pass_hash        text not null,
  fallos           int  not null default 0,
  bloqueado_hasta  timestamptz,
  creado           timestamptz not null default now()
);

-- Preguntas (la respuesta correcta NUNCA se envía al navegador del alumno)
create table if not exists public.preguntas (
  id          int primary key,
  seccion     text  not null,
  enunciado   text  not null,
  opciones    jsonb not null,          -- ["opción a","opción b","opción c","opción d"]
  correcta    int   not null,          -- 0 = a, 1 = b, 2 = c, 3 = d
  explicacion text  not null default ''
);

-- Cada entrega de un alumno
create table if not exists public.intentos (
  id          bigint generated always as identity primary key,
  usuario     text not null references public.alumnos(usuario) on delete cascade on update cascade,
  respuestas  jsonb not null,          -- {"1":2,"2":0,...}  (n° de pregunta → opción elegida)
  correctas   int not null,
  total       int not null,
  nota        numeric(4,2) not null,
  aprobado    boolean not null,
  fecha       timestamptz not null default now()
);
create index if not exists intentos_usuario_idx on public.intentos(usuario);

insert into public.examen (id, titulo)
values (1, 'Evaluación – Configuración y Adaptación de Sistemas Operativos')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- SEGURIDAD: nadie lee ni escribe las tablas directamente desde Internet.
-- Todo pasa por las funciones de abajo, que verifican la contraseña.
-- ---------------------------------------------------------------------
alter table public.examen    enable row level security;
alter table public.alumnos   enable row level security;
alter table public.preguntas enable row level security;
alter table public.intentos  enable row level security;

revoke all on public.examen, public.alumnos, public.preguntas, public.intentos from public;
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on public.examen, public.alumnos, public.preguntas, public.intentos from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on public.examen, public.alumnos, public.preguntas, public.intentos from authenticated';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- FUNCIONES INTERNAS (no se pueden llamar desde Internet)
-- ---------------------------------------------------------------------

-- Genera una contraseña de 6 caracteres fácil de dictar (sin 0/O, 1/l/I)
create or replace function public._generar_pass()
returns text language sql volatile
set search_path = public, extensions, pg_temp
as $$
  select string_agg(substr('abcdefghjkmnpqrstuvwxyz23456789',
                           (get_byte(b, i) % 31) + 1, 1), '')
  from (select gen_random_bytes(6) as b) x, generate_series(0, 5) as i;
$$;

-- Verifica usuario y contraseña de un alumno. Devuelve 'ok' o un mensaje de error.
-- Tras 5 intentos fallidos bloquea al usuario 5 minutos.
create or replace function public._verificar_alumno(p_usuario text, p_pass text)
returns text language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare a public.alumnos;
begin
  select * into a from public.alumnos where usuario = lower(trim(p_usuario));
  if not found then
    return 'Usuario o contraseña incorrectos.';
  end if;
  if a.bloqueado_hasta is not null and a.bloqueado_hasta > now() then
    return 'Demasiados intentos fallidos. Esperá unos minutos o pedile ayuda a tu profesor/a.';
  end if;
  if crypt(coalesce(p_pass, ''), a.pass_hash) <> a.pass_hash then
    update public.alumnos
       set fallos = case when fallos + 1 >= 5 then 0 else fallos + 1 end,
           bloqueado_hasta = case when fallos + 1 >= 5 then now() + interval '5 minutes' else bloqueado_hasta end
     where usuario = a.usuario;
    return 'Usuario o contraseña incorrectos.';
  end if;
  if a.fallos > 0 or a.bloqueado_hasta is not null then
    update public.alumnos set fallos = 0, bloqueado_hasta = null where usuario = a.usuario;
  end if;
  return 'ok';
end $$;

-- Verifica la contraseña docente. Devuelve 'ok' o un mensaje de error.
create or replace function public._verificar_docente(p_pass text)
returns text language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare e public.examen;
begin
  select * into e from public.examen where id = 1;
  if e.docente_hash is null then
    return 'Todavía no se configuró la contraseña docente.';
  end if;
  if e.docente_bloqueo is not null and e.docente_bloqueo > now() then
    return 'Demasiados intentos fallidos. Esperá 5 minutos.';
  end if;
  if crypt(coalesce(p_pass, ''), e.docente_hash) <> e.docente_hash then
    update public.examen
       set docente_fallos = case when docente_fallos + 1 >= 5 then 0 else docente_fallos + 1 end,
           docente_bloqueo = case when docente_fallos + 1 >= 5 then now() + interval '5 minutes' else docente_bloqueo end
     where id = 1;
    return 'Contraseña docente incorrecta.';
  end if;
  if e.docente_fallos > 0 or e.docente_bloqueo is not null then
    update public.examen set docente_fallos = 0, docente_bloqueo = null where id = 1;
  end if;
  return 'ok';
end $$;

-- ---------------------------------------------------------------------
-- FUNCIONES PARA EL ALUMNO
-- ---------------------------------------------------------------------

-- Ingreso: valida y devuelve el estado del alumno
create or replace function public.alumno_ingresar(p_usuario text, p_pass text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_msg text; a public.alumnos; e public.examen; v_usados int; v_ultimo json;
begin
  v_msg := public._verificar_alumno(p_usuario, p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;

  select * into a from public.alumnos where usuario = lower(trim(p_usuario));
  select * into e from public.examen where id = 1;
  select count(*) into v_usados from public.intentos where usuario = a.usuario;
  select json_build_object('correctas', correctas, 'total', total, 'nota', nota,
                           'aprobado', aprobado, 'fecha', fecha)
    into v_ultimo
    from public.intentos where usuario = a.usuario order by fecha desc limit 1;

  return json_build_object(
    'ok', true, 'usuario', a.usuario, 'nombre', a.nombre, 'curso', a.curso,
    'titulo', e.titulo, 'abierto', e.abierto,
    'intentos_usados', v_usados, 'intentos_max', e.intentos_max,
    'puede_rendir', e.abierto and v_usados < e.intentos_max,
    'nota_aprobacion', e.nota_aprobacion,
    'ultimo', v_ultimo);
end $$;

-- Preguntas SIN la respuesta correcta
create or replace function public.alumno_preguntas(p_usuario text, p_pass text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare v_msg text; e public.examen; v_usados int;
begin
  v_msg := public._verificar_alumno(p_usuario, p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  select * into e from public.examen where id = 1;
  if not e.abierto then
    return json_build_object('ok', false, 'error', 'El examen está cerrado.');
  end if;
  select count(*) into v_usados from public.intentos where usuario = lower(trim(p_usuario));
  if v_usados >= e.intentos_max then
    return json_build_object('ok', false, 'error', 'Ya usaste todos tus intentos.');
  end if;
  return json_build_object('ok', true, 'titulo', e.titulo, 'preguntas',
    (select coalesce(json_agg(json_build_object('id', id, 'seccion', seccion,
                     'enunciado', enunciado, 'opciones', opciones) order by id), '[]'::json)
       from public.preguntas));
end $$;

-- Entrega: corrige en el servidor, guarda y devuelve la nota
create or replace function public.alumno_entregar(p_usuario text, p_pass text, p_respuestas jsonb)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_msg text; e public.examen; v_usuario text := lower(trim(p_usuario));
  v_usados int; v_total int; v_ok int; v_nota numeric; v_aprob boolean;
  v_limpias jsonb; v_detalle json;
begin
  v_msg := public._verificar_alumno(p_usuario, p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  if p_respuestas is null or jsonb_typeof(p_respuestas) <> 'object' then
    return json_build_object('ok', false, 'error', 'Respuestas inválidas.');
  end if;

  -- bloquea la fila del alumno para evitar dos entregas simultáneas
  perform 1 from public.alumnos where usuario = v_usuario for update;
  select * into e from public.examen where id = 1;
  if not e.abierto then
    return json_build_object('ok', false, 'error', 'El examen está cerrado.');
  end if;
  select count(*) into v_usados from public.intentos where usuario = v_usuario;
  if v_usados >= e.intentos_max then
    return json_build_object('ok', false, 'error', 'Ya usaste todos tus intentos.');
  end if;

  -- respuestas elegidas (solo números válidos de preguntas existentes)
  with r as (
    select p.id, p.correcta, p.explicacion,
           case when jsonb_typeof(p_respuestas -> p.id::text) = 'number'
                then floor((p_respuestas ->> p.id::text)::numeric)::int end as elegida
      from public.preguntas p
  )
  select count(*), count(*) filter (where elegida = correcta),
         coalesce(jsonb_object_agg(id::text, elegida) filter (where elegida is not null), '{}'::jsonb),
         json_agg(json_build_object('id', id, 'elegida', elegida, 'correcta', correcta,
                                    'explicacion', explicacion) order by id)
    into v_total, v_ok, v_limpias, v_detalle
    from r;

  if v_total = 0 then
    return json_build_object('ok', false, 'error', 'El examen no tiene preguntas cargadas.');
  end if;

  v_nota  := greatest(1, round(v_ok * 10.0 / v_total, 2));
  v_aprob := v_nota >= e.nota_aprobacion;

  insert into public.intentos (usuario, respuestas, correctas, total, nota, aprobado)
  values (v_usuario, v_limpias, v_ok, v_total, v_nota, v_aprob);

  return json_build_object('ok', true, 'correctas', v_ok, 'total', v_total,
    'nota', v_nota, 'aprobado', v_aprob, 'nota_aprobacion', e.nota_aprobacion,
    'detalle', case when e.mostrar_correccion then v_detalle else null end);
end $$;

-- ---------------------------------------------------------------------
-- FUNCIONES PARA EL DOCENTE (todas piden la contraseña docente)
-- ---------------------------------------------------------------------

-- Todo lo necesario para el panel: configuración, alumnos, intentos y preguntas
create or replace function public.docente_datos(p_pass text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare v_msg text;
begin
  v_msg := public._verificar_docente(p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  return json_build_object('ok', true,
    'examen', (select json_build_object('titulo', titulo, 'abierto', abierto,
                 'intentos_max', intentos_max, 'mostrar_correccion', mostrar_correccion,
                 'nota_aprobacion', nota_aprobacion) from public.examen where id = 1),
    'alumnos', (select coalesce(json_agg(json_build_object(
                   'usuario', a.usuario, 'nombre', a.nombre, 'curso', a.curso,
                   'bloqueado', a.bloqueado_hasta is not null and a.bloqueado_hasta > now(),
                   'intentos', (select coalesce(json_agg(json_build_object(
                                   'id', i.id, 'correctas', i.correctas, 'total', i.total,
                                   'nota', i.nota, 'aprobado', i.aprobado, 'fecha', i.fecha,
                                   'respuestas', i.respuestas) order by i.fecha), '[]'::json)
                                  from public.intentos i where i.usuario = a.usuario)
                 ) order by a.curso, a.nombre), '[]'::json) from public.alumnos a),
    'preguntas', (select coalesce(json_agg(json_build_object('id', id, 'seccion', seccion,
                   'enunciado', enunciado, 'opciones', opciones, 'correcta', correcta)
                   order by id), '[]'::json) from public.preguntas));
end $$;

-- Alta de alumnos en lote. p_lista = [{"usuario":"...","nombre":"...","curso":"...","pass":""}]
-- Si "pass" viene vacío se genera una. Devuelve las contraseñas (solo esta vez).
create or replace function public.docente_alta_alumnos(p_pass text, p_lista jsonb)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_msg text; x jsonb; v_usuario text; v_nombre text; v_curso text; v_clave text;
  v_creados jsonb := '[]'::jsonb; v_omitidos jsonb := '[]'::jsonb;
begin
  v_msg := public._verificar_docente(p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  if p_lista is null or jsonb_typeof(p_lista) <> 'array' then
    return json_build_object('ok', false, 'error', 'Lista inválida.');
  end if;

  for x in select * from jsonb_array_elements(p_lista) loop
    v_usuario := lower(regexp_replace(trim(coalesce(x->>'usuario', '')), '\s+', '', 'g'));
    v_nombre  := trim(coalesce(x->>'nombre', ''));
    v_curso   := trim(coalesce(x->>'curso', ''));
    v_clave   := trim(coalesce(x->>'pass', ''));
    if v_usuario = '' or v_nombre = '' then
      v_omitidos := v_omitidos || jsonb_build_object('usuario', v_usuario, 'motivo', 'Falta usuario o nombre');
      continue;
    end if;
    if exists (select 1 from public.alumnos where usuario = v_usuario) then
      v_omitidos := v_omitidos || jsonb_build_object('usuario', v_usuario, 'motivo', 'Ya existe');
      continue;
    end if;
    if v_clave = '' then v_clave := public._generar_pass(); end if;
    insert into public.alumnos (usuario, nombre, curso, pass_hash)
    values (v_usuario, v_nombre, v_curso, crypt(v_clave, gen_salt('bf')));
    v_creados := v_creados || jsonb_build_object('usuario', v_usuario, 'nombre', v_nombre,
                                                  'curso', v_curso, 'pass', v_clave);
  end loop;
  return json_build_object('ok', true, 'creados', v_creados, 'omitidos', v_omitidos);
end $$;

-- Genera una contraseña nueva para un alumno (y lo desbloquea)
create or replace function public.docente_nueva_pass(p_pass text, p_usuario text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare v_msg text; v_clave text := public._generar_pass();
begin
  v_msg := public._verificar_docente(p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  update public.alumnos set pass_hash = crypt(v_clave, gen_salt('bf')), fallos = 0, bloqueado_hasta = null
   where usuario = lower(trim(p_usuario));
  if not found then return json_build_object('ok', false, 'error', 'No existe ese alumno.'); end if;
  return json_build_object('ok', true, 'usuario', lower(trim(p_usuario)), 'pass', v_clave);
end $$;

-- Borra los intentos de un alumno para que pueda volver a rendir
create or replace function public.docente_habilitar_intento(p_pass text, p_usuario text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare v_msg text; v_n int;
begin
  v_msg := public._verificar_docente(p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  delete from public.intentos where usuario = lower(trim(p_usuario));
  get diagnostics v_n = row_count;
  return json_build_object('ok', true, 'borrados', v_n);
end $$;

-- Elimina un alumno (y sus intentos)
create or replace function public.docente_borrar_alumno(p_pass text, p_usuario text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare v_msg text;
begin
  v_msg := public._verificar_docente(p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  delete from public.alumnos where usuario = lower(trim(p_usuario));
  return json_build_object('ok', true);
end $$;

-- Cambia la configuración del examen (los valores en null no se modifican)
create or replace function public.docente_configurar(
  p_pass text, p_abierto boolean default null, p_intentos_max int default null,
  p_mostrar_correccion boolean default null, p_titulo text default null)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare v_msg text;
begin
  v_msg := public._verificar_docente(p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  if p_intentos_max is not null and (p_intentos_max < 1 or p_intentos_max > 20) then
    return json_build_object('ok', false, 'error', 'Los intentos deben estar entre 1 y 20.');
  end if;
  update public.examen set
    abierto            = coalesce(p_abierto, abierto),
    intentos_max       = coalesce(p_intentos_max, intentos_max),
    mostrar_correccion = coalesce(p_mostrar_correccion, mostrar_correccion),
    titulo             = coalesce(nullif(trim(p_titulo), ''), titulo)
  where id = 1;
  return json_build_object('ok', true);
end $$;

-- Cambia la contraseña docente
create or replace function public.docente_cambiar_pass(p_pass text, p_nueva text)
returns json language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare v_msg text;
begin
  v_msg := public._verificar_docente(p_pass);
  if v_msg <> 'ok' then return json_build_object('ok', false, 'error', v_msg); end if;
  if length(coalesce(p_nueva, '')) < 8 then
    return json_build_object('ok', false, 'error', 'La nueva contraseña debe tener al menos 8 caracteres.');
  end if;
  update public.examen set docente_hash = crypt(p_nueva, gen_salt('bf')) where id = 1;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- PERMISOS: desde Internet solo se pueden llamar las funciones públicas
-- ---------------------------------------------------------------------
revoke execute on all functions in schema public from public;
do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('revoke execute on all functions in schema public from %I', r);
      execute format('grant execute on function
        public.alumno_ingresar(text, text),
        public.alumno_preguntas(text, text),
        public.alumno_entregar(text, text, jsonb),
        public.docente_datos(text),
        public.docente_alta_alumnos(text, jsonb),
        public.docente_nueva_pass(text, text),
        public.docente_habilitar_intento(text, text),
        public.docente_borrar_alumno(text, text),
        public.docente_configurar(text, boolean, int, boolean, text),
        public.docente_cambiar_pass(text, text) to %I', r);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- PREGUNTAS (20).  correcta: 0 = a, 1 = b, 2 = c, 3 = d
-- Para modificar una pregunta, editala acá y volvé a ejecutar el archivo.
-- ---------------------------------------------------------------------
insert into public.preguntas (id, seccion, enunciado, opciones, correcta, explicacion) values
(1, $q$Panel de control$q$,
  $q$¿Qué comando se escribe en la ventana Ejecutar (Win + R) para abrir el Panel de control?$q$,
  $q$["regedit","msconfig","control","cmd"]$q$::jsonb, 2,
  $q$El comando «control» abre el Panel de control. regedit abre el Editor del Registro, msconfig la Configuración del sistema y cmd el Símbolo del sistema.$q$),
(2, $q$Panel de control$q$,
  $q$¿En qué categoría del Panel de control se encuentra el «Firewall de Windows Defender»?$q$,
  $q$["Sistema y seguridad","Redes e Internet","Programas","Hardware y sonido"]$q$::jsonb, 0,
  $q$El firewall, las copias de seguridad, las opciones de energía y la información del sistema están dentro de «Sistema y seguridad».$q$),
(3, $q$Panel de control$q$,
  $q$Un usuario necesita desinstalar un programa. ¿A qué opción del Panel de control debe ir?$q$,
  $q$["Apariencia y personalización","Programas → Programas y características","Cuentas de usuario","Herramientas administrativas → Servicios"]$q$::jsonb, 1,
  $q$Desde «Programas → Programas y características» (o «Desinstalar un programa») se quitan o reparan las aplicaciones instaladas.$q$),
(4, $q$Panel de control$q$,
  $q$¿Qué categoría se usa para agregar una impresora o ver los dispositivos conectados?$q$,
  $q$["Accesibilidad","Reloj y región","Redes e Internet","Hardware y sonido"]$q$::jsonb, 3,
  $q$«Hardware y sonido» contiene «Dispositivos e impresoras», sonido, opciones de energía y el Administrador de dispositivos.$q$),
(5, $q$Panel de control$q$,
  $q$Se quiere cambiar el formato de la fecha, la hora y la moneda del sistema. ¿Dónde se configura?$q$,
  $q$["Reloj y región","Sistema y seguridad","Apariencia y personalización","Programas"]$q$::jsonb, 0,
  $q$En «Reloj y región» se ajustan la fecha, la hora, la zona horaria y los formatos regionales (fecha, número, moneda).$q$),
(6, $q$Panel de control$q$,
  $q$¿Qué categoría permite crear una cuenta nueva, cambiar el tipo de cuenta (estándar/administrador) o modificar la contraseña?$q$,
  $q$["Sistema y seguridad","Accesibilidad","Cuentas de usuario","Redes e Internet"]$q$::jsonb, 2,
  $q$«Cuentas de usuario» administra las cuentas del equipo, su tipo y sus credenciales.$q$),
(7, $q$Windows 10 en VirtualBox$q$,
  $q$¿Cuál es la memoria RAM mínima que pide Windows 10 de 64 bits? (dato a tener en cuenta al asignar memoria a la máquina virtual)$q$,
  $q$["512 MB","1 GB","4 GB","2 GB"]$q$::jsonb, 3,
  $q$Windows 10 pide 1 GB para 32 bits y 2 GB para 64 bits. En la práctica conviene asignar 4 GB o más a la VM si el equipo anfitrión lo permite.$q$),
(8, $q$Windows 10 en VirtualBox$q$,
  $q$¿Cuál es el espacio mínimo en disco que requieren las versiones actuales de Windows 10?$q$,
  $q$["8 GB","32 GB","4 GB","500 GB"]$q$::jsonb, 1,
  $q$Desde la actualización de 2019 el mínimo es de 32 GB. Al crear el disco virtual conviene dejar más margen (por ejemplo, 50 GB) para actualizaciones y programas.$q$),
(9, $q$Windows 10 en VirtualBox$q$,
  $q$Para crear máquinas virtuales de 64 bits, ¿qué debe estar habilitado en la BIOS/UEFI del equipo anfitrión (la PC real)?$q$,
  $q$["La virtualización por hardware (Intel VT-x o AMD-V)","El arranque rápido (Fast Boot)","El puerto serie COM1","El modo de compatibilidad Legacy"]$q$::jsonb, 0,
  $q$Sin VT-x / AMD-V activado, VirtualBox solo ofrece sistemas invitados de 32 bits o directamente no puede iniciar la VM.$q$),
(10, $q$Windows 10 en VirtualBox$q$,
  $q$Al crear la máquina virtual, ¿qué archivo se necesita para instalar Windows 10?$q$,
  $q$["Un archivo .exe del instalador de VirtualBox","Un archivo .zip con los drivers","La imagen ISO de Windows 10","Un archivo .vdi vacío"]$q$::jsonb, 2,
  $q$La imagen ISO (que se descarga del sitio de Microsoft) se monta como un DVD virtual en la VM para arrancar la instalación.$q$),
(11, $q$Windows 10 en VirtualBox$q$,
  $q$Al crear el disco virtual se elige «Reservado dinámicamente». ¿Qué significa?$q$,
  $q$["El archivo ocupa todo el tamaño elegido desde el principio","El archivo del disco crece a medida que la VM guarda datos, hasta el tamaño máximo elegido","El disco se borra cada vez que se apaga la VM","El disco se comparte con el equipo anfitrión"]$q$::jsonb, 1,
  $q$Un disco dinámico empieza chico y crece según el uso. Un disco de «tamaño fijo» reserva todo el espacio de entrada (es un poco más rápido, pero ocupa más).$q$),
(12, $q$Windows 10 en VirtualBox$q$,
  $q$Una vez instalado Windows en la VM, ¿para qué se instalan las «Guest Additions» (Complementos del invitado)?$q$,
  $q$["Para mejorar la integración: ajuste de resolución, portapapeles compartido, carpetas compartidas y mejor rendimiento de video","Para activar la licencia de Windows","Para crear un pendrive booteable","Para aumentar la RAM física del equipo anfitrión"]$q$::jsonb, 0,
  $q$Las Guest Additions son drivers y utilidades que hacen que el sistema invitado funcione mejor y se integre con el anfitrión.$q$),
(13, $q$Pendrive booteable con Rufus$q$,
  $q$¿Qué ocurre con los archivos que tenía el pendrive cuando se crea un booteable con Rufus?$q$,
  $q$["Se mueven a una carpeta llamada «Backup»","Se conservan sin cambios","Se borran, porque el pendrive se formatea","Se comprimen en un .zip"]$q$::jsonb, 2,
  $q$Rufus formatea la unidad antes de grabar la imagen, así que hay que hacer una copia de seguridad de los datos antes de empezar.$q$),
(14, $q$Pendrive booteable con Rufus$q$,
  $q$En Rufus, si la PC de destino arranca con UEFI moderno, ¿qué esquema de partición conviene elegir?$q$,
  $q$["MBR","GPT","FAT16","Ninguno, Rufus no permite elegirlo"]$q$::jsonb, 1,
  $q$GPT corresponde a equipos UEFI. MBR se usa para equipos con BIOS heredada (Legacy/CSM).$q$),
(15, $q$Pendrive booteable con Rufus$q$,
  $q$¿Cuál es la capacidad mínima recomendada del pendrive para grabar el instalador de Windows 10?$q$,
  $q$["8 GB","1 GB","2 GB","512 MB"]$q$::jsonb, 0,
  $q$La ISO de Windows 10 pesa más de 4 GB, por eso se recomienda un pendrive de 8 GB o más.$q$),
(16, $q$Pendrive booteable con Ventoy$q$,
  $q$¿Qué es una unidad USB «multiboot»?$q$,
  $q$["Un pendrive que solo puede arrancar un sistema operativo por vez y hay que regrabarlo para cambiarlo","Un pendrive donde se guardan varias imágenes ISO para arrancar o instalar distintos sistemas operativos","Un pendrive que arranca varias computadoras al mismo tiempo","Un disco virtual de VirtualBox"]$q$::jsonb, 1,
  $q$En el video se define así: un USB donde se almacenan varios sistemas operativos (varias imágenes ISO) para poder arrancarlos o instalarlos.$q$),
(17, $q$Pendrive booteable con Ventoy$q$,
  $q$Después de descargar Ventoy desde su página oficial y extraer el archivo comprimido, ¿qué se debe hacer?$q$,
  $q$["Copiar la carpeta extraída al pendrive","Abrir el Panel de control y buscar «Ventoy»","Instalar Ventoy en el disco C: como cualquier programa","Abrir la carpeta y ejecutar Ventoy2Disk como administrador"]$q$::jsonb, 3,
  $q$Ventoy no se instala en la PC: se extrae el .zip, se entra a la carpeta y se ejecuta Ventoy2Disk con clic derecho → «Ejecutar como administrador».$q$),
(18, $q$Pendrive booteable con Ventoy$q$,
  $q$En Ventoy2Disk se elige el pendrive en «Device» y se presiona «Install». ¿Qué advierte el programa y qué pasa después?$q$,
  $q$["Que el pendrive se va a formatear por completo; al terminar aparece en el Explorador con el nombre «Ventoy»","Que el pendrive se va a desfragmentar; los archivos se conservan","Que se va a descargar Windows 10 automáticamente","Que la PC se va a reiniciar en modo seguro"]$q$::jsonb, 0,
  $q$Ventoy avisa (dos veces) que la unidad se formateará y se usará solo como USB multiboot. Por eso conviene usar un pendrive limpio y en buen estado. Al finalizar, la unidad aparece como «Ventoy».$q$),
(19, $q$Pendrive booteable con Ventoy$q$,
  $q$Con el pendrive Ventoy ya creado, ¿cómo se agregan o quitan sistemas operativos?$q$,
  $q$["Hay que volver a presionar «Install» por cada ISO","Solo se pueden agregar desde el menú de arranque de la BIOS","Arrastrando o copiando y pegando las ISO en la unidad «Ventoy»; para quitarlas, se eliminan como cualquier archivo","Con Rufus, eligiendo la opción «Agregar ISO»"]$q$::jsonb, 2,
  $q$Las ISO se copian y pegan (o se arrastran) a la unidad. Para quitar una, se borra como cualquier archivo. Solo hay que calcular que entren según la capacidad del pendrive.$q$),
(20, $q$Pendrive booteable con Ventoy$q$,
  $q$Para arrancar el instalador de Windows 7, en el video se pasa la BIOS/UEFI a modo Legacy. En el menú de arranque el pendrive aparece dos veces: «UEFI: Kingston DataTraveler» y «Kingston DataTraveler». ¿Cuál se elige?$q$,
  $q$["«UEFI: Kingston DataTraveler», porque es la más moderna","Cualquiera, son iguales","Ninguna: Windows 7 no puede arrancar desde Ventoy","«Kingston DataTraveler» (sin UEFI), porque corresponde al modo BIOS/Legacy"]$q$::jsonb, 3,
  $q$La entrada sin «UEFI» es la de BIOS/Legacy. Ventoy sirve tanto para BIOS (MBR) como para UEFI (GPT); se elige la entrada según el modo de arranque configurado. Luego aparece el menú de Ventoy con la lista de ISO.$q$)
on conflict (id) do update set seccion = excluded.seccion, enunciado = excluded.enunciado,
  opciones = excluded.opciones, correcta = excluded.correcta, explicacion = excluded.explicacion;
-- Si había más preguntas que las de esta lista, se borran:
delete from public.preguntas where id > 20;

-- =====================================================================
--  CONTRASEÑA DOCENTE  (¡CAMBIALA antes de ejecutar!)
--  Es la que vas a usar para entrar a docente.html. Mínimo 8 caracteres.
-- =====================================================================
update public.examen
   set docente_hash = extensions.crypt('CambiarEstaClave2026', extensions.gen_salt('bf'))
 where id = 1;
