import { useState } from 'react';
import { scenarios, thresholds } from '../data/metrics';

const fmt = (n) => n.toLocaleString('es-VE');

const STATE = {
  ok: { icon: '✓', text: 'Correcto' },
  fail: { icon: '✕', text: 'Falló' },
  skip: { icon: '–', text: 'Omitido' },
};

function Kpi({ label, value, unit, note, tone }) {
  return (
    <div className="kpi card">
      <span className="kpi__label">{label}</span>
      <b className="kpi__value">
        {value}
        {unit && <small>{unit}</small>}
      </b>
      {note && <span className={`kpi__note ${tone ? `is-${tone}` : ''}`}>{note}</span>}
    </div>
  );
}

function Pipeline({ steps }) {
  return (
    <ol className="pipe">
      {steps.map((s) => (
        <li key={s.stage} className={`pipe__step is-${s.state}`}>
          <span className="pipe__icon" aria-hidden="true">{STATE[s.state].icon}</span>
          <span>
            <b>{s.stage}</b>
            <small>{STATE[s.state].text} · {s.time}</small>
          </span>
        </li>
      ))}
    </ol>
  );
}

// Area chart of response time with a hover crosshair and tooltip
function ResponseChart({ data }) {
  const [hover, setHover] = useState(null);
  const W = 720;
  const H = 260;
  const pad = { l: 48, r: 12, t: 12, b: 28 };
  const max = Math.ceil(Math.max(...data.map((d) => d.ms)) / 500) * 500;
  const x = (i) => pad.l + (i / (data.length - 1)) * (W - pad.l - pad.r);
  const y = (v) => pad.t + (1 - v / max) * (H - pad.t - pad.b);
  const line = data.map((d, i) => `${i ? 'L' : 'M'}${x(i)},${y(d.ms)}`).join('');
  const area = `${line}L${x(data.length - 1)},${y(0)}L${x(0)},${y(0)}Z`;
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((f) => Math.round(max * f));
  const limit = thresholds.avgMs;

  const onMove = (e) => {
    const box = e.currentTarget.getBoundingClientRect();
    const px = ((e.clientX - box.left) / box.width) * W;
    const i = Math.round(((px - pad.l) / (W - pad.l - pad.r)) * (data.length - 1));
    setHover(Math.max(0, Math.min(data.length - 1, i)));
  };

  const h = hover !== null ? data[hover] : null;
  return (
    <div className="chart">
      <svg viewBox={`0 0 ${W} ${H}`} onMouseMove={onMove} onMouseLeave={() => setHover(null)} role="img" aria-label="Tiempo de respuesta durante la prueba">
        <defs>
          <linearGradient id="fillRed" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#e43b3b" stopOpacity=".35" />
            <stop offset="100%" stopColor="#e43b3b" stopOpacity="0" />
          </linearGradient>
        </defs>
        {ticks.map((t) => (
          <g key={t}>
            <line x1={pad.l} x2={W - pad.r} y1={y(t)} y2={y(t)} className="grid" />
            <text x={pad.l - 8} y={y(t) + 4} className="axis" textAnchor="end">{fmt(t)}</text>
          </g>
        ))}
        {data.map((d, i) => i % 12 === 0 && (
          <text key={d.t} x={x(i)} y={H - 8} className="axis" textAnchor="middle">{d.t}</text>
        ))}
        {limit < max && (
          <g>
            <line x1={pad.l} x2={W - pad.r} y1={y(limit)} y2={y(limit)} className="limit" />
            <text x={W - pad.r} y={y(limit) - 6} className="axis" textAnchor="end">Límite {fmt(limit)} ms</text>
          </g>
        )}
        <path d={area} fill="url(#fillRed)" />
        <path d={line} fill="none" stroke="#e43b3b" strokeWidth="2" strokeLinejoin="round" />
        {h && (
          <g>
            <line x1={x(hover)} x2={x(hover)} y1={pad.t} y2={y(0)} className="cross" />
            <circle cx={x(hover)} cy={y(h.ms)} r="5" fill="#e43b3b" stroke="var(--card)" strokeWidth="2" />
          </g>
        )}
      </svg>
      {h && (
        <div className="tip" style={{ left: `${(x(hover) / W) * 100}%` }}>
          <b>{fmt(h.ms)} ms</b>
          <span>Minuto {h.t} · {h.users} usuarios</span>
        </div>
      )}
    </div>
  );
}

