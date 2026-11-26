import { useEffect, useRef, useState } from 'react';
import { asset } from '../data/content';
import { loadPdfjs, pdfSource } from '../lib/pdf';
import DrawioView from './DrawioView';
import archiveContents from '../data/archiveContents.json';

// Heavy previews are only mounted near the viewport and released when offscreen.
function PdfThumbnail({ src }) {
  const canvas = useRef(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let cancelled = false;
    let loading;
    let render;
    loadPdfjs().then((pdfjs) => {
      if (cancelled) return;
      loading = pdfjs.getDocument(pdfSource(src));
      return loading.promise;
    }).then(async (pdf) => {
      if (!pdf || cancelled) return;
      const page = await pdf.getPage(1);
      if (cancelled || !canvas.current) return;
      const viewport = page.getViewport({ scale: 500 / page.getViewport({ scale: 1 }).width });
      const element = canvas.current;
      element.width = viewport.width;
      element.height = viewport.height;
      render = page.render({ canvasContext: element.getContext('2d'), canvas: element, viewport });
      await render.promise;
    }).catch(() => { if (!cancelled) setError(true); });
    return () => { cancelled = true; render?.cancel(); loading?.destroy(); };
  }, [src]);
  return error ? <span className="preview-error">Vista previa PDF</span> : <canvas ref={canvas} className="repo-pdf-thumb" />;
}

function DocxThumbnail({ src }) {
  const host = useRef(null);
  const wrapper = useRef(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    const controller = new AbortController();
    let alive = true;
    const resize = new ResizeObserver(() => {
      if (wrapper.current && host.current) host.current.style.transform = `scale(${wrapper.current.clientWidth / 816})`;
    });
    resize.observe(wrapper.current);
    Promise.all([fetch(src, { signal: controller.signal }), import('docx-preview')]).then(async ([response, { renderAsync }]) => {
      if (!response.ok) throw new Error('No se pudo cargar');
      const bytes = await response.arrayBuffer();
      if (!alive || !host.current) return;
      await renderAsync(bytes, host.current, null, { inWrapper: true, renderHeaders: true, renderFooters: false, renderFootnotes: false, ignoreLastRenderedPageBreak: false, className: 'docx-thumb' });
    }).catch((e) => { if (alive && e.name !== 'AbortError') setError(true); });
    return () => { alive = false; controller.abort(); resize.disconnect(); };
  }, [src]);
  return error ? <span className="preview-error">Documento Word</span> : <div className="repo-docx-thumb" ref={wrapper}><div ref={host} /></div>;
}

function TextThumbnail({ src }) {
  const [text, setText] = useState('Cargando código…');
  useEffect(() => {
    const controller = new AbortController();
    fetch(src, { signal: controller.signal }).then((r) => { if (!r.ok) throw new Error(); return r.text(); })
      .then((t) => setText(t.slice(0, 2200))).catch((e) => { if (e.name !== 'AbortError') setText('Archivo de código'); });
    return () => controller.abort();
  }, [src]);
  return <pre className="repo-code-thumb">{text}</pre>;
}

export default function FileThumbnail({ file }) {
  const host = useRef(null);
  const [near, setNear] = useState(false);
  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => setNear(entry.isIntersecting), { rootMargin: '180px' });
    observer.observe(host.current);
    return () => observer.disconnect();
  }, []);
  const src = asset(file.file);
  const archive = archiveContents[file.file];
  let preview = <span className="repo-preview-loading">{file.format}</span>;
  if (near) {
    if (file.thumb) preview = <img src={asset(file.thumb)} alt="" loading="lazy" />;
    else if (['PNG', 'JPG', 'JPEG', 'SVG'].includes(file.format)) preview = <img src={src} alt="" loading="lazy" />;
    else if (file.format === 'DRAWIO') preview = <DrawioView src={src} title={file.title} thumbnail />;
    else if (file.format === 'PDF') preview = <PdfThumbnail src={src} />;
    else if (file.format === 'DOCX') preview = <DocxThumbnail src={src} />;
    else if (archive) preview = <div className="repo-archive-thumb"><b>{archive.length} archivos</b>{archive.slice(0, 4).map((f) => <span key={f.original}>{f.title}</span>)}</div>;
    else if (file.format === 'SQL') preview = <TextThumbnail src={src} />;
  }
  return <div ref={host} className={`repo-preview preview-${file.format.toLowerCase()}`} aria-hidden="true">{preview}<span className="repo-preview-hint">Previsualizar</span></div>;
}
