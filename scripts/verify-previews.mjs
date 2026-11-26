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
  const messages = [];
  w.postMessage = (data) => messages.push(data);
  w.eval(await readFile('public/diagram-viewer.js', 'utf8'));
  let pages = 0;
  for (const file of diagrams.values()) {
    console.log(`Comprobando ${file.title || file.file}…`);
    const source = await readFile(`public/${file.file}`, 'utf8');
    const xml = w.mxUtils.parseXml(source);
    w.document.getElementById('status').hidden = false;
    w.dispatchEvent(new w.MessageEvent('message', { origin: w.location.origin, source: w, data: { channel: 'natys-diagram', action: 'load', xml: source } }));
    const count = xml.getElementsByTagName('diagram').length || 1;
    for (let i = 0; i < count; i++) {
      if (i) {
        const select = w.document.getElementById('pages');
        select.value = String(i);
        select.dispatchEvent(new w.Event('change'));
        await new Promise((resolve) => w.requestAnimationFrame(resolve));
      }
      const svg = container.querySelector('svg');
      assert.ok(svg, `${file.file}: SVG missing`);
      assert.ok(svg.querySelectorAll('path, rect, ellipse, foreignObject').length > 1, `${file.file}: drawing is empty`);
      const viewBox = svg.getAttribute('viewBox')?.split(/\s+/).map(Number);
      assert.ok(viewBox?.length === 4 && viewBox.every(Number.isFinite) && viewBox[2] > 0 && viewBox[3] > 0, `${file.file}: initial viewport is not fitted`);
      assert.equal(w.document.getElementById('status').hidden, true, `${file.file}: initial display still loading`);
      pages++;
    }
  }
  // Runs our message bridge too, to catch initialization and toolbar failures.
  await new Promise((resolve) => w.requestAnimationFrame(resolve));
  assert.ok(!messages.some((m) => m.action === 'error'), JSON.stringify(messages));
  assert.ok(messages.some((m) => m.action === 'rendered'), 'Renderer handshake failed');
  assert.equal(w.document.getElementById('status').hidden, true);
  const svg = container.querySelector('svg');
  const initialWidth = Number(svg.getAttribute('viewBox').split(' ')[2]);
  w.document.getElementById('in').click();
  assert.ok(Number(svg.getAttribute('viewBox').split(' ')[2]) < initialWidth, 'Zoom did not enlarge drawing');
  w.document.getElementById('out').click();
  w.document.getElementById('fit').click();
  for (const [archive, entries] of Object.entries(archives)) {
    assert.ok(entries.length, `${archive}: empty archive`);
    for (const entry of entries) assert.equal((await readFile(`public/${entry.file}`)).length, entry.size);
  }
  console.log(`OK: ${diagrams.size} diagramas visibles desde el primer render, ${pages} páginas, zoom y puente del visor; ${Object.keys(archives).length} paquetes con contenido interno.`);
} finally {
  dom.window.close();
}
