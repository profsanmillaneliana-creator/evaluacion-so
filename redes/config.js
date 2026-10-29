// =====================================================================
//  CONFIGURACIÓN
// =====================================================================
window.CONFIG = {
  // Pegá acá el objeto firebaseConfig de tu proyecto
  // (Firebase → Configuración del proyecto ⚙ → General → Tus apps → app web).
  // Estos datos son públicos por diseño: la seguridad la dan las reglas de Firestore.
  firebase: {
    apiKey: "",
    authDomain: "",
    projectId: "",
    storageBucket: "",
    messagingSenderId: "",
    appId: ""
  },

  // Dominio ficticio con el que se arma el "correo" interno de cada alumno
  // (usuario 45123456 → 45123456@alumnos.eet3117.edu.ar). No se envían correos.
  // No lo cambies después de crear alumnos.
  DOMINIO_ALUMNOS: "alumnos.eet3117.edu.ar",

  ESCUELA: "E.E.T. N° 3117 «Mtro. Daniel Oscar Reyes»",
  MATERIA: "Conexión entre dos computadoras",
  CURSO: "2° año 4ª división · Ciclo Superior · Orientación Informática",
  TITULO: "Evaluación: Modelo OSI, modelo TCP/IP y comandos ping e ipconfig",
  NOTA_APROBACION: 6
};
