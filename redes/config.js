// =====================================================================
//  CONFIGURACIÓN
// =====================================================================
window.CONFIG = {
  // Pegá acá el objeto firebaseConfig de tu proyecto
  // (Firebase → Configuración del proyecto ⚙ → General → Tus apps → app web).
  // Estos datos son públicos por diseño: la seguridad la dan las reglas de Firestore.
  firebase: {
    apiKey: "AIzaSyD7WUfg_Sjbu_m3s0dZn-8VI-zTY_ccPHE",
    authDomain: "redes-eet3117.firebaseapp.com",
    projectId: "redes-eet3117",
    storageBucket: "redes-eet3117.firebasestorage.app",
    messagingSenderId: "137857507345",
    appId: "1:137857507345:web:015b9ad074ae2eaa4151b0"
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
