// =====================================================================
//  Genera el PDF de la evaluación resuelta y corregida de cada alumno
// =====================================================================
import { jsPDF } from "./jspdf.js";
import { calcularNota, fmtNota, fmtFecha, LETRAS } from "./util.js";

const A4 = { w: 210, h: 297 }, M = 15, ANCHO = A4.w - 2 * M;
const AZUL = [31, 95, 191], VERDE = [30, 125, 69], ROJO = [179, 38, 30], GRIS = [91, 100, 118], NEGRO = [29, 36, 51];
const FONDO_OK = [230, 244, 236], FONDO_MAL = [251, 234, 234];

// Las fuentes estándar del PDF no traen algunos símbolos: se reemplazan
function limpiar(t) {
  return String(t ?? "")
    .replace(/[→⇒]/g, "->").replace(/[✔✓]/g, "").replace(/[✘✗]/g, "")
    .replace(/[^\u0000-ÿ–—‘’“”•…€]/g, "");
}

export function descargarPDF(lista, ctx, nombreArchivo) {
  const doc = new jsPDF({ unit: "mm", format: "a4" });
  lista.forEach((item, i) => {
    if (i > 0) doc.addPage();
    paginaAlumno(doc, item, ctx);
  });
  pies(doc, ctx);
  doc.save(nombreArchivo);
}

