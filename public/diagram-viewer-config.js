// Visor oficial de Draw.io servido desde la misma landing, sin navegación externa.
(() => {
const base = new URL('vendor/drawio/', location.href).href.replace(/\/$/, '');
window.DRAWIO_BASE_URL = base;
window.DRAWIO_SERVER_URL = base + '/';
window.PROXY_URL = base + '/proxy';
window.STYLE_PATH = base + '/styles';
window.SHAPES_PATH = base + '/shapes';
window.STENCIL_PATH = base + '/stencils';
window.GRAPH_IMAGE_PATH = base + '/img';
window.mxImageBasePath = base + '/mxgraph/images';
window.mxBasePath = base + '/mxgraph/';
window.mxLoadResources = false;
window.mxLoadStylesheets = false;
window.urlParams = { math: '0', lightbox: '0', nav: '0' };
window.onDrawioViewerLoad = function () {};
})();
