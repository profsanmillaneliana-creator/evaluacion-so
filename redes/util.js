// Utilidades compartidas por las páginas del alumno y del docente
export const $ = (s, r) => (r || document).querySelector(s);
export const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
export const LETRAS = ["a", "b", "c", "d", "e", "f"];

export function esc(t) {
  return String(t ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
// Nota de 1 a 10, proporcional a las respuestas correctas
export function calcularNota(correctas, total) {
  if (!total) return 1;
  return Math.max(1, Math.round(correctas * 1000 / total) / 100);
}
export function fmtNota(n) { return (Math.round(Number(n) * 100) / 100).toString().replace(".", ","); }
export function fmtFecha(f) {
  if (!f) return "";
  const d = typeof f.toDate === "function" ? f.toDate() : new Date(f);
  return d.toLocaleString("es-AR", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
}
export function configurado() {
  const f = (window.CONFIG || {}).firebase || {};
  return !!(f.apiKey && f.projectId && f.appId);
}
export function avisoConfig() {
  document.body.innerHTML =
    '<div class="wrap"><div class="card"><h2>Falta configurar Firebase</h2>' +
    '<p>Completá los datos de <code>firebase</code> en el archivo <code>config.js</code>. Los pasos están en <code>LEEME.md</code>.</p></div></div>';
}
export function encabezado() {
  const c = window.CONFIG;
  return `<p class="escuela"><b>${esc(c.ESCUELA)}</b></p>
          <p class="escuela">${esc(c.MATERIA)} · ${esc(c.CURSO)}</p>`;
}