function paginaAlumno(doc, { alumno, entrega }, ctx) {
  const C = ctx.config, k = ctx.clave.correctas || [], ex = ctx.clave.explicaciones || [];
  const total = entrega.respuestas.length;
  const correctas = entrega.respuestas.filter((r, i) => r === k[i]).length;
  const nota = calcularNota(correctas, total), aprobado = nota >= C.NOTA_APROBACION;
  let y = M;

  // ---------- Encabezado ----------
  doc.setFont("helvetica", "bold").setFontSize(11).setTextColor(...NEGRO);
  doc.text(limpiar(C.ESCUELA), M, y + 4); y += 6;
  doc.setFont("helvetica", "normal").setFontSize(9).setTextColor(...GRIS);
  doc.text(limpiar(`${C.MATERIA} · ${C.CURSO}`), M, y + 3); y += 7;
  doc.setFont("helvetica", "bold").setFontSize(13).setTextColor(...NEGRO);
  const tit = doc.splitTextToSize(limpiar(ctx.titulo), ANCHO);
  doc.text(tit, M, y + 4); y += tit.length * 5.5 + 2;
  doc.setDrawColor(...AZUL).setLineWidth(0.6).line(M, y, A4.w - M, y); y += 5;

  // ---------- Datos del alumno y nota ----------
  const altoCaja = 26;
  doc.setDrawColor(...(aprobado ? VERDE : ROJO)).setLineWidth(0.5).roundedRect(M, y, ANCHO, altoCaja, 2, 2);
  doc.setFont("helvetica", "bold").setFontSize(12).setTextColor(...NEGRO);
  doc.text(limpiar(alumno.nombre), M + 4, y + 7);
  doc.setFont("helvetica", "normal").setFontSize(9.5).setTextColor(...GRIS);
  doc.text(limpiar(`Usuario: ${alumno.usuario}    Curso: ${alumno.curso || "-"}`), M + 4, y + 13);
  doc.text(limpiar(`Entregado: ${fmtFecha(entrega.fecha)}`), M + 4, y + 18.5);
  doc.text(`Respuestas correctas: ${correctas} de ${total}`, M + 4, y + 23.5);
  // nota a la derecha
  const xN = A4.w - M - 4;
  doc.setFont("helvetica", "bold").setFontSize(28).setTextColor(...(aprobado ? VERDE : ROJO));
  doc.text(fmtNota(nota), xN, y + 14, { align: "right" });
  doc.setFontSize(11).text(aprobado ? "APROBADO" : "DESAPROBADO", xN, y + 21, { align: "right" });
  y += altoCaja + 4;
  doc.setFont("helvetica", "normal").setFontSize(8.5).setTextColor(...GRIS);
  doc.text(limpiar(`Nota de 1 a 10 proporcional a las respuestas correctas. Se aprueba con ${fmtNota(C.NOTA_APROBACION)}.  ` +
    "Referencias: fondo verde = respuesta correcta · fondo rojo = respuesta elegida incorrecta."), M, y, { maxWidth: ANCHO });
  y += 8;

  // ---------- Preguntas ----------
  let seccion = null;
  ctx.preguntas.forEach((p, i) => {
    const elegida = entrega.respuestas[i], correcta = k[i], bien = elegida === correcta;
    doc.setFont("helvetica", "bold").setFontSize(10);
    const enun = doc.splitTextToSize(limpiar(`${i + 1}. ${p.enunciado}`), ANCHO - 26);
    const ops = p.opciones.map((op, j) => {
      // se mide con la misma fuente con la que se va a escribir (negrita si está resaltada)
      doc.setFont("helvetica", (j === correcta || j === elegida) ? "bold" : "normal").setFontSize(9.5);
      let suf = "";
      if (j === elegida && j === correcta) suf = "   (respuesta del alumno - correcta)";
      else if (j === elegida) suf = "   (respuesta del alumno)";
      else if (j === correcta) suf = "   (respuesta correcta)";
      return doc.splitTextToSize(limpiar(`${LETRAS[j]}) ${op}${suf}`), ANCHO - 8);
    });
    doc.setFont("helvetica", "italic").setFontSize(8.8);
    const expl = ex[i] ? doc.splitTextToSize(limpiar(ex[i]), ANCHO - 4) : [];
    const alto = (p.seccion !== seccion ? 8 : 0) + enun.length * 4.6 + 2 +
      ops.reduce((s, l) => s + l.length * 4.3 + 2, 0) + (expl.length ? expl.length * 3.9 + 3 : 0) + 4;
    if (y + alto > A4.h - 18) { doc.addPage(); y = M; }

    if (p.seccion !== seccion) {
      seccion = p.seccion;
      doc.setFont("helvetica", "bold").setFontSize(10).setTextColor(...AZUL);
      doc.text(limpiar(seccion.toUpperCase()), M, y + 4); y += 8;
    }
    // enunciado + marca
    doc.setFont("helvetica", "bold").setFontSize(10).setTextColor(...NEGRO);
    doc.text(enun, M, y + 4);
    doc.setFontSize(9).setTextColor(...(bien ? VERDE : ROJO));
    doc.text(bien ? "CORRECTA" : "INCORRECTA", A4.w - M, y + 4, { align: "right" });
    y += enun.length * 4.6 + 2;
    // opciones
    doc.setFont("helvetica", "normal").setFontSize(9.5);
    ops.forEach((lineas, j) => {
      const h = lineas.length * 4.3 + 1.2;
      const fondo = j === correcta ? FONDO_OK : (j === elegida ? FONDO_MAL : null);
      if (fondo) { doc.setFillColor(...fondo).roundedRect(M + 2, y, ANCHO - 2, h, 1, 1, "F"); }
      doc.setTextColor(...(j === correcta ? VERDE : (j === elegida ? ROJO : NEGRO)));
      doc.setFont("helvetica", fondo ? "bold" : "normal");
      doc.text(lineas, M + 4, y + 3.6);
      y += h + 0.8;
    });
    // explicación
    if (expl.length) {
      doc.setFont("helvetica", "italic").setFontSize(8.8).setTextColor(...GRIS);
      doc.text(expl, M + 2, y + 3.4);
      y += expl.length * 3.9 + 3;
    }
    y += 3;
  });

  // ---------- Firma ----------
  if (y + 20 > A4.h - 18) { doc.addPage(); y = M; }
  y += 12;
  doc.setDrawColor(...GRIS).setLineWidth(0.3);
  doc.line(M, y, M + 70, y); doc.line(A4.w - M - 70, y, A4.w - M, y);
  doc.setFont("helvetica", "normal").setFontSize(8.5).setTextColor(...GRIS);
  doc.text("Firma del docente", M, y + 4); doc.text("Firma del alumno/a", A4.w - M - 70, y + 4);
}

function pies(doc, ctx) {
  const n = doc.getNumberOfPages();
  for (let i = 1; i <= n; i++) {
    doc.setPage(i);
    doc.setFont("helvetica", "normal").setFontSize(8).setTextColor(...GRIS);
    doc.text(limpiar(`${ctx.config.ESCUELA} · ${ctx.config.MATERIA}`), M, A4.h - 8);
    doc.text(`Página ${i} de ${n}`, A4.w - M, A4.h - 8, { align: "right" });
  }
}
