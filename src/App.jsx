import { useEffect, useRef, useState } from 'react';
import Dashboard from './components/Dashboard';
import TestsPage from './components/TestsSection';
import { asset, documents, event, guide } from './data/content';
import { scenarios } from './data/metrics';

function Navbar({ onSelectDashboard }) {
  const [open, setOpen] = useState(false);
  const [mobile, setMobile] = useState(false);
  const ref = useRef(null);

  // Close the dropdown when clicking outside of it
  useEffect(() => {
    const close = (e) => ref.current && !ref.current.contains(e.target) && setOpen(false);
    document.addEventListener('click', close);
    return () => document.removeEventListener('click', close);
  }, []);

  const pick = (id) => {
    onSelectDashboard(id);
    setOpen(false);
    setMobile(false);
    // Desde la página de pruebas, volver primero a la landing
    if (window.location.hash.startsWith('#/pruebas')) window.location.hash = '#dashboard';
    else document.getElementById('dashboard')?.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <header className="nav">
      <div className="nav__inner">
        <a href="#inicio" className="brand">
          <span className="brand__logo">N</span>
          <span>
            Natys <small>· {event.team}</small>
          </span>
        </a>
        <button className="nav__burger" onClick={() => setMobile(!mobile)} aria-label="Menú">
          ☰
        </button>
        <nav className={`nav__links ${mobile ? 'is-open' : ''}`}>
          <a href="#inicio" onClick={() => setMobile(false)}>Inicio</a>
          <div className="dropdown" ref={ref}>
            <button className="dropdown__toggle" onClick={() => setOpen(!open)} aria-expanded={open}>
              Dashboard <span className={`caret ${open ? 'up' : ''}`}>▾</span>
            </button>
            {open && (
              <ul className="dropdown__menu">
                {scenarios.map((d) => (
                  <li key={d.id}>
                    <button onClick={() => pick(d.id)}>
                      <i className={`dot dot--${d.status}`} />
                      Dashboard · {d.label.toLowerCase()}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
          <a href="#guia" onClick={() => setMobile(false)}>Guía</a>
          <a href="#/pruebas" onClick={() => setMobile(false)}>Pruebas</a>
          <a href="#documentos" onClick={() => setMobile(false)}>Documentos</a>
          <a className="btn btn--sm" href={event.formUrl} target="_blank" rel="noreferrer">
            Evaluación
          </a>
        </nav>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section id="inicio" className="hero">
      <div className="container hero__grid">
        <div>
          <span className="badge">{event.section} · {event.team}</span>
          <h1>{event.title}</h1>
          <p className="lead">
            Caso práctico: <strong>{event.project}</strong>. Software probado por máquinas: más
            rápido, más confiable y sin errores humanos.
          </p>
          <div className="hero__actions">
            <a className="btn" href="#guia">Ver guía</a>
            <a className="btn btn--ghost" href="#documentos">Documentos</a>
          </div>
          <p className="muted">Exposición · {event.date}</p>
        </div>
        <div className="hero__qr card">
          <img src={asset('img/qr-evaluacion.png')} alt="QR de la evaluación" />
          <a href={event.formUrl} target="_blank" rel="noreferrer">{event.formUrl.replace('https://', '')}</a>
        </div>
      </div>
      <div className="container stats">
        <div className="stat"><b>5</b><span>Integrantes</span></div>
        <div className="stat"><b>{documents.length}</b><span>Documentos</span></div>
        <div className="stat"><b>20</b><span>Preguntas</span></div>
        <div className="stat"><b>{scenarios.length}</b><span>Dashboards</span></div>
      </div>
    </section>
  );
}

function GuideSection() {
  const [active, setActive] = useState(1);
  return (
    <section id="guia" className="section section--alt">
      <div className="container">
        <SectionTitle kicker="Guion" title="Guía de la exposición" text="Orden, responsable y lo que se hablará en cada parte." />
        <div className="guide">
          <ol className="guide__list">
            {guide.map((g) => (
              <li key={g.order}>
                <button className={`step ${active === g.order ? 'is-active' : ''}`} onClick={() => setActive(g.order)}>
                  <span className="step__num">{g.order}</span>
                  <span>
                    <b>{g.name}</b>
                    <small>{g.topic}</small>
                  </span>
                </button>
              </li>
            ))}
          </ol>
          {guide.filter((g) => g.order === active).map((g) => (
            <article key={g.order} className="card guide__detail">
              <span className="badge">Parte {g.order} · {g.role}</span>
              <h3>{g.topic}</h3>
              <p className="muted">Expone: {g.name}</p>
              <ul className="points">
                {g.points.map((p) => <li key={p}>{p}</li>)}
              </ul>
            </article>
          ))}
        </div>

      </div>
    </section>
  );
}

function DocumentsSection({ onOpen }) {
  const categories = ['Todos', ...new Set(documents.map((d) => d.category))];
  const [filter, setFilter] = useState('Todos');
  const list = documents.filter((d) => filter === 'Todos' || d.category === filter);
  return (
    <section id="documentos" className="section">
      <div className="container">
        <SectionTitle kicker="Material" title="Documentos" text="Haz clic en un documento para verlo aquí mismo." />
        <div className="tabs">
          {categories.map((c) => (
            <button key={c} className={`tab ${c === filter ? 'is-active' : ''}`} onClick={() => setFilter(c)}>{c}</button>
          ))}
        </div>
        <div className="docs">
          {list.map((d) => (
            <button key={d.id} className={`doc card ${d.file ? '' : 'is-pending'}`} onClick={() => d.file && onOpen(d)}>
              <div className="doc__thumb">
                {d.thumb ? <img src={asset(d.thumb)} alt={d.title} loading="lazy" /> : <span className="doc__icon">PDF</span>}
              </div>
              <div className="doc__body">
                <b>{d.title}</b>
                <small>{d.owner}</small>
                <span className={`pill ${d.file ? 'pill--ok' : ''}`}>{d.file ? d.category : 'Pendiente'}</span>
              </div>
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}

function Viewer({ doc, onClose }) {
  useEffect(() => {
    const esc = (e) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', esc);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', esc);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  const download = asset(doc.download || doc.file);
  return (
    <div className="modal" onClick={onClose}>
      <div className="modal__box" onClick={(e) => e.stopPropagation()}>
        <div className="modal__head">
          <b>{doc.title}</b>
          <div>
            <a className="btn btn--sm btn--ghost" href={asset(doc.file)} target="_blank" rel="noreferrer">Abrir</a>
            <a className="btn btn--sm" href={download} download>Descargar</a>
            <button className="close" onClick={onClose} aria-label="Cerrar">✕</button>
          </div>
        </div>
        <div className="modal__body">
          {doc.type === 'pdf' ? (
            <iframe src={asset(doc.file)} title={doc.title} />
          ) : (
            <img src={asset(doc.file)} alt={doc.title} />
          )}
        </div>
      </div>
    </div>
  );
}

function SectionTitle({ kicker, title, text }) {
  return (
    <div className="stitle">
      <span>{kicker}</span>
      <h2>{title}</h2>
      <p>{text}</p>
    </div>
  );
}

// Ruta simple por hash: #/pruebas es una página aparte; lo demás es la landing
const isTestsRoute = () => window.location.hash.startsWith('#/pruebas');

export default function App() {
  const [dashboard, setDashboard] = useState(scenarios[0].id);
  const [doc, setDoc] = useState(null);
  const [tests, setTests] = useState(isTestsRoute);

  useEffect(() => {
    const onHash = () => {
      const next = isTestsRoute();
      setTests(next);
      // Al volver a la landing, baja a la sección del enlace (#guia, #documentos...)
      const id = window.location.hash.slice(1);
      requestAnimationFrame(() => {
        const el = !next && id && document.getElementById(id);
        if (el) el.scrollIntoView();
        else window.scrollTo(0, 0);
      });
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);
  return (
    <>
      <Navbar onSelectDashboard={setDashboard} />
      <main>
        {tests ? (
          <TestsPage onOpen={setDoc} />
        ) : (
          <>
            <Hero />
            <Dashboard selected={dashboard} onSelect={setDashboard} />
            <GuideSection />
            <DocumentsSection onOpen={setDoc} />
          </>
        )}
      </main>
      <footer className="footer">
        <div className="container">
          {event.team} · {event.section} · {event.project} · {event.date}
        </div>
      </footer>
      {doc && <Viewer doc={doc} onClose={() => setDoc(null)} />}
    </>
  );
}
