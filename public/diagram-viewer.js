/* global GraphViewer, mxUtils */
(() => {
  const container = document.getElementById('graph');
  const status = document.getElementById('status');
  const pages = document.getElementById('pages');
  let viewer;
  let thumbnail = false;
  let svg;
  let bounds;
  let view;
  let drag;
  const report = (data) => parent.postMessage({ channel: 'natys-diagram', ...data }, location.origin);
  // Keep the drawing in its original coordinates and fit its SVG viewport.
  // Translating the mxGraph canvas itself can leave the saved diagram offscreen
  // until the first drag, especially inside a freshly mounted iframe.
  const paint = () => {
    if (!svg || !view) return;
    svg.setAttribute('viewBox', [view.x, view.y, view.width, view.height].join(' '));
    document.getElementById('scale').textContent = Math.round(bounds.width / view.width * 100) + '%';
  };
  const fit = () => {
    if (!viewer?.graph) return;
    const graph = viewer.graph;
    graph.view.validate();
    const box = graph.getGraphBounds();
    if (!(box.width > 0 && box.height > 0)) return;
    svg = graph.view.canvas.ownerSVGElement;
    const padding = Math.max(box.width, box.height) * (thumbnail ? 0.025 : 0.04);
    bounds = { x: box.x - padding, y: box.y - padding, width: box.width + padding * 2, height: box.height + padding * 2 };
    view = { ...bounds };
    svg.setAttribute('width', '100%');
    svg.setAttribute('height', '100%');
    svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
    Object.assign(svg.style, { position: 'absolute', inset: '0', width: '100%', height: '100%', minWidth: '0', minHeight: '0' });
    paint();
    container.dataset.rendered = 'true';
    status.hidden = true;
  };
  const zoom = (factor) => {
    if (!view) return;
    const width = Math.min(bounds.width * 8, Math.max(bounds.width / 30, view.width * factor));
    const ratio = width / view.width;
    const height = view.height * ratio;
    view = { x: view.x + (view.width - width) / 2, y: view.y + (view.height - height) / 2, width, height };
    paint();
  };
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') report({ action: 'close' });
  });
  document.addEventListener('click', (event) => {
    if (event.target.closest('a')) event.preventDefault();
  }, true);
  window.addEventListener('message', (event) => {
    if (event.source !== parent || event.origin !== location.origin || event.data?.channel !== 'natys-diagram' || event.data.action !== 'load') return;
    try {
      thumbnail = Boolean(event.data.thumbnail);
      const xml = mxUtils.parseXml(event.data.xml);
      if (xml.getElementsByTagName('parsererror').length || !['mxfile', 'mxGraphModel'].includes(xml.documentElement.nodeName)) throw new Error('El archivo no contiene un diagrama válido.');
      document.getElementById('controls').hidden = thumbnail;
      viewer?.graph?.destroy();
      container.replaceChildren();
      viewer = new GraphViewer(container, xml.documentElement, {
        responsive: true, resize: false, 'auto-fit': false, 'check-visible-state': false,
        center: false, lightbox: false, nav: false, 'dark-mode': 'light', border: 0,
      });
      viewer.graph.getLinkForCell = () => null;
      viewer.graph.openLink = () => {};
      viewer.graph.setPanning(false);
      pages.replaceChildren();
      const diagrams = [...xml.getElementsByTagName('diagram')];
      diagrams.forEach((diagram, index) => pages.add(new Option(diagram.getAttribute('name') || `Página ${index + 1}`, index)));
      document.getElementById('pages-label').hidden = diagrams.length < 2;
      fit();
      requestAnimationFrame(() => { fit(); report({ action: 'rendered', pages: diagrams.length || 1 }); });
      // Re-measure labels when web fonts finish loading without requiring input.
      document.fonts?.ready.then(() => requestAnimationFrame(fit));
    } catch (error) {
      status.hidden = false;
      status.textContent = 'No se pudo mostrar el diagrama: ' + error.message;
      report({ action: 'error', message: error.message });
    }
  });
  pages.addEventListener('change', () => { viewer.selectPage(Number(pages.value)); requestAnimationFrame(fit); });
  document.getElementById('fit').addEventListener('click', fit);
  document.getElementById('in').addEventListener('click', () => zoom(1 / 1.35));
  document.getElementById('out').addEventListener('click', () => zoom(1.35));
  container.addEventListener('pointerdown', (event) => {
    if (thumbnail || !view || event.button !== 0) return;
    drag = { x: event.clientX, y: event.clientY, view: { ...view } };
    container.setPointerCapture(event.pointerId);
    container.style.cursor = 'grabbing';
    event.preventDefault();
  });
  container.addEventListener('pointermove', (event) => {
    if (!drag) return;
    const pixelsPerUnit = Math.min(container.clientWidth / drag.view.width, container.clientHeight / drag.view.height);
    if (!pixelsPerUnit) return;
    view = { ...drag.view, x: drag.view.x - (event.clientX - drag.x) / pixelsPerUnit, y: drag.view.y - (event.clientY - drag.y) / pixelsPerUnit };
    paint();
  });
  const stopDrag = () => { drag = null; container.style.cursor = thumbnail ? 'default' : 'grab'; };
  container.addEventListener('pointerup', stopDrag);
  container.addEventListener('pointercancel', stopDrag);
  new ResizeObserver(() => requestAnimationFrame(fit)).observe(container);
  report({ action: 'ready' });
})();
