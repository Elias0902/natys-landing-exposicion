import { useLayoutEffect, useRef, useState } from 'react';
import { asset } from '../data/content';

export default function DrawioView({ src, title, thumbnail = false, onClose }) {
  const frame = useRef(null);
  const [error, setError] = useState('');
  useLayoutEffect(() => {
    const controller = new AbortController();
    let xml;
    let ready = false;
    let sent = false;
    const send = () => {
      if (xml && ready && !sent && frame.current?.contentWindow) {
        sent = true;
        frame.current.contentWindow.postMessage({ channel: 'natys-diagram', action: 'load', xml, thumbnail }, window.location.origin);
      }
    };
    const onMessage = (event) => {
      if (event.source !== frame.current?.contentWindow || event.origin !== window.location.origin || event.data?.channel !== 'natys-diagram') return;
      if (event.data.action === 'ready') { ready = true; send(); }
      if (event.data.action === 'error') setError('No se pudo mostrar el diagrama.');
      if (event.data.action === 'close') onClose?.();
    };
    window.addEventListener('message', onMessage);
    fetch(src, { signal: controller.signal }).then((response) => {
      if (!response.ok) throw new Error('No se pudo cargar el diagrama.');
      return response.text();
    }).then((text) => { xml = text; send(); }).catch((e) => { if (e.name !== 'AbortError') setError(e.message); });
    return () => { controller.abort(); window.removeEventListener('message', onMessage); };
  }, [src, thumbnail, onClose]);
  return error ? <div className="preview-error">{error}</div> : <iframe ref={frame} className="drawio-frame" src={asset('diagram-viewer.html')} title={`Diagrama · ${title}`} sandbox="allow-scripts allow-same-origin" tabIndex={thumbnail ? -1 : 0} />;
}
