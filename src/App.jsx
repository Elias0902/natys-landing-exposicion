import { useEffect, useState } from 'react';
import Dashboard from './components/Dashboard';
import TestsPage from './components/TestsSection';
import DocViewer from './components/DocViewer';
import SimulacionPrueba from './components/SimulacionPrueba';
import { LoginModal, yaDesbloqueado } from './components/AccesoPrivado';
import { asset, documents, event, guide } from './data/content';
import { scenarios } from './data/metrics';

// Documentos que solo se ven con login (el resto queda público)
const PRIVADOS = new Set(['formulario', 'asignaciones', 'guia', 'punto1', 'informe']);

function Navbar({ onSimular, onLogin }) {
  const [mobile, setMobile] = useState(false);

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
          <a href="#/pruebas" onClick={() => setMobile(false)}>Pruebas</a>
          <a href="#documentos" onClick={() => setMobile(false)}>Documentos</a>
          <button
            className="btn btn--sm btn--ghost"
            onClick={() => {
              setMobile(false);
              onSimular();
            }}
          >
            ▶ Simular prueba
          </button>
          <button
            className="btn btn--sm btn--ghost"
            onClick={() => {
              setMobile(false);
              onLogin();
            }}
          >
            Login
          </button>
          <a className="btn btn--sm" href={event.formUrl} target="_blank" rel="noreferrer">
            Evaluación
          </a>
        </nav>
      </div>
    </header>
  );
}

function Hero() {
  const publicos = documents.filter((d) => !PRIVADOS.has(d.id)).length;
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
        <div className="stat"><b>{publicos}</b><span>Documentos</span></div>
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
              {g.examples?.length > 0 && (
                <div className="examples">
                  <h4>Ejemplos en el sistema Naty's</h4>
                  <ul>
                    {g.examples.map((e) => <li key={e}>{e}</li>)}
                  </ul>
                </div>
              )}
            </article>
          ))}
        </div>

      </div>
    </section>
  );
}

// Documentos: los públicos siempre; los privados aparecen al hacer login
function DocumentsSection({ onOpen, ok }) {
  const visibles = documents.filter((d) => ok || !PRIVADOS.has(d.id));
  const categories = ['Todos', ...new Set(visibles.map((d) => d.category))];
  const [filter, setFilter] = useState('Todos');
  const list = visibles.filter((d) => filter === 'Todos' || d.category === filter);
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

// Página del dashboard (#/dashboard): se abre desde "Ver dashboard" en la simulación
function DashboardPage({ selected, onSelect }) {
  return (
    <>
      <div className="container">
        <a className="back" href="#inicio">← Volver al inicio</a>
      </div>
      <Dashboard selected={selected} onSelect={onSelect} />
    </>
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

// Rutas simples por hash: #/pruebas y #/dashboard son páginas aparte; lo demás es la landing
const rutaActual = () => {
  const h = window.location.hash;
  if (h.startsWith('#/pruebas')) return 'pruebas';
  if (h.startsWith('#/dashboard')) return 'dashboard';
  return 'inicio';
};

export default function App() {
  const [dashboard, setDashboard] = useState(scenarios[0].id);
  const [doc, setDoc] = useState(null);
  const [ruta, setRuta] = useState(rutaActual);
  const [simulando, setSimulando] = useState(false);
  const [privado, setPrivado] = useState(yaDesbloqueado);
  const [login, setLogin] = useState(false);

  useEffect(() => {
    const onHash = () => {
      const next = rutaActual();
      setRuta(next);
      // Relee la sesión por si se entró desde la página de Pruebas
      setPrivado(yaDesbloqueado());
      // Al volver a la landing, baja a la sección del enlace (#guia, #documentos...)
      const id = window.location.hash.slice(1);
      requestAnimationFrame(() => {
        const el = next === 'inicio' && id && document.getElementById(id);
        if (el) el.scrollIntoView();
        else window.scrollTo(0, 0);
      });
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  return (
    <>
      <Navbar onSimular={() => setSimulando(true)} onLogin={() => setLogin(true)} />
      <main>
        {ruta === 'pruebas' && <TestsPage onOpen={setDoc} />}
        {ruta === 'dashboard' && <DashboardPage selected={dashboard} onSelect={setDashboard} />}
        {ruta === 'inicio' && (
          <>
            <Hero />
            {privado && <GuideSection />}
            <DocumentsSection onOpen={setDoc} ok={privado} />
          </>
        )}
      </main>
      <footer className="footer">
        <div className="container">
          {event.team} · {event.section} · {event.project} · {event.date}
        </div>
      </footer>
      {doc && <DocViewer doc={doc} onClose={() => setDoc(null)} />}
      {login && (
        <LoginModal
          onOk={() => {
            setPrivado(true);
            setLogin(false);
          }}
          onClose={() => setLogin(false)}
        />
      )}
      {simulando && (
        <SimulacionPrueba
          scenario={scenarios.find((x) => x.id === dashboard) ?? scenarios[0]}
          onClose={() => setSimulando(false)}
          onVerDashboard={(id) => {
            setDashboard(id);
            setSimulando(false);
            window.location.hash = '#/dashboard';
          }}
        />
      )}
    </>
  );
}
