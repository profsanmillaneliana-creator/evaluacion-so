// Funciones compartidas por index.html (alumno) y docente.html (docente)

function configurado() {
  const c = window.CONFIG || {};
  return !!(c.SUPABASE_URL && c.SUPABASE_KEY);
}

// Llama a una función de la base de datos (Supabase RPC)
async function rpc(nombre, parametros) {
  const url = window.CONFIG.SUPABASE_URL.replace(/\/+$/, "") + "/rest/v1/rpc/" + nombre;
  let resp;
  try {
    resp = await fetch(url, {
      method: "POST",
      headers: { "apikey": window.CONFIG.SUPABASE_KEY, "Content-Type": "application/json" },
      body: JSON.stringify(parametros || {})
    });
  } catch (e) {
    throw new Error("No se pudo conectar con la base de datos. Revisá tu conexión a Internet.");
  }
  let datos = null;
  try { datos = await resp.json(); } catch (e) {}
  if (!resp.ok) {
    console.error("Error de Supabase", resp.status, datos);
    if (resp.status === 401 || resp.status === 403)
      throw new Error("La clave de Supabase de config.js no es válida.");
    if (resp.status === 404)
      throw new Error("No se encontró la función en la base de datos. ¿Ejecutaste schema.sql en Supabase?");
    throw new Error("Error del servidor (" + resp.status + "). Probá de nuevo en un momento.");
  }
  if (datos && datos.ok === false) throw new Error(datos.error || "Error.");
  return datos;
}

// Atajos
const $ = (sel, raiz) => (raiz || document).querySelector(sel);
const $$ = (sel, raiz) => Array.from((raiz || document).querySelectorAll(sel));
function esc(t) {
  return String(t ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
function fmtNota(n) {
  n = Number(n);
  return (Math.round(n * 100) / 100).toString().replace(".", ",");
}
function fmtFecha(f) {
  try {
    return new Date(f).toLocaleString("es-AR", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
  } catch (e) { return f; }
}
const LETRAS = ["a", "b", "c", "d", "e", "f"];

function mostrarAvisoConfig() {
  document.body.innerHTML =
    '<div class="wrap"><div class="card"><h2>Falta configurar la base de datos</h2>' +
    '<p>Abrí el archivo <code>config.js</code> y completá <b>SUPABASE_URL</b> y <b>SUPABASE_KEY</b> ' +
    'con los datos de tu proyecto de Supabase. Los pasos están en <code>README.md</code>.</p></div></div>';
}
