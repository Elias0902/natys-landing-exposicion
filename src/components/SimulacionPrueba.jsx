import { useEffect, useRef, useState } from 'react';
import './simulacion.css';
import './simulacion-acciones.css';
import './simulacion-camion.css';
import { FlowBars, FlowTable, ResponseChart } from './Dashboard';
import { thresholds } from '../data/metrics';

// Camioncito de entregas que avanza sobre la barra de carga; las ruedas giran
function Camion() {
  return (
    <svg className="sim-camion-svg" viewBox="0 0 64 34" width="44" height="24" aria-hidden="true">
      <rect x="2" y="6" width="38" height="19" rx="3" fill="#e43b3b" />
      <path d="M40 12h11l9 9v4H40z" fill="#ff8a65" />
      <rect x="45" y="14" width="8" height="5" rx="1" fill="#fff" opacity=".9" />
      <rect x="10" y="10" width="18" height="6" rx="1" fill="#fff" opacity=".85" />
      <g className="sim-rueda">
        <circle cx="13" cy="27" r="5" fill="#222" />
        <circle cx="13" cy="27" r="1.6" fill="#ccc" />
      </g>
      <g className="sim-rueda">
        <circle cx="48" cy="27" r="5" fill="#222" />
        <circle cx="48" cy="27" r="1.6" fill="#ccc" />
      </g>
    </svg>
  );
}

// Duración: 1,5 s de "procesando" + 3,5 s de ejecución = 5 s en total
const CARGA_MS = 1500;
const EJECUCION_MS = 3500;
const TOTAL_MS = CARGA_MS + EJECUCION_MS;
const TICK_MS = 80;

// Código real de tests/EntregaTest.php (patrón AAA: Arrange, Act, Assert)
const CODIGO = `// tests/EntregaTest.php · test_modificar_entrega_inexistente_es_rechazada

public function test_modificar_entrega_inexistente_es_rechazada()
{
    // 1. DATOS (Arrange): Configuramos el mock para que la entrega 999 no exista
    $stmtMock->method('fetch')->willReturn(false);
    $pdoMock->expects($this->once())->method('rollBack');  // Debe deshacer la transacción
    $pdoMock->expects($this->never())->method('commit');   // Nunca debe confirmar cambios

    // 2. ACCIÓN (Act): Pedimos al modelo que intente modificar la entrega inexistente
    $resultado = $entrega->manejarAccion('modificar', json_encode([
        'id' => 999,
        'repartidor' => 'Carlos Pérez',
        'sector' => 'Oeste'
    ]));

    // 3. VERIFICACIÓN (Assert): Comprobamos que rechace la operación y devuelva el mensaje exacto
    $this->assertFalse($resultado['status']);
    $this->assertEquals('Entrega no existe', $resultado['msj']);
}`.split('\n');

const CMD_PRUEBAS = 'vendor\\bin\\phpunit tests\\EntregaTest.php --filter test_modificar_entrega_inexistente_es_rechazada --testdox';
const CMD_CARGA = 'node scripts/carga.js --usuarios 100 --duracion 5m';

// La prueba que se ejecuta en la terminal
const PRUEBAS = ['test_modificar_entrega_inexistente_es_rechazada'];
const RESULTADO_PRUEBA = 'Prueba aprobada: la entrega 999 es rechazada con «Entrega no existe».';

const f0 = (n) => Math.round(n).toLocaleString('es-VE');
const f1 = (n) => n.toFixed(1);
const clamp = (n) => Math.min(1, Math.max(0, n));

