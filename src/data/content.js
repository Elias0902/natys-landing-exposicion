// Central content for the landing. Edit this file to add URLs or documents.
const base = import.meta.env.BASE_URL;
export const asset = (path) => `${base}${path}`;

export const event = {
  title: 'Automatización de las Pruebas y Pipelines',
  team: 'Equipo 8',
  section: 'Sección IN3103',
  project: 'Galletas Natys',
  date: '13 de noviembre de 2026',
  formUrl: 'https://forms.gle/1q3Zo8qu2FE4vGpj9',
};

// Presentation guide: order, speaker, topic and talking points.
export const guide = [
  {
    order: 1,
    name: 'Edgmairys Apostol',
    role: 'QA Analyst / Logistics Specialist',
    topic: 'Introducción y Fundamentos de la Automatización',
    points: [
      'Dinámica rompehielo para abrir la exposición.',
      '¿Qué es? Usar scripts y herramientas que ejecutan pruebas y comparan resultados de forma automática.',
      'Manual vs. automática: velocidad, repetición, costo e ideal de uso.',
      'Cuándo sí automatizar (regresión, carga, flujos críticos) y cuándo no (una sola vez, pantallas que cambian a diario).',
      'ROI y pirámide de pruebas: unitarias en la base, luego integración/API y arriba UI.',
    ],
  },
  {
    order: 2,
    name: 'Moisés Pereira',
    role: 'Lead QA Automation Engineer',
    topic: 'Pipelines y CI/CD',
    points: [
      'Pipeline: serie de etapas Commit › Build › Pruebas › Despliegue.',
      'Integración Continua, Entrega Continua y Despliegue Continuo.',
      'Triggers: commit, pull request u horario disparan el pipeline.',
      'Ejemplo en GitHub Actions con PHPUnit: si una prueba falla, el despliegue se detiene.',
      'Beneficio: los errores se detectan minutos después de escribirse.',
    ],
  },
  {
    order: 3,
    name: 'Elías Armas',
    role: 'Lead QA Automation Engineer',
    topic: 'JMeter: fundamentos, arquitectura y diseño de scripts',
    points: [
      'Script de prueba y estructura AAA: Preparar, Actuar, Verificar.',
      'Principios: modular, independiente, legible y con nombres claros.',
      'Patrones: guiado por datos (CSV), palabras clave, Page Object y por capas.',
      'Plan en JMeter: Test Plan, Thread Group, Sampler, Assertion y Listener.',
      'Características de JMeter: open source, Java, multi-protocolo y multihilo.',
    ],
  },
  {
    order: 4,
    name: 'Ismael Torres',
    role: 'Live Performance & Demo Tester',
    topic: 'Demo en vivo con JMeter',
    points: [
      'JMeter simula de 50 a 100 usuarios comprando galletas a la vez.',
      'Flujo probado: Login › Catálogo › Carrito › Pago.',
      'Comparación en dashboard: versión con pruebas fallando vs. funcionando.',
      'Respaldo: 2 videos (prueba que falla / prueba que funciona) por si falla la demo.',
      'Código QR con la URL de los dashboards y del formulario.',
    ],
  },
  {
    order: 5,
    name: 'Santiago Loyo',
    role: 'QA Analyst / Logistics Specialist',
    topic: 'Buenas prácticas, estrategias CI/CD y cierre',
    points: [
      'Ecosistema: JMeter, PHPUnit, Selenium, Postman, Jenkins y GitHub Actions.',
      'Shift-left, paralelizar pruebas y entornos aislados.',
      'Puertas de calidad y menor time-to-market.',
      'Regla de oro: automatiza lo repetitivo y deja a las personas lo que requiere criterio.',
      'Cierre e invitación a responder la evaluación desde el QR.',
    ],
  },
];

// Documents. `file` empty = pending (drop the PDF in public/docs and set the path).
export const documents = [
  {
    id: 'triptico',
    title: 'Tríptico',
    owner: 'Elías Armas',
    type: 'pdf',
    file: 'docs/triptico-equipo8.pdf',
    thumb: 'img/thumb-triptico.png',
    category: 'Material',
  },
  {
    id: 'mapa-mental',
    title: 'Mapa mental',
    owner: 'Elías Armas',
    type: 'image',
    file: 'img/mapa-mental.jpg',
    download: 'docs/mapa-mental.pdf',
    thumb: 'img/mapa-mental.jpg',
    category: 'Material',
  },
  {
    id: 'formulario',
    title: 'Formulario de evaluación',
    owner: 'Elías Armas',
    type: 'image',
    file: 'img/banco-preguntas.jpg',
    download: 'docs/formulario-evaluacion.pdf',
    thumb: 'img/banco-preguntas.jpg',
    category: 'Evaluación',
  },
  {
    id: 'qr',
    title: 'Código QR · Evaluación',
    owner: 'Ismael Torres',
    type: 'image',
    file: 'img/qr-evaluacion.png',
    thumb: 'img/qr-evaluacion.png',
    category: 'Evaluación',
  },
  {
    id: 'asignaciones',
    title: 'Asignaciones de la exposición',
    owner: 'Equipo 8',
    type: 'pdf',
    file: 'docs/asignaciones-equipo8.pdf',
    download: 'docs/asignaciones-equipo8.docx',
    thumb: 'img/thumb-asignaciones.png',
    category: 'Organización',
  },
  {
    id: 'guia',
    title: 'Guía de la exposición',
    owner: 'Edgmairys Apostol',
    type: 'pdf',
    file: '',
    category: 'Organización',
  },
  {
    id: 'informe',
    title: 'Informe para la docente',
    owner: 'Moisés Pereira',
    type: 'pdf',
    file: 'docs/informe-docente.pdf',
    download: 'docs/informe-docente.docx',
    thumb: 'img/thumb-informe.png',
    category: 'Organización',
  },
  {
    id: 'mapa-conceptual',
    title: 'Mapa conceptual',
    owner: 'Moisés Pereira',
    type: 'pdf',
    file: 'docs/mapa-conceptual.pdf',
    thumb: 'img/thumb-mapa-conceptual.png',
    category: 'Material',
  },
  {
    id: 'presentacion',
    title: 'Presentación PowerPoint',
    owner: 'Santiago Loyo',
    type: 'pdf',
    file: 'docs/diapositivas-equipo8.pptx',
    thumb: 'img/thumb-diapositivas.png',
    category: 'Material',
  },
];
