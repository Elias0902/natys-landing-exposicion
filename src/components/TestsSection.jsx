import { useState } from 'react';
import { asset } from '../data/content';
import { integrantes, modulos } from '../data/pruebas';

const persona = Object.fromEntries(integrantes.map((p) => [p.id, p]));
const esPrincipal = (m) => persona[m.responsable].principal === m.id;

// pdf-lib se carga desde CDN solo al pulsar el botón (no hace falta npm install)
const PDF_LIB = 'https://cdn.jsdelivr.net/npm/pdf-lib@1.17.1/dist/pdf-lib.esm.min.js';

// Une todos los PDF disponibles, en el orden de la lista, y descarga el resultado
function MergeButton() {
  const conPdf = modulos.filter((m) => m.pdf);
  const [estado, setEstado] = useState('');
  const ocupado = estado && !estado.startsWith('Error');

  const juntar = async () => {
    try {
      setEstado('Cargando…');
      const { PDFDocument } = await import(/* @vite-ignore */ PDF_LIB);
      const salida = await PDFDocument.create();
      salida.setTitle('Informes de pruebas · Natys · Equipo 8');
      for (const [i, m] of conPdf.entries()) {
        setEstado(`Uniendo ${i + 1} de ${conPdf.length}: ${m.nombre}`);
        const bytes = await fetch(asset(m.pdf)).then((r) => {
          if (!r.ok) throw new Error(`No se encontró ${m.pdf}`);
          return r.arrayBuffer();
        });
        const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
        const paginas = await salida.copyPages(doc, doc.getPageIndices());
        paginas.forEach((pg) => salida.addPage(pg));
      }
      setEstado('Generando archivo…');
      const blob = new Blob([await salida.save()], { type: 'application/pdf' });
      const url = URL.createObjectURL(blob);
      const a = Object.assign(document.createElement('a'), { href: url, download: 'informes-pruebas-natys.pdf' });
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 10000);
      setEstado('');
    } catch (e) {
      setEstado(`Error: ${e.message}`);
    }
  };

  return (
    <div className="merge card">
      <div>
        <b>Todos los informes en un solo PDF</b>
        <small>
          {estado || `Une los ${conPdf.length} informes disponibles: ${conPdf.map((m) => m.nombre).join(', ')}.`}
        </small>
      </div>
      <button className="btn" onClick={juntar} disabled={ocupado || !conPdf.length}>
        {ocupado ? 'Uniendo…' : 'Juntar y descargar'}
      </button>
    </div>
  );
}

// Página aparte (#/pruebas): un contenedor por módulo con su informe de pruebas
export default function TestsPage({ onOpen }) {
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
