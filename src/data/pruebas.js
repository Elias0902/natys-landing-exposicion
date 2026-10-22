// Informes de pruebas por módulo de Natys (natys-larence).
//
// Para subir un informe: copien el PDF a public/docs/pruebas/, el Word al lado
// (opcional) y una miniatura a public/img/pruebas/. Luego escriban las rutas
// en `pdf`, `docx` y `thumb`. Si `pdf` y `docx` están vacíos, la tarjeta
// aparece como "Pendiente".

export const integrantes = [
  { id: 'moises', nombre: 'Moisés Pereira', principal: 'pedidos' },
  { id: 'edmairys', nombre: 'Edgmairys Apostol', principal: 'clientes' },
  { id: 'santiago', nombre: 'Santiago Loyo', principal: 'productos' },
  { id: 'ismael', nombre: 'Ismael Torres', principal: 'promociones' },
  { id: 'elias', nombre: 'Elías Armas', principal: 'entregas' },
];

const vacio = { pdf: '', docx: '', thumb: '' };
const m = (id, nombre, responsable, informe = vacio) => ({ id, nombre, responsable, ...informe });

export const modulos = [
  // Moisés
  m('pedidos', 'Pedidos', 'moises', {
    pdf: 'docs/pruebas/informe-pedidos.pdf',
    docx: 'docs/pruebas/informe-pedidos.docx',
    thumb: 'img/pruebas/thumb-informe-pedidos.png',
  }),
  m('ecommerce', 'Ecommerce', 'moises'),
  m('carrito', 'Carrito de compras', 'moises', {
    pdf: 'docs/pruebas/informe-carrito.pdf',
    docx: 'docs/pruebas/informe-carrito.docx',
    thumb: 'img/pruebas/thumb-informe-carrito.png',
  }),
  m('dashboard', 'Dashboard', 'moises'),
  // Extra: Moisés también probó estos módulos (no estaban en las asignaciones)
  m('moneda', 'Moneda', 'moises', {
    pdf: 'docs/pruebas/informe-moneda.pdf',
    docx: 'docs/pruebas/informe-moneda.docx',
    thumb: 'img/pruebas/thumb-informe-moneda.png',
  }),
  m('modulo', 'Módulos (gestión)', 'moises', {
    pdf: 'docs/pruebas/informe-modulo.pdf',
    docx: 'docs/pruebas/informe-modulo.docx',
    thumb: 'img/pruebas/thumb-informe-modulo.png',
  }),
  m('rol', 'Roles', 'moises', {
    pdf: 'docs/pruebas/informe-rol.pdf',
    docx: 'docs/pruebas/informe-rol.docx',
    thumb: 'img/pruebas/thumb-informe-rol.png',
  }),

  // Edmairys
  m('clientes', 'Clientes', 'edmairys'),
  m('proveedores', 'Proveedores', 'edmairys'),
  m('categorias', 'Categorías', 'edmairys'),

  // Santiago
  m('productos', 'Productos', 'santiago', {
    pdf: 'docs/pruebas/informe-productos.pdf',
    docx: 'docs/pruebas/informe-productos.docx',
    thumb: 'img/pruebas/thumb-informe-productos.png',
  }),
  m('compras', 'Compras', 'santiago', {
    pdf: 'docs/pruebas/informe-compras.pdf',
    docx: 'docs/pruebas/informe-compras.docx',
    thumb: 'img/pruebas/thumb-informe-compras.png',
  }),
  m('producciones', 'Producciones', 'santiago', {
    pdf: 'docs/pruebas/informe-producciones.pdf',
    docx: 'docs/pruebas/informe-producciones.docx',
    thumb: 'img/pruebas/thumb-informe-producciones.png',
  }),

  // Ismael
  m('promociones', 'Promociones', 'ismael'),
  m('pagos', 'Pagos', 'ismael'),
  m('cobrar', 'Cuentas por Cobrar', 'ismael'),
  m('pagar', 'Cuentas por Pagar', 'ismael'),
  m('materias', 'Materias Primas', 'ismael'),

  // Elías
  m('entregas', 'Entregas', 'elias', {
    pdf: 'docs/pruebas/informe-entregas.pdf',
    docx: 'docs/pruebas/informe-entregas.docx',
    thumb: 'img/pruebas/thumb-informe-entregas.png',
  }),
  m('chatbot', 'Chatbot', 'elias', {
    pdf: 'docs/pruebas/informe-chatbot.pdf',
    docx: 'docs/pruebas/informe-chatbot.docx',
    thumb: 'img/pruebas/thumb-informe-chatbot.png',
  }),
];