// Horizontal bars of average response time per flow
function FlowBars({ flows }) {
  const [hover, setHover] = useState(null);
  const max = Math.max(...flows.map((f) => f.avgMs), thresholds.avgMs);
  return (
    <ul className="bars">
      {flows.map((f) => {
        const bad = f.avgMs > thresholds.avgMs || f.errors > thresholds.errorRate;
        return (
          <li key={f.name} onMouseEnter={() => setHover(f.name)} onMouseLeave={() => setHover(null)}>
            <span className="bars__name">{f.name}</span>
            <span className="bars__track">
              <span className="bars__fill" style={{ width: `${(f.avgMs / max) * 100}%` }} />
              <span className="bars__limit" style={{ left: `${(thresholds.avgMs / max) * 100}%` }} />
              {hover === f.name && (
                <span className="tip tip--bar">
                  <b>{fmt(f.avgMs)} ms</b>
                  <span>p90 {fmt(f.p90)} ms · error {f.errors}%</span>
                </span>
              )}
            </span>
            <span className={`bars__val ${bad ? 'is-fail' : 'is-ok'}`}>
              {bad ? '✕' : '✓'} {fmt(f.avgMs)} ms
            </span>
          </li>
        );
      })}
    </ul>
  );
}

function FlowTable({ flows }) {
  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr>
            <th>Flujo</th>
            <th>Muestras</th>
            <th>Promedio</th>
            <th>p90</th>
            <th>Error</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          {flows.map((f) => {
            const bad = f.avgMs > thresholds.avgMs || f.errors > thresholds.errorRate;
            return (
              <tr key={f.name}>
                <td>{f.name}</td>
                <td>{fmt(f.samples)}</td>
                <td>{fmt(f.avgMs)} ms</td>
                <td>{fmt(f.p90)} ms</td>
                <td>{f.errors}%</td>
                <td>
                  <span className={`state is-${bad ? 'fail' : 'ok'}`}>{bad ? '✕ Falla' : '✓ Pasa'}</span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export default function Dashboard({ selected, onSelect }) {
  const s = scenarios.find((x) => x.id === selected) ?? scenarios[0];
  const k = s.kpis;
  const unitOk = k.unitPassed === k.unitTotal;

  return (
    <section id="dashboard" className="section">
      <div className="container">
        <div className="dash-top card">
          <div>
            <h2>Dashboard</h2>
            <p className="muted">Prueba de carga JMeter + pipeline CI/CD · Galletas Natys</p>
          </div>
          <div className="tabs tabs--tight">
            {scenarios.map((x) => (
              <button key={x.id} className={`tab ${x.id === s.id ? 'is-active' : ''}`} onClick={() => onSelect(x.id)}>
                <i className={`dot dot--${x.status}`} /> {x.label}
              </button>
            ))}
          </div>
        </div>

        <div className={`banner is-${s.status}`}>
          <span className="banner__icon" aria-hidden="true">{s.status === 'ok' ? '✓' : '✕'}</span>
          <div>
            <b>{s.summary}</b>
            <small>{s.commit}</small>
          </div>
        </div>

        <Pipeline steps={s.pipeline} />

        <div className="kpis">
          <Kpi label="Usuarios virtuales" value={fmt(k.virtualUsers)} note="Thread Group" />
          <Kpi label="Peticiones" value={fmt(k.requests)} note="Samplers HTTP" />
          <Kpi label="Tasa de error" value={k.errorRate} unit="%" note={k.errorRate > thresholds.errorRate ? '✕ Supera el 1%' : '✓ Bajo el 1%'} tone={k.errorRate > thresholds.errorRate ? 'fail' : 'ok'} />
          <Kpi label="Respuesta media" value={fmt(k.avgMs)} unit="ms" note={k.avgMs > thresholds.avgMs ? '✕ Supera 1 s' : '✓ Bajo 1 s'} tone={k.avgMs > thresholds.avgMs ? 'fail' : 'ok'} />
          <Kpi label="Throughput" value={k.throughput} unit="req/s" note="Peticiones por segundo" />
          <Kpi label="PHPUnit" value={`${k.unitPassed}/${k.unitTotal}`} note={unitOk ? '✓ Todas pasan' : `✕ ${k.unitTotal - k.unitPassed} fallidas`} tone={unitOk ? 'ok' : 'fail'} />
        </div>

        <div className="dash-grid">
          <div className="card panel">
            <div className="panel__head">
              <h3>Tiempo de respuesta</h3>
              <small>ms durante los 5 minutos de la prueba</small>
            </div>
            <ResponseChart data={s.timeline} />
          </div>
          <div className="card panel">
            <div className="panel__head">
              <h3>Respuesta media por flujo</h3>
              <small>Línea punteada: límite de {fmt(thresholds.avgMs)} ms</small>
            </div>
            <FlowBars flows={s.flows} />
          </div>
        </div>

        <div className="card panel">
          <div className="panel__head">
            <h3>Resultados por flujo (JMeter)</h3>
            <small>Assertion: código 200 y error menor al {thresholds.errorRate}%</small>
          </div>
          <FlowTable flows={s.flows} />
        </div>
      </div>
    </section>
  );
}
