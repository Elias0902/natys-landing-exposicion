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

// Presentation guide: the 5 official points, speaker, talking points and the
// Naty's examples that go in the guide and the slides (pedido de la profesora).
export const guide = [
  {
    order: 1,
    name: 'Elías Armas',
    role: 'Módulos: Entregas y Chatbot',
    topic: 'Fundamentos de la Automatización de Pruebas',
    points: [
      'Apertura con rompehielo: ¿quién ha probado lo mismo diez veces a mano?',
      '¿Qué es? Scripts y herramientas que ejecutan la prueba y comparan el resultado con lo esperado: datos, acción y verificación.',
      'Prueba manual vs. automatizada: velocidad, repetición, costo y criterio humano.',
      'Cuándo sí automatizar (repetitivo, estable y crítico) y cuándo no (una sola vez, usabilidad, pantallas en rediseño).',
      'Pirámide de pruebas (Mike Cohn) y las 7 etapas para automatizar.',
    ],
    examples: [
      'UT-03 (PHPUnit): modificar la entrega 999 inexistente → responde «Entrega no existe» y hace rollback.',
      'Formulario «Modificar Entrega» revisado a mano vs. UI-01 en Selenium IDE.',
      'Suite de Entregas: 7 pruebas y 28 aserciones en 0,031 s.',
      'Pirámide de Naty\'s: EntregaTest (base) · IT-01 y Postman (medio) · Selenium y Codeception (cima).',
      'Errores reales encontrados: BUG-01 (Entregas) y BUG-05 (Chatbot dejaba pasar «SELECT 1; DROP TABLE…»).',
    ],
  },
  {
    order: 2,
    name: 'Edgmairys Apóstol',
    role: 'Módulos: Clientes, Proveedores y Categorías',
    topic: 'Arquitectura y Diseño de Scripts de Prueba',
    points: [
      'Estructura de un script: Preparar, Actuar y Verificar (AAA).',
      'Principios: modular, independiente, legible y con nombres que dicen qué prueban.',
      'Patrones de diseño: guiado por datos, palabras clave, Page Object y arquitectura por capas.',
      'Organización del proyecto de pruebas: carpeta tests/, datos de prueba y configuración (phpunit.xml).',
      'Objetos simulados (mocks) para probar sin tocar la base de datos real.',
    ],
    examples: [
      'Clientes: un mismo script con varios datos (cédula vacía, inválida, repetida) usando un dataProvider de PHPUnit.',
      'Page Object del formulario de Clientes para que Selenium no dependa de cada botón.',
      'EntregaTest.php como modelo de prueba AAA con mocks.',
      'Nombres claros: test_registrar_cliente_sin_cedula_es_rechazado.',
    ],
  },
  {
    order: 3,
    name: 'Moisés Pereira',
    role: 'Módulos: Pedidos, Carrito y Ecommerce',
    topic: 'Definición y Tipos de Pipeline',
    points: [
      '¿Qué es un pipeline? Etapas automáticas en cadena: Commit › Build › Pruebas › Despliegue.',
      'Tipos: Integración Continua (CI), Entrega Continua y Despliegue Continuo (CD).',
      'Disparadores: push, pull request, horario programado o ejecución manual.',
      'Si una etapa falla, el pipeline se detiene y avisa: nada roto llega a producción.',
    ],
    examples: [
      'Pipeline de Naty\'s en GitHub Actions: composer install › PHPUnit › pytest del chatbot › despliegue.',
      'Pedidos: si falla la prueba de registrar pedido, el despliegue no se ejecuta.',
      'Esta misma landing se publica sola con un pipeline de GitHub Actions al hacer push.',
    ],
  },
  {
    order: 4,
    name: 'Ismael Torres',
    role: 'Módulos: Promociones, Pagos y Cuentas',
    topic: 'Herramientas de Ecosistema',
    points: [
      'Las herramientas se escogen según el nivel de la prueba.',
      'Unitarias: PHPUnit (PHP) y pytest (Python).',
      'API: Postman · Interfaz: Selenium IDE · Aceptación: Codeception.',
      'Carga y concurrencia: Locust · Orquestación CI/CD: GitHub Actions (alternativas: Jenkins, GitLab CI).',
      'Criterios para elegir: lenguaje del sistema, costo, comunidad e integración con el pipeline.',
    ],
    examples: [
      'Postman API-01: obtener una entrega por ID y validar la respuesta.',
      'pytest en el microservicio del chatbot (detectó BUG-05).',
      'Locust: varios usuarios consultando al chatbot a la vez (detectó BUG-07).',
      'Mapa del ecosistema de Naty\'s: qué herramienta prueba qué parte del sistema.',
    ],
  },
  {
    order: 5,
    name: 'Santiago Loyo',
    role: 'Módulos: Productos, Compras y Producciones',
    topic: 'Estrategias Avanzadas e Integración Continua (CI/CD)',
    points: [
      'Shift-left: probar desde el inicio, no al final.',
      'Puertas de calidad (quality gates): no se integra ni despliega si las pruebas fallan.',
      'Paralelizar pruebas, entornos aislados y base de datos de prueba.',
      'Simular servicios externos y guardar claves como secretos del pipeline.',
      'Cierre: «Automatiza lo repetitivo, estable y crítico» e invitación a la evaluación por el QR.',
    ],
    examples: [
      'Productos: las pruebas corren en cada pull request antes de unir el código.',
      'BUG-07: sin cuota de Gemini el chatbot tardaba ~40 s; en CI se simula la API y la clave va en un secreto.',
      'Dashboard de la landing: pipeline con pruebas fallando vs. funcionando.',
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
    owner: 'Elías Armas',
    type: 'pdf',
    file: 'docs/guia-exposicion.pdf',
    category: 'Organización',
  },
  {
    id: 'punto1',
    title: 'Punto 1 · Fundamentos de la Automatización',
    owner: 'Elías Armas',
    type: 'pdf',
    file: 'docs/punto1-fundamentos-elias.pdf',
    download: 'docs/punto1-fundamentos-elias.docx',
    thumb: 'img/thumb-punto1.png',
    category: 'Puntos',
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
    owner: 'Equipo 8',
    type: 'pdf',
    file: 'docs/diapositivas-equipo8.pdf',
    download: 'docs/diapositivas-equipo8.pptx',
    thumb: 'img/thumb-diapositivas.png',
    category: 'Material',
  },
];
