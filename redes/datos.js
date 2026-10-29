// =====================================================================
//  Acceso a Firebase (Authentication + Cloud Firestore)
//  Las páginas solo usan las funciones exportadas acá.
// =====================================================================
import {
  initializeApp, deleteApp,
  getAuth, signInWithEmailAndPassword, signOut, createUserWithEmailAndPassword,
  setPersistence, browserSessionPersistence, inMemoryPersistence,
  getFirestore, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, collection,
  serverTimestamp, writeBatch
} from "./firebase.js";

const CFG = window.CONFIG;
const app = initializeApp(CFG.firebase);
const auth = getAuth(app);
const db = getFirestore(app);

// La sesión se cierra al cerrar la pestaña (importante en las PC del laboratorio)
const persistenciaLista = setPersistence(auth, browserSessionPersistence).catch(() => {});

// ---------- Utilidades ----------
export function normalizarUsuario(u) {
  return String(u || "").trim().toLowerCase().replace(/\s+/g, "");
}
function emailDe(usuario) {
  return normalizarUsuario(usuario) + "@" + CFG.DOMINIO_ALUMNOS;
}
function traducir(e) {
  const c = (e && e.code) || "";
  if (/invalid-credential|wrong-password|user-not-found|invalid-email|invalid-login/.test(c))
    return "Usuario o contraseña incorrectos.";
  if (/too-many-requests/.test(c))
    return "Demasiados intentos fallidos. Esperá unos minutos y probá de nuevo.";
  if (/network-request-failed|unavailable/.test(c))
    return "No hay conexión con el servidor. Revisá Internet y probá de nuevo.";
  if (/permission-denied/.test(c))
    return "No tenés permiso para hacer esto.";
  if (/user-disabled/.test(c)) return "Este usuario está deshabilitado.";
  if (/api-key|invalid-api-key|configuration-not-found|operation-not-allowed/.test(c))
    return "Firebase no está bien configurado (revisá config.js y que el ingreso con correo y contraseña esté habilitado).";
  return (e && e.message) || "Error inesperado.";
}
async function intentar(fn) {
  try { return await fn(); } catch (e) { const err = new Error(traducir(e)); err.code = e && e.code; throw err; }
}
const ref = (...p) => doc(db, ...p);

// =====================================================================
//  ALUMNO
// =====================================================================
let alumnoActual = null;   // {uid, usuario, nombre, curso}

export async function alumnoIngresar(usuario, pass) {
  return intentar(async () => {
    await persistenciaLista;
    const cred = await signInWithEmailAndPassword(auth, emailDe(usuario), pass);
    const uid = cred.user.uid;
    const a = await getDoc(ref("alumnos", uid));
    if (!a.exists()) {
      await signOut(auth);
      throw Object.assign(new Error("Tu usuario no está habilitado para este examen. Consultá con tu profesor/a."), { code: "x" });
    }
    alumnoActual = Object.assign({ uid }, a.data());
    return alumnoEstado();
  });
}

// Estado actual: datos del alumno, del examen y de su entrega (si existe)
export async function alumnoEstado() {
  return intentar(async () => {
    const [ex, en] = await Promise.all([
      getDoc(ref("config", "examen")),
      getDoc(ref("entregas", alumnoActual.uid))
    ]);
    const examen = ex.exists() ? ex.data() : { titulo: "Evaluación", abierto: false, mostrar_correccion: false };
    let entrega = en.exists() ? en.data() : null;
    // Si entregó pero la nota no quedó registrada (por ejemplo, se cortó Internet), se reintenta.
    if (entrega && typeof entrega.correctas !== "number") {
      const c = await registrarAciertos(entrega.respuestas.length);
      if (c !== null) entrega.correctas = c;
    }
    return { alumno: alumnoActual, examen, entrega };
  });
}

export async function alumnoPreguntas() {
  return intentar(async () => {
    const s = await getDoc(ref("config", "preguntas"));
    if (!s.exists()) throw Object.assign(new Error("El examen todavía no tiene preguntas cargadas."), { code: "x" });
    return s.data().lista;
  });
}

// Guarda las respuestas (una sola vez) y registra los aciertos verificados por la base de datos
export async function alumnoEntregar(respuestas) {
  return intentar(async () => {
    await setDoc(ref("entregas", alumnoActual.uid), {
      respuestas, fecha: serverTimestamp(),
      usuario: alumnoActual.usuario, nombre: alumnoActual.nombre, curso: alumnoActual.curso || ""
    });
    const correctas = await registrarAciertos(respuestas.length);
    return { correctas, total: respuestas.length };
  });
}

// El alumno no conoce la clave, así que propone cada cantidad posible (0..n).
// Las reglas de seguridad solo aceptan la cantidad que coincide con la clave real.
async function registrarAciertos(n) {
  const r = ref("entregas", alumnoActual.uid);
  const intentos = [];
  for (let k = 0; k <= n; k++) intentos.push(updateDoc(r, { correctas: k }).then(() => k));
  const res = await Promise.allSettled(intentos);
  const ok = res.find(x => x.status === "fulfilled");
  if (ok) return ok.value;
  // Puede que ya estuviera registrada: se lee del servidor
  try {
    const s = await getDoc(r);
    if (s.exists() && typeof s.data().correctas === "number") return s.data().correctas;
  } catch (e) {}
  return null;
}

