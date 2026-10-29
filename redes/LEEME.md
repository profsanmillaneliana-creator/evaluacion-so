# Evaluación de redes con Firebase

**Conexión entre dos computadoras** · 2° año 4ª división · Ciclo Superior · Orientación Informática

E.E.T. N° 3117 «Mtro. Daniel Oscar Reyes»

**Temas:** Modelo OSI · Modelo TCP/IP · Comandos `ping` e `ipconfig` (20 preguntas)

## Cómo funciona

- **Alumnos (`index.html`):**
  - Entran con su usuario y su contraseña y rinden una sola vez.
  - Al entregar ven su nota del 1 al 10 (se aprueba con 6).
  - La corrección detallada la ven cuando vos la habilitás.
- **Docente (`docente.html`):**
  - Cargás los alumnos y las contraseñas se generan solas. Podés imprimir tarjetas.
  - Abrís y cerrás el examen.
  - Ves notas, promedios y el porcentaje de aciertos por pregunta.
  - Descargás las notas a Excel y habilitás a un alumno para que rinda de nuevo.
- **Seguridad:**
  - Las respuestas correctas **no están en la página** ni en GitHub. Están en la base de datos y se cargan desde el archivo `preguntas-redes.json`, que guardás vos.
  - La nota la verifica la base de datos comparando con la clave, así que nadie puede inventarse un 10.

---

## Paso 1 · Crear el proyecto en Firebase (plan gratuito Spark)

1. Entrá a **https://console.firebase.google.com** con tu cuenta de Google.
2. Tocá **Crear un proyecto**.
   - Nombre: por ejemplo `redes-eet3117`.
   - Cuando pregunte por Google Analytics, **desactivalo**: no hace falta.
   - Tocá **Crear proyecto**.

## Paso 2 · Activar el ingreso con contraseña

1. En el menú de la izquierda andá a **Compilación → Authentication** y tocá **Comenzar**.
2. En **Método de acceso** elegí **Correo electrónico/contraseña**.
3. Activá el **primer** interruptor y tocá **Guardar**. El segundo, «vínculo de correo», dejalo apagado.
4. Andá a la pestaña **Usuarios** y tocá **Agregar usuario**. Esta es **tu cuenta de docente**:
   - Correo: el tuyo.
   - Contraseña: una segura, de 8 caracteres o más.
5. En la lista va a aparecer tu usuario con un **UID de usuario** (un código largo). **Copialo**: lo vas a necesitar en el Paso 4.
6. En **Configuración → Dominios autorizados**, tocá **Agregar dominio** y escribí `profsanmillaneliana-creator.github.io`.

## Paso 3 · Crear la base de datos

1. En el menú de la izquierda andá a **Compilación → Firestore Database** y tocá **Crear base de datos**.
2. Ubicación: **southamerica-east1 (São Paulo)**.
3. Elegí **Comenzar en modo de producción** y tocá **Crear**.

## Paso 4 · Publicar las reglas de seguridad

1. En Firestore Database, andá a la pestaña **Reglas**.
2. Borrá todo lo que haya y pegá el contenido completo del archivo `firestore.rules`.
3. Buscá `PEGAR_AQUI_TU_UID` y reemplazalo por **tu UID** del Paso 2. Tiene que quedar entre comillas simples, así:
   `request.auth.uid in ['aB3xYz...']`
4. Tocá **Publicar**.

## Paso 5 · Conectar la página con tu proyecto

1. Andá a **Configuración del proyecto** (el engranaje ⚙, arriba a la izquierda). En la pestaña **General**, bajá hasta **Tus apps** y tocá el ícono **`</>`** (Web).
2. Nombre: `evaluacion-redes`. **No** marques Firebase Hosting. Tocá **Registrar app**.
3. Va a aparecer un bloque `const firebaseConfig = { apiKey: "...", authDomain: "...", ... }`.
4. Copiá esos datos en el archivo `config.js`, dentro de `firebase: { ... }`.

Estos datos (incluido el `apiKey`) son públicos por diseño: los que protegen la información son las reglas del Paso 4.

## Paso 6 · Cargar las preguntas y los alumnos

1. Entrá al **panel docente** (`docente.html`) con tu correo y tu contraseña del Paso 2.
   - Si dice *«Esta cuenta todavía no tiene permisos de docente»*, el mensaje te muestra tu UID: pegalo en las reglas (Paso 4) y publicá de nuevo.
2. En **Examen y preguntas**, elegí el archivo **`preguntas-redes.json`** y tocá **Cargar preguntas**.
3. En **Alumnos**, pegá la lista con este formato:
   ```
   usuario ; Apellido y nombre ; curso ; contraseña
   ```
   - La contraseña es opcional.
   - **Descargá o imprimí las credenciales** en ese momento, porque no se vuelven a mostrar.
4. El día del examen, en **Examen y preguntas** marcá **Examen abierto** y tocá **Guardar**.
5. Cuando todos terminen:
   - Desmarcá **Examen abierto**.
   - Si querés que vean las respuestas correctas, marcá **Mostrar la corrección**.

## Preguntas frecuentes

| Situación | Qué hacer |
|---|---|
| Un alumno olvidó su contraseña | Eliminalo en el panel. Después, en Firebase → Authentication → Usuarios, borrá la cuenta `usuario@alumnos.eet3117.edu.ar`. Por último, volvé a cargarlo en el panel |
| Un alumno tiene que rendir de nuevo | En Resultados tocá **Habilitar de nuevo** (se borra su nota) y verificá que el examen esté abierto |
| Al entregar dice «Tu nota la va a informar tu profesor/a» | La entrega quedó guardada. La nota la ves igual en el panel, que siempre corrige con la clave |
| Quiero cambiar preguntas | Editá `preguntas-redes.json` (`correcta`: 0 = a, 1 = b, 2 = c, 3 = d) y volvé a cargarlo desde el panel. Máximo 30 preguntas |

## Plan gratuito

El plan Spark de Firebase alcanza de sobra para un curso. A diferencia de Supabase, el proyecto **no se pausa** por falta de uso.

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `index.html` | Página del alumno |
| `docente.html` | Panel docente |
| `config.js` | Datos de tu proyecto Firebase (**completar**) |
| `datos.js`, `util.js`, `estilos.css` | Funcionamiento y diseño |
| `firebase.js` | Librería oficial de Firebase (v13.1.0), incluida para no depender de servidores externos |
| `firestore.rules` | Reglas de seguridad para pegar en Firebase (Paso 4) |
| `preguntas-redes.json` | Preguntas **con las respuestas**. **No lo subas a GitHub** |
