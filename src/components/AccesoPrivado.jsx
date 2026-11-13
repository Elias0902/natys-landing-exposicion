import { useEffect, useState } from 'react';

// Misma clave y misma sesión que la sección de Pruebas: al entrar en una, se abren las demás
export const CLAVE = 'nomelase';
const CLAVE_GUARDADA = 'natys-pruebas-ok';

export const yaDesbloqueado = () => {
  try { return sessionStorage.getItem(CLAVE_GUARDADA) === '1'; } catch { return false; }
};

// Formulario de clave reutilizable
export function FormularioClave({ onOk, titulo, texto }) {
  const [valor, setValor] = useState('');
  const [error, setError] = useState(false);

  const entrar = (e) => {
    e.preventDefault();
    if (valor !== CLAVE) { setError(true); return; }
    try { sessionStorage.setItem(CLAVE_GUARDADA, '1'); } catch { /* sin almacenamiento: pide la clave otra vez */ }
    onOk();
  };

  return (
    <form className="card merge" onSubmit={entrar}>
      <div>
        <b>{titulo}</b>
        <small className={error ? 'merge__error' : undefined}>
          {error ? 'Clave incorrecta. Intenta de nuevo.' : texto}
        </small>
      </div>
      <input
        type="password"
        value={valor}
        onChange={(e) => { setValor(e.target.value); setError(false); }}
        aria-label="Clave de acceso"
      />
      <button className="btn" type="submit">Entrar</button>
    </form>
  );
}

// Ventana de login que se abre desde el botón del header
export function LoginModal({ onOk, onClose }) {
  useEffect(() => {
    const esc = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [onClose]);

  return (
    <div
      className="sim-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Login"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div
        style={{
          position: 'relative',
          width: 'min(420px, 100%)',
          padding: 20,
          borderRadius: 14,
          background: 'var(--card, #fff)',
          boxShadow: '0 30px 80px rgba(0, 0, 0, 0.4)',
        }}
      >
        <button
          onClick={onClose}
          aria-label="Cerrar"
          style={{
            position: 'absolute',
            top: 8,
            right: 10,
            background: 'none',
            border: 0,
            color: 'inherit',
            fontSize: 22,
            cursor: 'pointer',
          }}
        >
          ×
        </button>
        <FormularioClave
          onOk={onOk}
          titulo="Login"
          texto="Ingresa la clave para ver los documentos privados."
        />
      </div>
    </div>
  );
}