// Clave de corrección: solo disponible si el docente la habilitó
export async function alumnoCorreccion() {
  try {
    const s = await getDoc(ref("config", "clave"));
    return s.exists() ? s.data() : null;
  } catch (e) { return null; }
}

export async function salir() {
  alumnoActual = null;
  await signOut(auth).catch(() => {});
}

// =====================================================================
//  DOCENTE
// =====================================================================
export async function docenteIngresar(email, pass) {
  return intentar(async () => {
    await persistenciaLista;
    const cred = await signInWithEmailAndPassword(auth, String(email).trim(), pass);
    try {
      // Solo el docente (UID en las reglas) puede leer la clave. Si falla, falta configurar las reglas.
      await getDoc(ref("config", "clave"));
    } catch (e) {
      const uid = cred.user.uid;
      await signOut(auth);
      throw Object.assign(new Error(
        "Esta cuenta todavía no tiene permisos de docente. Copiá tu UID en las reglas de Firestore " +
        "(en lugar de PEGAR_AQUI_TU_UID) y publicalas. Tu UID es: " + uid), { code: "x", uid });
    }
    return cred.user.email;
  });
}

export async function docenteDatos() {
  return intentar(async () => {
    const [ex, pr, cl, al, en] = await Promise.all([
      getDoc(ref("config", "examen")), getDoc(ref("config", "preguntas")), getDoc(ref("config", "clave")),
      getDocs(collection(db, "alumnos")), getDocs(collection(db, "entregas"))
    ]);
    const entregas = {};
    en.forEach(d => { entregas[d.id] = d.data(); });
    const alumnos = [];
    al.forEach(d => alumnos.push(Object.assign({ uid: d.id }, d.data())));
    alumnos.sort((a, b) => (a.curso || "").localeCompare(b.curso || "") || (a.nombre || "").localeCompare(b.nombre || ""));
    return {
      examen: ex.exists() ? ex.data() : null,
      preguntas: pr.exists() ? pr.data().lista : [],
      clave: cl.exists() ? cl.data() : { correctas: [], explicaciones: [] },
      alumnos, entregas
    };
  });
}

export async function docenteGuardarExamen(datos) {
  return intentar(() => setDoc(ref("config", "examen"), datos, { merge: true }));
}

// lista = [{seccion, enunciado, opciones, correcta, explicacion}]
export async function docenteCargarPreguntas(lista, titulo) {
  return intentar(async () => {
    const b = writeBatch(db);
    b.set(ref("config", "preguntas"), {
      lista: lista.map(p => ({ seccion: p.seccion || "", enunciado: p.enunciado, opciones: p.opciones }))
    });
    b.set(ref("config", "clave"), {
      correctas: lista.map(p => p.correcta),
      explicaciones: lista.map(p => p.explicacion || "")
    });
    const ex = await getDoc(ref("config", "examen"));
    if (!ex.exists()) b.set(ref("config", "examen"), { titulo: titulo || "Evaluación", abierto: false, mostrar_correccion: false });
    await b.commit();
  });
}

function generarPass() {
  const abc = "abcdefghjkmnpqrstuvwxyz23456789";
  const b = new Uint8Array(6); crypto.getRandomValues(b);
  return Array.from(b, x => abc[x % abc.length]).join("");
}

// lista = [{usuario, nombre, curso, pass}] → crea las cuentas y devuelve las contraseñas
export async function docenteCrearAlumnos(lista, alAvanzar) {
  const app2 = initializeApp(CFG.firebase, "alta-" + Date.now());
  const auth2 = getAuth(app2);
  await setPersistence(auth2, inMemoryPersistence).catch(() => {});
  const creados = [], omitidos = [];
  try {
    for (let i = 0; i < lista.length; i++) {
      const x = lista[i];
      const usuario = normalizarUsuario(x.usuario), nombre = String(x.nombre || "").trim(), curso = String(x.curso || "").trim();
      let pass = String(x.pass || "").trim();
      if (alAvanzar) alAvanzar(i + 1, lista.length);
      if (!usuario || !nombre) { omitidos.push({ usuario, motivo: "Falta usuario o nombre" }); continue; }
      if (!/^[a-z0-9._-]+$/.test(usuario)) { omitidos.push({ usuario, motivo: "El usuario solo puede tener letras sin acentos, números, punto o guion" }); continue; }
      if (!pass) pass = generarPass();
      if (pass.length < 6) { omitidos.push({ usuario, motivo: "La contraseña debe tener al menos 6 caracteres" }); continue; }
      try {
        const cred = await createUserWithEmailAndPassword(auth2, emailDe(usuario), pass);
        await setDoc(ref("alumnos", cred.user.uid), { usuario, nombre, curso, creado: serverTimestamp() });
        await signOut(auth2);
        creados.push({ usuario, nombre, curso, pass });
      } catch (e) {
        const motivo = /email-already-in-use/.test(e.code || "")
          ? "Ese usuario ya existe (si lo borraste, eliminá también su cuenta en Firebase → Authentication)"
          : traducir(e);
        omitidos.push({ usuario, motivo });
      }
    }
  } finally {
    await deleteApp(app2).catch(() => {});
  }
  return { creados, omitidos };
}

export async function docenteHabilitar(uid) {
  return intentar(() => deleteDoc(ref("entregas", uid)));
}

export async function docenteBorrarAlumno(uid) {
  return intentar(async () => {
    await deleteDoc(ref("entregas", uid));
    await deleteDoc(ref("alumnos", uid));
  });
}
