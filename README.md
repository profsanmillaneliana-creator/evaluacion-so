# Cuestionario autocorregible con contraseña

**Configuración y Adaptación de Sistemas Operativos**

- **Página:** GitHub Pages (gratis)
- **Base de datos:** Supabase (plan gratuito)

## ¿Qué hace?

- **Alumnos (`index.html`):** cada alumno entra con su usuario y su contraseña y responde las 20 preguntas. Al entregar ve su nota del 1 al 10 (aprueba con 6) y, si lo habilitás, la corrección de cada pregunta.
- **Corrección en el servidor:** el examen se corrige en la base de datos. Las respuestas correctas nunca llegan a la computadora del alumno, así que no se pueden "espiar" con el inspector del navegador.
- **Docente (`docente.html`):** con tu contraseña podés hacer lo siguiente.
  - Cargar alumnos en lote (podés pegarlos desde Excel). Las contraseñas se generan solas.
  - Imprimir tarjetas con el usuario y la contraseña de cada alumno.
  - Ver las notas por curso, el promedio y el porcentaje de aprobados.
  - Ver las respuestas de cada alumno.
  - Descargar las notas en un archivo que abre Excel.
  - Ver el porcentaje de aciertos de cada pregunta, para saber qué temas reforzar.
  - Abrir o cerrar el examen, elegir cuántos intentos tiene cada alumno y habilitar a un alumno para que rinda de nuevo.
- **Contraseñas:** se guardan cifradas (bcrypt). Si alguien se equivoca 5 veces seguidas, ese usuario queda bloqueado 5 minutos.

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `index.html` | Página del alumno |
| `docente.html` | Panel docente |
| `config.js` | Acá van la dirección y la clave pública de tu Supabase (**hay que completarlo**) |
| `comun.js`, `estilos.css` | Código y diseño compartidos |
| `supabase/schema.sql` | Crea la base de datos con las 20 preguntas (se ejecuta una vez en Supabase) |

---

## Paso 1 · Crear la base de datos en Supabase

1. Entrá a **https://supabase.com** y creá una cuenta. Podés usar tu cuenta de GitHub.
2. Tocá **New project**.
   - Nombre: por ejemplo `cuestionario-so`.
   - Database password: inventá una y guardala. No es la del examen.
   - Region: **South America (São Paulo)**, que es la más cercana.
   - Tocá **Create new project** y esperá 1 o 2 minutos.
3. Abrí el archivo `supabase/schema.sql` con el Bloc de notas. Al final del archivo buscá esta línea:
   ```sql
   set docente_hash = extensions.crypt('CambiarEstaClave2026', ...
   ```
   Cambiá `CambiarEstaClave2026` por **tu contraseña docente** (mínimo 8 caracteres). Dejá las comillas.
4. En Supabase andá al menú de la izquierda, **SQL Editor** → **New query**. Pegá **todo** el contenido de `schema.sql` y tocá **Run**. Tiene que decir *Success. No rows returned*.
5. Andá a **Project Settings** (el engranaje) y copiá dos datos:
   - **Project URL**, del tipo `https://abcdxyz.supabase.co`. Está en *Data API* o en la pantalla principal del proyecto.
   - **Publishable key**, que empieza con `sb_publishable_...`. Está en *API Keys*. En proyectos viejos se llama **anon public**.
   - ⚠️ **No uses nunca** la *secret key* ni la *service_role*.

## Paso 2 · Completar `config.js`

Abrí `config.js` y pegá los dos datos:

```js
window.CONFIG = {
  SUPABASE_URL: "https://abcdxyz.supabase.co",
  SUPABASE_KEY: "sb_publishable_xxxxxxxxxxxxxxxx"
};
```

Esa clave es **pública por diseño**: puede estar a la vista en GitHub. Lo que protege los datos son las funciones de la base de datos, que exigen las contraseñas.

## Paso 3 · Publicar la página en GitHub Pages

1. Entrá a **https://github.com**, creá una cuenta si no tenés y tocá **New repository**.
   - Nombre: por ejemplo `evaluacion-so`.
   - Elegí **Public**, porque GitHub Pages es gratis solo para repositorios públicos.
   - Tocá **Create repository**.
