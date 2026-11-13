import { useState } from 'react';
import { asset } from '../data/content';
import { integrantes, modulos } from '../data/pruebas';

const persona = Object.fromEntries(integrantes.map((p) => [p.id, p]));
const esPrincipal = (m) => persona[m.responsable].principal === m.id;

// Si en este tiempo no llega ni un byte, la conexión se da por caída
const SIN_DATOS_MS = 30000;
const MB = (n) => (n / 1048576).toFixed(1);
const pausa = () => new Promise((r) => setTimeout(r)); // deja que React pinte el progreso

// Descarga todos los PDF a la vez. Cancela si la red se queda quieta SIN_DATOS_MS.
async function descargar(rutas, onProgreso) {
  const ctrl = new AbortController();
  let recibidos = 0;
  let total = 0;
  let conTamano = 0;
  let vigilante;
  const latido = () => {
    clearTimeout(vigilante);
    vigilante = setTimeout(() => ctrl.abort(), SIN_DATOS_MS);
  };
  const avisar = () => {
    latido();
    onProgreso(recibidos, conTamano === rutas.length ? total : 0);
  };

  latido();
  try {
    return await Promise.all(rutas.map(async (ruta) => {
      const r = await fetch(asset(ruta), { signal: ctrl.signal });
      if (!r.ok) throw new Error(`No se encontró ${ruta}`);
      const tam = Number(r.headers.get('content-length'));
      if (tam) { total += tam; conTamano += 1; }
      avisar();
      const lector = r.body.getReader();
      const partes = [];
      for (;;) {
        const { done, value } = await lector.read();
        if (done) break;
        partes.push(value);
        recibidos += value.length;
        avisar();
      }
      return new Blob(partes).arrayBuffer();
    }));
  } catch (e) {
    ctrl.abort();
    throw e;
  } finally {
    clearTimeout(vigilante);
  }
}

const mensajeError = (e) => {
  if (e.name === 'AbortError') return 'La conexión está muy lenta o se cortó. Intenta de nuevo.';
  if (e.name === 'TypeError') return 'Sin conexión. Revisa el wifi e intenta de nuevo.';
  return e.message;
};

