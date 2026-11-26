/* global GraphViewer, mxUtils, mxEvent */
(() => {
  const container = document.getElementById('graph');
  const status = document.getElementById('status');
  const pages = document.getElementById('pages');
  let viewer;
  let thumbnail = false;
  const report = (data) => parent.postMessage({ channel: 'natys-diagram', ...data }, location.origin);
  const scale = () => {
    if (viewer?.graph) document.getElementById('scale').textContent = Math.round(viewer.graph.view.scale * 100) + '%';
  };
  const fit = () => {
    if (!viewer?.graph) return;
    viewer.graph.maxFitScale = thumbnail ? 1 : 2;
    viewer.graph.fit(thumbnail ? 12 : 24);
    viewer.graph.center(true, true);
    scale();
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
        resize: false, 'auto-fit': true, 'allow-zoom-in': true, 'check-visible-state': false,
        center: true, lightbox: false, nav: false, 'dark-mode': 'light', border: thumbnail ? 12 : 24,
      });
      viewer.graph.getLinkForCell = () => null;
      viewer.graph.openLink = () => {};
      viewer.graph.setPanning(!thumbnail);
      viewer.graph.panningHandler.useLeftButtonForPanning = true;
      viewer.graph.panningHandler.ignoreCell = true;
      viewer.graph.panningHandler.isForcePanningEvent = (event) => !mxEvent.isPopupTrigger(event.getEvent());
      pages.replaceChildren();
      const diagrams = [...xml.getElementsByTagName('diagram')];
      diagrams.forEach((diagram, index) => pages.add(new Option(diagram.getAttribute('name') || `Página ${index + 1}`, index)));
      document.getElementById('pages-label').hidden = diagrams.length < 2;
      status.hidden = true;
      requestAnimationFrame(() => { fit(); report({ action: 'rendered', pages: diagrams.length || 1 }); });
    } catch (error) {
      status.hidden = false;
      status.textContent = 'No se pudo mostrar el diagrama: ' + error.message;
      report({ action: 'error', message: error.message });
    }
  });
  pages.addEventListener('change', () => { viewer.selectPage(Number(pages.value)); requestAnimationFrame(fit); });
  document.getElementById('fit').addEventListener('click', fit);
  document.getElementById('in').addEventListener('click', () => { viewer?.graph?.zoomIn(); scale(); });
  document.getElementById('out').addEventListener('click', () => { viewer?.graph?.zoomOut(); scale(); });
  new ResizeObserver(() => requestAnimationFrame(fit)).observe(container);
  report({ action: 'ready' });
})();