2. En el repositorio nuevo tocá **uploading an existing file** (o **Add file → Upload files**).
   - Arrastrá estos archivos: `index.html`, `docente.html`, `config.js`, `comun.js`, `estilos.css`, `README.md`.
   - No hace falta subir la carpeta `supabase`. Si la subís no pasa nada, porque no contiene contraseñas.
   - Tocá **Commit changes**.
3. Andá a **Settings → Pages**.
   - En *Source* elegí **Deploy from a branch**.
   - En *Branch* elegí **main** y **/ (root)**.
   - Tocá **Save**.
4. Esperá 1 o 2 minutos y recargá la página de Settings. Arriba aparece la dirección:
   - Alumnos: `https://TU-USUARIO.github.io/evaluacion-so/`
   - Docente: `https://TU-USUARIO.github.io/evaluacion-so/docente.html`

## Paso 4 · Cargar los alumnos

1. Entrá a `docente.html` con tu contraseña docente y abrí la pestaña **Alumnos**.
2. Escribí o pegá una línea por alumno con este formato:
   ```
   usuario ; Apellido y nombre ; curso ; contraseña
   45123456 ; Pérez, Juan ; 5° A
   45987654 ; Gómez, Ana ; 5° A ; ana2026
   ```
   - El **usuario** no lleva espacios. Conviene usar el DNI.
   - La **contraseña** es opcional: si la dejás vacía se genera una de 6 letras y números.
   - Desde Excel podés copiar 3 o 4 columnas y pegarlas directo.
3. Tocá **Cargar alumnos**. **Descargá o imprimí las credenciales en ese momento**, porque por seguridad no se vuelven a mostrar. Si un alumno se olvida su contraseña, tocá **Nueva contraseña** en la lista.

## Paso 5 · Tomar el examen

1. Pasales a los alumnos el link de la página del alumno y su tarjeta con el usuario y la contraseña.
2. En **Configuración** podés:
   - Abrir o cerrar el examen. Cerralo cuando termine la hora.
   - Elegir cuántos intentos tiene cada alumno. Por defecto es 1.
   - Elegir si ven la corrección al terminar.
3. Las notas aparecen en **Resultados**. Tocá **↻ Actualizar** para ver las nuevas entregas.

---

## Escala de calificación

`nota = correctas × 10 ÷ total de preguntas`, con un mínimo de 1. Se aprueba con **6**.

Con 20 preguntas, cada una vale 0,5 punto: 12 correctas dan 6, que es la nota de aprobación.

## Cambiar o agregar preguntas

Editá la sección **PREGUNTAS** de `supabase/schema.sql` y volvé a ejecutar el archivo completo en el SQL Editor. **No se borran** ni los alumnos ni las notas. En cada pregunta, `correcta` indica la opción correcta: 0 = a, 1 = b, 2 = c, 3 = d.

⚠️ Al volver a ejecutar el archivo, la contraseña docente vuelve a ser la que figura al final. Si la habías cambiado desde el panel, poné la nueva en el archivo antes de ejecutarlo.

Para cambiar el porcentaje de aprobación, ejecutá en el SQL Editor:

```sql
update examen set nota_aprobacion = 7;
```

## Importante sobre el plan gratuito de Supabase

- **Pausa por inactividad:** si el proyecto pasa **7 días sin uso**, Supabase lo pausa. Los datos no se pierden. Antes de cada examen entrá a supabase.com y, si el proyecto dice *Paused*, tocá **Restore**. Tarda unos minutos.
- **Copia de las notas:** el plan gratis no hace copias de seguridad, así que descargá las notas desde el panel después de cada examen.

## Problemas frecuentes

| Problema | Solución |
|---|---|
| "Falta configurar la base de datos" | Completá `config.js` y volvé a subirlo a GitHub |
| "No se encontró la función…" | No se ejecutó `schema.sql`, o se ejecutó en otro proyecto |
| "La clave de Supabase… no es válida" | Revisá que copiaste la *Publishable key* (o *anon*) completa |
| "No se pudo conectar…" | El proyecto está pausado (andá a supabase.com → Restore) o no hay Internet |
| Un alumno quedó "bloqueado" | Esperá 5 minutos o generale una **Nueva contraseña** |
| Un alumno necesita rendir de nuevo | Tocá **Habilitar de nuevo** en Resultados (se borra su nota anterior), o subí la cantidad de intentos |
