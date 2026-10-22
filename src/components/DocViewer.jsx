import { useEffect, useRef, useState } from 'react';
import { asset } from '../data/content';

// pdf.js se carga desde CDN solo al abrir un PDF (sin npm install)
const PDFJS = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/legacy/build/pdf.min.mjs';
const PDFJS_WORKER = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/legacy/build/pdf.worker.min.mjs';

const ZOOMS = [1, 1.5, 2];

let pdfjsPromise;
function loadPdfjs() {
  pdfjsPromise ??= import(/* @vite-ignore */ PDFJS).then((lib) => {
    lib.GlobalWorkerOptions.workerSrc = PDFJS_WORKER;
    return lib;
  });
  return pdfjsPromise;
}

// Una página: reserva su alto y se dibuja solo cuando está cerca de la pantalla
function PdfPage({ pdf, num, ratio, width, root }) {
  const ref = useRef(null);
  const [near, setNear] = useState(false);

  useEffect(() => {
    const el = ref.current;
    const io = new IntersectionObserver(
      ([e]) => e.isIntersecting && setNear(true),
      { root: root.current, rootMargin: '1200px 0px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [root]);

  useEffect(() => {
    if (!near || !width) return;
    let task;
    let cancel = false;
    pdf.getPage(num).then((page) => {
      if (cancel) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const base = page.getViewport({ scale: 1 });
      const viewport = page.getViewport({ scale: (width * dpr) / base.width });
      const canvas = document.createElement('canvas');
      canvas.width = Math.floor(viewport.width);
      canvas.height = Math.floor(viewport.height);
      task = page.render({ canvasContext: canvas.getContext('2d'), canvas, viewport });
      task.promise
        .then(() => {
          if (cancel || !ref.current) return;
          ref.current.replaceChildren(canvas);
        })
        .catch(() => {});
    });
    return () => {
      cancel = true;
      task?.cancel();
    };
  }, [near, width, pdf, num]);

  return <div ref={ref} className="pv__page" style={{ width, height: width * ratio }} />;
}

function PdfView({ src, zoom, scroller, onPages, onError }) {
  const [pdf, setPdf] = useState(null);
  const [ratios, setRatios] = useState([]);
  const [box, setBox] = useState(0);

  // Ancho disponible del visor (se ajusta al girar el celular o cambiar ventana)
  useEffect(() => {
    const el = scroller.current;
    const ro = new ResizeObserver(() => setBox(el.clientWidth));
    ro.observe(el);
    return () => ro.disconnect();
  }, [scroller]);

  // Los callbacks van en una ref para no recargar el PDF en cada render
  const cb = useRef({ onPages, onError });
  cb.current = { onPages, onError };

  useEffect(() => {
    let alive = true;
    let task;
    loadPdfjs()
      .then((lib) => {
        task = lib.getDocument({ url: src });
        return task.promise;
      })
      .then(async (d) => {
        const r = [];
        for (let i = 1; i <= d.numPages; i++) {
          const vp = (await d.getPage(i)).getViewport({ scale: 1 });
          r.push(vp.height / vp.width);
        }
        if (!alive) return;
        setPdf(d);
        setRatios(r);
        cb.current.onPages(d.numPages);
      })
      .catch(() => alive && cb.current.onError());
    return () => {
      alive = false;
      task?.destroy();
    };
  }, [src]);

  if (!pdf) return <div className="pv__msg">Cargando documento…</div>;
  const pad = box < 600 ? 16 : 48;
  const width = Math.max(200, Math.min(box - pad, 900)) * zoom;
  return (
    <div className="pv__pages">
      {ratios.map((ratio, i) => (
        <PdfPage key={i} pdf={pdf} num={i + 1} ratio={ratio} width={width} root={scroller} />
      ))}
    </div>
  );
}

export default function DocViewer({ doc, onClose }) {
  const scroller = useRef(null);
  const [zoom, setZoom] = useState(0);
  const [pages, setPages] = useState(0);
  const [current, setCurrent] = useState(1);
  const [fallback, setFallback] = useState(false);
  const isPdf = doc.type === 'pdf' && /\.pdf$/i.test(doc.file);

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
  const z = ZOOMS[zoom];

  // Página actual = la que ocupa el centro del visor
  const onScroll = (e) => {
    const el = e.currentTarget;
    const mid = el.scrollTop + el.clientHeight / 2;
    const list = el.querySelectorAll('.pv__page');
    let n = 1;
    list.forEach((pg, i) => { if (pg.offsetTop <= mid) n = i + 1; });
    if (n !== current) setCurrent(n);
  };

  let body;
  if (isPdf && !fallback) {
    body = (
      <PdfView
        src={asset(doc.file)}
        zoom={z}
        scroller={scroller}
        onPages={setPages}
        onError={() => setFallback(true)}
      />
    );
  } else if (isPdf) {
    body = <iframe src={`${asset(doc.file)}#view=FitH`} title={doc.title} />;
  } else if (doc.type === 'pdf') {
    body = (
      <div className="pv__msg">
        Este archivo no se puede previsualizar aquí.
        <a className="btn btn--sm" href={download} download>Descargar</a>
      </div>
    );
  } else {
    body = <img className="pv__img" src={asset(doc.file)} alt={doc.title} style={{ width: `${z * 100}%` }} />;
  }

  return (
    <div className="modal" onClick={onClose}>
      <div className="modal__box" onClick={(e) => e.stopPropagation()}>
        <div className="modal__head">
          <b className="modal__title">{doc.title}</b>
          <div className="modal__tools">
            {pages > 0 && !fallback && <span className="pv__count">{current} / {pages}</span>}
            {!fallback && (
              <span className="pv__zoom">
                <button onClick={() => setZoom(Math.max(0, zoom - 1))} disabled={zoom === 0} aria-label="Alejar">−</button>
                <button onClick={() => setZoom(0)} title="Ajustar al ancho">{Math.round(z * 100)}%</button>
                <button onClick={() => setZoom(Math.min(ZOOMS.length - 1, zoom + 1))} disabled={zoom === ZOOMS.length - 1} aria-label="Acercar">+</button>
              </span>
            )}
            <a className="btn btn--sm btn--ghost pv__open" href={asset(doc.file)} target="_blank" rel="noreferrer">Abrir</a>
            <a className="btn btn--sm" href={download} download>Descargar</a>
            <button className="close" onClick={onClose} aria-label="Cerrar">✕</button>
          </div>
        </div>
        <div className={`modal__body ${z > 1 ? 'is-zoomed' : ''}`} ref={scroller} onScroll={pages ? onScroll : undefined}>{body}</div>
      </div>
    </div>
  );
}