export default function SimulacionPrueba({ scenario, onClose, onVerDashboard }) {
  const [t, setT] = useState(0);
  const [vista, setVista] = useState('simulacion'); // 'simulacion' | 'graficas'
  const cerrarRef = useRef(onClose);
  cerrarRef.current = onClose;

  // Un solo reloj controla todas las fases; así el timing no depende de cuántos efectos haya
  useEffect(() => {
    const inicio = performance.now();
    const id = setInterval(() => {
      const ms = Math.min(performance.now() - inicio, TOTAL_MS);
      setT(ms);
      if (ms >= TOTAL_MS) clearInterval(id);
    }, TICK_MS);
    const esc = (e) => { if (e.key === 'Escape') cerrarRef.current(); };
    window.addEventListener('keydown', esc);
    return () => {
      clearInterval(id);
      window.removeEventListener('keydown', esc);
    };
  }, []);

  const k = scenario.kpis;
  const cargando = t < CARGA_MS;
  const p = clamp((t - CARGA_MS) / EJECUCION_MS); // avance de la ejecución, 0..1
  const listo = p >= 1;
  const pruebaVisible = p >= 0.3;                // la prueba aparece al 30 %
  const resumenVisible = p >= 0.6;               // el resumen de la prueba al 60 %
  const faseCarga = clamp((p - 0.6) / 0.4);      // último 40%: carga, los valores convergen
  const lineaActiva = Math.min(CODIGO.length - 1, Math.floor(p * CODIGO.length));

  // Valor que se mueve al azar y termina exactamente en el resultado final
  const converge = (final) => {
    const suave = 1 - Math.pow(1 - faseCarga, 3);
    const azar = final * (0.3 + Math.random() * 1.4);
    return azar + (final - azar) * suave;
  };

  const acciones = (
    <div className="sim-actions">
      {vista === 'graficas' ? (
        <button className="btn btn--ghost sim-back" onClick={() => setVista('simulacion')}>
          ← Volver a la simulación
        </button>
      ) : (
        <button className="btn btn--ghost" onClick={() => setVista('graficas')}>
          Ver gráficas
        </button>
      )}
      <button className="btn" onClick={() => onVerDashboard(scenario.id)}>
        Ver dashboard
      </button>
    </div>
  );

  return (
    <div
      className="sim-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Simulación de prueba"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className="sim-box">
        <div className="sim-head">
          <b>Simulación de prueba · Sistema Naty's</b>
          <button className="sim-close" onClick={onClose} aria-label="Cerrar">×</button>
        </div>

        {cargando ? (
          <div className="sim-load">
            <div className="sim-spin" />
            <b>Procesando…</b>
            <p className="sim-muted">Preparando el entorno de pruebas</p>
            <div className="sim-bar-wrap">
              <div className="sim-bar">
                <i style={{ width: `${(t / CARGA_MS) * 100}%` }} />
              </div>
              <span className="sim-camion" style={{ left: `${Math.min(96, Math.max(4, (t / CARGA_MS) * 100))}%` }}>
                <Camion />
              </span>
            </div>
          </div>
        ) : vista === 'graficas' && listo ? (
          <>
            <div className="sim-scroll">
              <div className="card panel">
                <div className="panel__head">
                  <h3>Tiempo de respuesta</h3>
                  <small>ms durante los 5 minutos de la prueba</small>
                </div>
                <ResponseChart data={scenario.timeline} />
              </div>
              <div className="card panel">
                <div className="panel__head">
                  <h3>Respuesta media por flujo</h3>
                  <small>Línea punteada: límite de {f0(thresholds.avgMs)} ms</small>
                </div>
                <FlowBars flows={scenario.flows} />
              </div>
              <div className="card panel">
                <div className="panel__head">
                  <h3>Resultados por flujo</h3>
                  <small>Aserción: código 200 y error menor al {thresholds.errorRate}%</small>
                </div>
                <FlowTable flows={scenario.flows} />
              </div>
            </div>
            {acciones}
          </>
        ) : (
          <>
            <div className="sim-bar sim-bar--top">
              <i style={{ width: `${p * 100}%` }} />
            </div>

            <div className="sim-split">
              <div className="sim-pane">
                <div className="sim-pane-title">EntregaTest.php</div>
                <div className="sim-code">
                  {CODIGO.map((linea, i) => (
                    <div
                      key={i}
                      className={`sim-ln${i < lineaActiva ? ' is-run' : ''}${i === lineaActiva && !listo ? ' is-now' : ''}`}
                    >
                      <span>{i + 1}</span>
                      <code>{linea || ' '}</code>
                    </div>
                  ))}
                </div>
              </div>

              <div className="sim-pane">
                <div className="sim-pane-title">Terminal</div>
                <div className="sim-term">
                  <p><span className="sim-muted">PS natys&gt;</span> {CMD_PRUEBAS}</p>

                  {pruebaVisible && PRUEBAS.map((nombre) => (
                    <p key={nombre} className="sim-ok">
                      ✓ <span className="sim-txt">{nombre}</span>
                    </p>
                  ))}

                  {resumenVisible && (
                    <p className="sim-ok">
                      Tests: {PRUEBAS.length} · Pasan: {PRUEBAS.length} · Fallan: 0
                    </p>
                  )}

                  {faseCarga > 0 && (
                    <>
                      <p className="sim-gap"><span className="sim-muted">PS natys&gt;</span> {CMD_CARGA}</p>
                      <p className="sim-kv"><span>Usuarios virtuales</span><b>{f0(converge(k.virtualUsers))}</b></p>
                      <p className="sim-kv"><span>Peticiones</span><b>{f0(converge(k.requests))}</b></p>
                      <p className="sim-kv"><span>Tasa de error</span><b>{f1(converge(k.errorRate))} %</b></p>
                      <p className="sim-kv"><span>Respuesta media</span><b>{f0(converge(k.avgMs))} ms</b></p>
                      <p className="sim-kv"><span>Throughput</span><b>{f1(converge(k.throughput))} req/s</b></p>
                    </>
                  )}

                  {!listo && <span className="sim-cursor" />}
                </div>
              </div>
            </div>

            {listo && (
              <>
                <div className="sim-result is-ok">
                  ✓ {RESULTADO_PRUEBA}
                </div>
                {acciones}
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}
