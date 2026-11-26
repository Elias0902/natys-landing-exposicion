import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { JSDOM } from 'jsdom';

// Exercises the actual bundled renderer with the supplied diagrams, including
// compressed and multi-page files. This is DOM verification, not visual QA.
const materials = JSON.parse(await readFile('src/data/materials.json', 'utf8'));
const archives = JSON.parse(await readFile('src/data/archiveContents.json', 'utf8'));
const diagrams = new Map(materials.filter((f) => f.format === 'DRAWIO').map((f) => [f.file, f]));
for (const entries of Object.values(archives)) for (const f of entries) if (f.format === 'DRAWIO') diagrams.set(f.file, f);
const html = await readFile('public/diagram-viewer.html', 'utf8');
const dom = new JSDOM(html, { url: 'http://localhost/renamed-project/diagram-viewer.html', runScripts: 'outside-only', pretendToBeVisual: true });
const w = dom.window;
w.matchMedia = () => ({ matches: false, addListener() {}, removeListener() {}, addEventListener() {}, removeEventListener() {} });
w.ResizeObserver = class { observe() {} disconnect() {} };
const container = w.document.getElementById('graph');
for (const [key, value] of Object.entries({ clientWidth: 1000, clientHeight: 700, offsetWidth: 1000, offsetHeight: 700 })) Object.defineProperty(container, key, { value });
try {
  w.eval(await readFile('public/diagram-viewer-config.js', 'utf8'));
  w.eval(await readFile('public/vendor/drawio/viewer-static.min.js', 'utf8'));
  console.log('Visor Draw.io local cargado.');
  assert.equal(typeof w.GraphViewer, 'function');
  let pages = 0;
  for (const file of diagrams.values()) {
    console.log(`Comprobando ${file.title || file.file}…`);
    container.replaceChildren();
    const xml = w.mxUtils.parseXml(await readFile(`public/${file.file}`, 'utf8'));
    const viewer = new w.GraphViewer(container, xml.documentElement, { 'check-visible-state': false, resize: false, nav: false, lightbox: false, 'dark-mode': 'light' });
    assert.ok(viewer.graph, `${file.file}: no graph`);
    const count = xml.getElementsByTagName('diagram').length || 1;
    for (let i = 0; i < count; i++) {
      if (i) viewer.selectPage(i);
      const cells = Object.values(viewer.graph.getModel().cells);
      assert.ok(cells.some((cell) => cell.vertex), `${file.file}: empty page ${i}`);
      assert.ok(container.querySelector('svg'), `${file.file}: SVG missing`);
      pages++;
    }
    viewer.graph.destroy();
  }
  // Runs our message bridge too, to catch initialization and toolbar failures.
  const messages = [];
  w.postMessage = (data) => messages.push(data);
  w.eval(await readFile('public/diagram-viewer.js', 'utf8'));
  const example = [...diagrams.values()][0];
  w.dispatchEvent(new w.MessageEvent('message', { origin: w.location.origin, source: w, data: { channel: 'natys-diagram', action: 'load', xml: await readFile(`public/${example.file}`, 'utf8') } }));
  await new Promise((resolve) => w.requestAnimationFrame(resolve));
  assert.ok(!messages.some((m) => m.action === 'error'), JSON.stringify(messages));
  assert.ok(messages.some((m) => m.action === 'rendered'), 'Renderer handshake failed');
  assert.equal(w.document.getElementById('status').hidden, true);
  w.document.getElementById('in').click();
  w.document.getElementById('out').click();
  w.document.getElementById('fit').click();
  for (const [archive, entries] of Object.entries(archives)) {
    assert.ok(entries.length, `${archive}: empty archive`);
    for (const entry of entries) assert.equal((await readFile(`public/${entry.file}`)).length, entry.size);
  }
  console.log(`OK: ${diagrams.size} diagramas, ${pages} páginas, zoom y puente del visor; ${Object.keys(archives).length} paquetes con contenido interno.`);
} finally {
  dom.window.close();
}
