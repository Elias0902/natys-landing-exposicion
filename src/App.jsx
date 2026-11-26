import { lazy, Suspense, useEffect, useMemo, useState } from 'react';
import DocViewer from './components/DocViewer';
import { asset } from './data/content';
import { integrantes, modulos } from './data/pruebas';
import materials from './data/materials.json';
import FileThumbnail from './components/FileThumbnail';
import { previewDocument } from './lib/filePreview';
import './repository.css';

const Legacy = lazy(() => import('./LegacyPresentation'));
const Tests = lazy(() => import('./components/TestsSection').then((module) => ({ default: module.TestsPage })));
const folders = [
  { id: 'todos', title: 'Todos los archivos', description: 'El proyecto completo en un solo lugar.', icon: 'library' },
  { id: 'pruebas', title: 'Pruebas', description: 'Plan maestro, trazabilidad e informes por módulo.', icon: 'check' },
  { id: 'ingenieria', title: 'Ingeniería de software', description: 'Requisitos, casos de uso, clases y navegación.', icon: 'layers' },
  { id: 'base-datos', title: 'Base de datos', description: 'Modelos, diccionario, DDL y scripts SQL.', icon: 'database' },
  { id: 'programacion', title: 'Programación de pruebas', description: 'Informes técnicos y evidencias de automatización.', icon: 'code' },
];
const people = Object.fromEntries(integrantes.map((p) => [p.id, p.nombre]));
const reports = modulos.flatMap((m) => ['pdf', 'docx'].filter((type) => m[type]).map((type) => ({
  id: `informe-${m.id}-${type}`, title: `Informe de pruebas · ${m.nombre}`, category: 'pruebas', group: 'Informes por módulo',
  owner: people[m.responsable], format: type.toUpperCase(), file: m[type], original: m[type], module: m.id, thumb: m.thumb,
})));
const evidence = [
  { id: 'codigo-unitaria', title: 'Prueba unitaria · Promociones', file: 'img/email-promociones-unitaria.jpg', group: 'PHPUnit · evidencia de código' },
  { id: 'codigo-pipeline', title: 'Pipeline de pruebas · Promociones', file: 'img/email-promociones-pipeline.jpg', group: 'Pipeline · evidencia de código' },
].map((f) => ({ ...f, category: 'programacion', format: 'JPG', owner: 'Ismael Torres' }));
const files = [...materials, ...reports, ...evidence];
const matches = (file, folder) => folder === 'todos' || file.category === folder || (folder === 'programacion' && Boolean(file.module));
const normal = (s) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
const sizeLabel = (s) => s >= 1048576 ? `${(s / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(s / 1024))} KB`;
function Icon({ name }) {
  const paths = {
    library: <><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></>,
    folder: <path d="M3 7h6l2 2h10v11H3z M3 7V4h6l2 3" />,
    check: <><path d="m7 12 3 3 7-7" /><rect x="3" y="3" width="18" height="18" rx="4" /></>,
    layers: <path d="m12 3 10 5-10 5L2 8z M2 12l10 5 10-5 M2 17l10 5 10-5" />,
    database: <><ellipse cx="12" cy="5" rx="9" ry="3" /><path d="M3 5v14c0 4 18 4 18 0V5 M3 12c0 4 18 4 18 0" /></>,
    code: <path d="m8 6-6 6 6 6 m8-12 6 6-6 6 m-3-16-2 20" />,
    search: <><circle cx="10" cy="10" r="7" /><path d="m15 15 6 6" /></>,
    download: <path d="M12 3v12 m-5-5 5 5 5-5 M3 16v5h18v-5" />,
    file: <path d="M5 2h9l5 5v15H5z M14 2v6h5 M8 13h8 M8 17h6" />,
    menu: <path d="M4 6h16 M4 12h16 M4 18h16" />,
  };
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name] || paths.file}</svg>;
}
function Library({ hash, onOpen }) {
  const initial = hash.startsWith('#/carpeta/') ? hash.split('/')[2] : 'todos';
  const folder = folders.some((f) => f.id === initial) ? initial : 'todos';
  const [query, setQuery] = useState('');
  const [format, setFormat] = useState('todos');
  const [order, setOrder] = useState('destacados');
  const [versions, setVersions] = useState(false);
  const [showOverview, setShowOverview] = useState(false);
  const [showPackages, setShowPackages] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(() => {
    try {
      const saved = localStorage.getItem('natys-sidebar-open');
      if (saved !== null) return saved === '1';
    } catch { /* El menú también funciona sin almacenamiento. */ }
    return window.matchMedia('(min-width: 761px)').matches;
  });
  const toggleSidebar = () => setSidebarOpen((open) => {
    try { localStorage.setItem('natys-sidebar-open', open ? '0' : '1'); } catch { /* Almacenamiento opcional. */ }
    return !open;
  });
  useEffect(() => {
    const mobile = window.matchMedia('(max-width: 760px)');
    const previous = document.body.style.overflow;
    const update = () => { document.body.style.overflow = sidebarOpen && mobile.matches ? 'hidden' : previous; };
    update();
    mobile.addEventListener?.('change', update);
    return () => { document.body.style.overflow = previous; mobile.removeEventListener?.('change', update); };
  }, [sidebarOpen]);
  const visible = (f) => versions || f.version !== 'Carpeta 03 · versión alternativa';
  const formats = [...new Set(files.filter((f) => matches(f, folder)).map((f) => f.format))].sort();
  const list = useMemo(() => {
    const result = files.filter((f) => matches(f, folder) && (format === 'todos' || f.format === format) && (showPackages || format !== 'todos' || !['RAR', 'ZIP'].includes(f.format)) && (versions || f.version !== 'Carpeta 03 · versión alternativa') && normal([f.title, f.group, f.owner, f.original, f.version].filter(Boolean).join(' ')).includes(normal(query)));
    if (order === 'nombre') result.sort((a, b) => a.title.localeCompare(b.title, 'es'));
    if (order === 'tipo') result.sort((a, b) => a.format.localeCompare(b.format) || a.title.localeCompare(b.title, 'es'));
    return result;
  }, [folder, query, format, order, versions, showPackages]);
  const selected = folders.find((f) => f.id === folder);
  const choose = (id) => {
    setFormat('todos'); setQuery('');
    if (window.matchMedia('(max-width: 760px)').matches) {
      setSidebarOpen(false);
      try { localStorage.setItem('natys-sidebar-open', '0'); } catch { /* Preferencia opcional. */ }
    }
    window.location.hash = id === 'todos' ? '#inicio' : `#/carpeta/${id}`;
  };
  const preview = (f) => onOpen(previewDocument(f));
  return <div className="repository" id="inicio">
    <header className="repo-header"><button className="repo-menu-toggle" onClick={toggleSidebar} aria-expanded={sidebarOpen} aria-controls="repo-sidebar" aria-label={sidebarOpen ? 'Cerrar menú lateral' : 'Abrir menú lateral'} title={sidebarOpen ? 'Cerrar menú lateral' : 'Abrir menú lateral'}><Icon name="menu" /></button><a className="repo-brand" href="#inicio"><span className="repo-logo">N’</span><span>Natys<small>Repositorio del proyecto</small></span></a><div className="repo-team">IN3103 <span>/</span> Equipo 8</div><a className="repo-header-link" href="#/pruebas">Informes por módulo</a></header>
    <div className={`repo-layout ${sidebarOpen ? '' : 'is-sidebar-closed'}`}>
      {sidebarOpen && <button className="repo-sidebar-backdrop" onClick={toggleSidebar} aria-label="Cerrar menú lateral desde el fondo" tabIndex={-1} />}
      <aside id="repo-sidebar" className="repo-sidebar" hidden={!sidebarOpen} aria-label="Carpetas del repositorio"><div className="repo-sidebar-mobile-head"><b>Carpetas del proyecto</b><button onClick={toggleSidebar} aria-label="Cerrar carpetas">×</button></div><span className="repo-eyebrow">ESPACIO DE TRABAJO</span><nav>{folders.map((f) => <button key={f.id} className={folder === f.id ? 'is-selected' : ''} onClick={() => choose(f.id)} aria-current={folder === f.id ? 'page' : undefined}><Icon name={f.icon} /><span>{f.title}</span><small>{files.filter((file) => matches(file, f.id) && visible(file)).length}</small></button>)}</nav><div className="repo-sidebar-note"><Icon name="folder" /><b>Materiales del equipo</b><p>Consulta los documentos y descarga sus archivos originales.</p></div><details className="repo-archive"><summary>Archivo de la exposición</summary><p>Automatización de las Pruebas y Pipelines · 13 de noviembre de 2026</p><a href="#/exposicion">Abrir exposición anterior</a><a href="#/ismael">Material de Ismael</a><a href="#/dashboard">Dashboards y simulador</a></details></aside>
      <main className="repo-main repo-main--compact">
        <div className="repo-overview-control"><button onClick={() => setShowOverview((open) => !open)} aria-expanded={showOverview} aria-controls="repo-overview">{showOverview ? 'Ocultar resumen de áreas' : 'Mostrar resumen de áreas'}</button></div>
        {showOverview && <div id="repo-overview"><div className="repo-breadcrumb">Proyecto Natys <span>/</span> {selected.title}</div><section className="repo-intro"><div><span className="repo-eyebrow">DOCUMENTACIÓN Y EVIDENCIAS</span><h1>{folder === 'todos' ? 'Todo el proyecto, organizado.' : selected.title}</h1><p>{folder === 'todos' ? 'Pruebas, ingeniería y base de datos. Los materiales de Galletas Natys, listos para consultar y presentar.' : selected.description}</p></div><div className="repo-intro-icon"><Icon name={selected.icon} /></div></section>
        <section className="repo-folders" aria-label="Explorar por área">{folders.slice(1).map((f) => <button key={f.id} className={`repo-folder ${folder === f.id ? 'is-selected' : ''}`} onClick={() => choose(f.id)}><span className={`repo-folder-icon tone-${f.id}`}><Icon name={f.icon} /></span><b>{f.title}</b><p>{f.description}</p><small>{files.filter((file) => matches(file, f.id) && visible(file)).length} archivos</small></button>)}</section></div>}
        <section className="repo-files" id="documentos" aria-labelledby="files-title"><div className="repo-files-heading"><div><h2 id="files-title">{folder === 'todos' ? 'Explorar archivos' : `Archivos · ${selected.title}`}</h2><p>Previsualiza los documentos o descarga el editable.</p></div><span className="repo-count" aria-live="polite">{list.length} archivos</span></div>
          <div className="repo-toolbar"><label className="repo-search"><Icon name="search" /><input aria-label="Buscar archivos" placeholder="Buscar un documento, módulo o integrante…" value={query} onChange={(e) => setQuery(e.target.value)} />{query && <button aria-label="Limpiar búsqueda" onClick={() => setQuery('')}>×</button>}</label><select aria-label="Filtrar por formato" value={format} onChange={(e) => setFormat(e.target.value)}><option value="todos">Todos los formatos</option>{formats.map((f) => <option key={f}>{f}</option>)}</select><select aria-label="Ordenar archivos" value={order} onChange={(e) => setOrder(e.target.value)}><option value="destacados">Orden del repositorio</option><option value="nombre">Nombre A–Z</option><option value="tipo">Tipo de archivo</option></select></div>
          <details className="repo-extra-options"><summary>Opciones de archivos</summary><label className="repo-versions"><input type="checkbox" checked={versions} onChange={(e) => setVersions(e.target.checked)} /> Incluir carpeta alternativa «03 - Bases de Datos»</label><label className="repo-versions"><input type="checkbox" checked={showPackages} onChange={(e) => setShowPackages(e.target.checked)} /> Mostrar paquetes originales ZIP / RAR</label></details>
          <ul className="repo-file-grid" aria-label="Archivos disponibles">
            {list.map((f) => <li key={f.id} className="repo-file-card">
              <button className="repo-card-preview" onClick={() => preview(f)} aria-label={`Previsualizar ${f.title} (${f.format})`}><FileThumbnail file={f} /></button>
              <div className="repo-card-body">
                <div className="repo-card-meta"><span>{folders.find((c) => c.id === f.category)?.title}</span><span className="repo-format">{f.format}</span></div>
                <h3><button onClick={() => preview(f)}>{f.title}</button></h3>
                <p className="repo-card-owner">{f.owner || f.version || (f.format === 'DRAWIO' ? 'Diagrama editable' : 'Archivo original')}{f.size ? ` · ${sizeLabel(f.size)}` : ''}</p>
                <div className="repo-card-actions"><button onClick={() => preview(f)}>Previsualizar</button><a href={asset(f.file)} download aria-label={`Descargar ${f.title} (${f.format})`} title="Descargar original"><Icon name="download" /></a></div>
              </div>
            </li>)}
          </ul>
          {!list.length && <div className="repo-empty"><Icon name="search" /><h3>No se encontraron archivos</h3><p>Prueba otro nombre o cambia los filtros.</p><button onClick={() => { setQuery(''); setFormat('todos'); }}>Limpiar filtros</button></div>}
          {folder === 'programacion' && <p className="repo-footnote">Los informes incluyen evidencias de automatización. Las capturas de código se identifican como imágenes; los scripts ejecutables se podrán incorporar cuando estén disponibles.</p>}
        </section><footer className="repo-footer"><span>Natys · Equipo 8</span><span>Documentación del sistema · IN3103</span></footer>
      </main>
    </div>
  </div>;
}
export default function App() {
  const [hash, setHash] = useState(() => window.location.hash);
  const [doc, setDoc] = useState(null);
  useEffect(() => { const update = () => { setHash(window.location.hash); setDoc(null); window.scrollTo(0, 0); }; window.addEventListener('hashchange', update); return () => window.removeEventListener('hashchange', update); }, []);
  const legacy = ['#/exposicion', '#/ismael', '#/dashboard'].some((route) => hash.startsWith(route));
  if (legacy) return <Suspense fallback={<p className="repo-loading">Cargando archivo…</p>}><Legacy /></Suspense>;
  if (hash.startsWith('#/pruebas')) return <><header className="repo-header"><a href="#inicio" className="repo-header-link">Volver al repositorio</a></header><Suspense fallback={<p>Cargando informes…</p>}><Tests key={hash} onOpen={setDoc} filtroInicial={hash.split('/')[2]} /></Suspense>{doc && <DocViewer key={doc.id || doc.file} doc={doc} onClose={() => setDoc(null)} />}</>;
  return <><Library key={initialFolder(hash)} hash={hash} onOpen={setDoc} />{doc && <DocViewer key={doc.id || doc.file} doc={doc} onClose={() => setDoc(null)} />}</>;
}
const initialFolder = (hash) => hash.startsWith('#/carpeta/') ? hash.split('/')[2] : 'todos';