// Une todos los PDF disponibles, en el orden de la lista, y descarga el resultado
function MergeButton() {
  const conPdf = modulos.filter((m) => m.pdf);
  const [ocupado, setOcupado] = useState(false);
  const [estado, setEstado] = useState('');
  const [error, setError] = useState(false);

  const juntar = async () => {
    setOcupado(true);
    setError(false);
    setEstado('Conectando…');
    // pdf-lib va incluido en la web; se pide en paralelo con los informes
    const libreria = import('pdf-lib');
    libreria.catch(() => {});
    try {
      const archivos = await descargar(conPdf.map((m) => m.pdf), (llevo, total) => {
        setEstado(total
          ? `Descargando informes… ${MB(Math.min(llevo, total))} de ${MB(total)} MB`
          : `Descargando informes… ${MB(llevo)} MB`);
      });
      const { PDFDocument } = await libreria;
      const salida = await PDFDocument.create();
      salida.setTitle('Informes de pruebas · Natys · Equipo 8');
      for (const [i, bytes] of archivos.entries()) {
        setEstado(`Uniendo ${i + 1} de ${conPdf.length}: ${conPdf[i].nombre}`);
        await pausa();
        const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
        const paginas = await salida.copyPages(doc, doc.getPageIndices());
        paginas.forEach((pg) => salida.addPage(pg));
      }
      setEstado('Generando archivo…');
      await pausa();
      const blob = new Blob([await salida.save()], { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      const a = Object.assign(document.createElement('a'), { href: url, download: 'informes-pruebas-natys.pdf' });
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 60000);
      setEstado(`Listo: informes-pruebas-natys.pdf (${MB(blob.size)} MB) está en tus descargas.`);
    } catch (e) {
      setError(true);
      setEstado(`Error: ${mensajeError(e)}`);
    } finally {
      setOcupado(false);
    }
  };

  return (
    <div className="merge card">
      <div>
        <b>Todos los informes en un solo PDF</b>
        <small className={error ? 'merge__error' : undefined}>
          {estado || `Une los ${conPdf.length} informes disponibles: ${conPdf.map((m) => m.nombre).join(', ')}.`}
        </small>
      </div>
      <button className="btn" onClick={juntar} disabled={ocupado || !conPdf.length}>
        {ocupado ? 'Uniendo…' : error ? 'Reintentar' : 'Juntar y descargar'}
      </button>
    </div>
  );
}

// Página aparte (#/pruebas): un contenedor por módulo con su informe de pruebas
function TestsPage({ onOpen }) {
  const [quien, setQuien] = useState('todos');
  const lista = quien === 'todos'
    ? modulos
    : modulos.filter((m) => m.responsable === quien).sort((a, b) => esPrincipal(b) - esPrincipal(a));
  const listos = modulos.filter((m) => m.pdf || m.docx).length;

  const abrir = (m) => {
    const titulo = `Informe de pruebas · ${m.nombre}`;
    if (m.pdf) onOpen({ title: titulo, type: 'pdf', file: m.pdf, download: m.docx || m.pdf });
    else if (m.docx) window.open(asset(m.docx), '_blank');
  };

  return (
    <section id="pruebas" className="section page">
      <div className="container">
        <a className="back" href="#inicio">← Volver al inicio</a>
        <div className="stitle">
          <span>Pruebas · Natys</span>
          <h2>Informes de pruebas por módulo</h2>
          <p>
            Cada módulo guarda su informe de pruebas. Haz clic para verlo aquí mismo.{' '}
            <b className="tcount">{listos} de {modulos.length} listos</b>
          </p>
        </div>

        <div className="tabs">
          <button className={`tab ${quien === 'todos' ? 'is-active' : ''}`} onClick={() => setQuien('todos')}>Todos</button>
          {integrantes.map((p) => (
            <button key={p.id} className={`tab ${quien === p.id ? 'is-active' : ''}`} onClick={() => setQuien(p.id)}>
              {p.nombre.split(' ')[0]}
            </button>
          ))}
        </div>

        <div className="docs">
          {lista.map((m) => {
            const listo = Boolean(m.pdf || m.docx);
            return (
              <button key={m.id} className={`doc card ${listo ? '' : 'is-pending'} ${esPrincipal(m) ? 'is-main' : ''}`} onClick={() => listo && abrir(m)}>
                <div className="doc__thumb">
                  {m.thumb ? (
                    <img src={asset(m.thumb)} alt={`Informe ${m.nombre}`} loading="lazy" />
                  ) : (
                    <span className="doc__icon">{listo ? (m.pdf ? 'PDF' : 'DOCX') : 'TEST'}</span>
                  )}
                </div>
                <div className="doc__body">
                  <b>{m.nombre}</b>
                  <small>{persona[m.responsable].nombre}</small>
                  <span className="doc__pills">
                    {esPrincipal(m) && <span className="pill pill--main">★ Principal</span>}
                    <span className={`pill ${listo ? 'pill--ok' : ''}`}>{listo ? 'Informe' : 'Pendiente'}</span>
                  </span>
                </div>
              </button>
            );
          })}
        </div>

        <MergeButton />
      </div>
    </section>
  );
}

// Contenido privado: pide la clave antes de mostrar la página de pruebas
const CLAVE = 'nomelase';
const CLAVE_GUARDADA = 'natys-pruebas-ok';
const yaDesbloqueado = () => {
  try { return sessionStorage.getItem(CLAVE_GUARDADA) === '1'; } catch { return false; }
};

function Candado({ onOk }) {
  const [valor, setValor] = useState('');
  const [error, setError] = useState(false);

  const entrar = (e) => {
    e.preventDefault();
    if (valor !== CLAVE) { setError(true); return; }
    try { sessionStorage.setItem(CLAVE_GUARDADA, '1'); } catch { /* sin almacenamiento: pide la clave otra vez */ }
    onOk();
  };

  return (
    <section id="pruebas" className="section page">
      <div className="container">
        <a className="back" href="#inicio">← Volver al inicio</a>
        <div className="stitle">
          <span>Contenido privado</span>
          <h2>Pruebas · Natys</h2>
          <p>Esta sección está protegida. Escribe la clave para ver los informes.</p>
        </div>
        <form className="card merge" onSubmit={entrar}>
          <div>
            <b>Clave de acceso</b>
            <small className={error ? 'merge__error' : undefined}>
              {error ? 'Clave incorrecta. Intenta de nuevo.' : 'Ingresa la clave para continuar.'}
            </small>
          </div>
          <input
            type="password"
            value={valor}
            onChange={(e) => { setValor(e.target.value); setError(false); }}
            aria-label="Clave de acceso"
            autoFocus
          />
          <button className="btn" type="submit">Entrar</button>
        </form>
      </div>
    </section>
  );
}

export default function TestsGate({ onOpen }) {
  const [ok, setOk] = useState(yaDesbloqueado);
  return ok ? <TestsPage onOpen={onOpen} /> : <Candado onOk={() => setOk(true)} />;
}
