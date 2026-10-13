// Dashboard metrics for each scenario. Replace these values with the real
// results exported from JMeter / PHPUnit / the pipeline run.

// Deterministic pseudo-random generator so the charts look the same on every load
function seeded(seed) {
  let s = seed;
  return () => {
    s = (s * 9301 + 49297) % 233280;
    return s / 233280;
  };
}

// Response time series (ms), one point every 5 seconds over a 5 minute run
function series(seed, baseMs, noiseMs, spikeFrom, spikeMs) {
  const rnd = seeded(seed);
  return Array.from({ length: 60 }, (_, i) => {
    const ramp = Math.min(1, (i + 1) / 12); // ramp-up of virtual users
    const spike = spikeFrom !== null && i >= spikeFrom ? spikeMs * Math.min(1, (i - spikeFrom + 1) / 8) : 0;
    return {
      t: `${Math.floor((i * 5) / 60)}:${String((i * 5) % 60).padStart(2, '0')}`,
      users: Math.round(100 * ramp),
      ms: Math.round(baseMs * (0.6 + 0.4 * ramp) + rnd() * noiseMs + spike * (0.8 + rnd() * 0.4)),
    };
  });
}

export const scenarios = [
  {
    id: 'fallando',
    label: 'Pruebas fallando',
    status: 'fail',
    summary: 'El pipeline se detuvo en la etapa de pruebas: no se despliega a producción.',
    commit: 'a3f9c21 · feat: nuevo flujo de pago',
    pipeline: [
      { stage: 'Commit', state: 'ok', time: '0s' },
      { stage: 'Build', state: 'ok', time: '42s' },
      { stage: 'Pruebas', state: 'fail', time: '3m 18s' },
      { stage: 'Despliegue', state: 'skip', time: '—' },
    ],
    kpis: {
      virtualUsers: 100,
      requests: 12480,
      errorRate: 18.4,
      avgMs: 1840,
      throughput: 41.6,
      unitPassed: 46,
      unitTotal: 52,
    },
    timeline: series(7, 420, 260, 24, 2600),
    flows: [
      { name: 'Login', avgMs: 380, p90: 610, samples: 3120, errors: 0.4 },
      { name: 'Catálogo', avgMs: 520, p90: 890, samples: 3120, errors: 1.2 },
      { name: 'Carrito', avgMs: 1460, p90: 2980, samples: 3120, errors: 9.8 },
      { name: 'Pago', avgMs: 5000, p90: 8420, samples: 3120, errors: 62.1 },
    ],
  },
  {
    id: 'funcionando',
    label: 'Pruebas funcionando',
    status: 'ok',
    summary: 'Todas las pruebas pasaron las puertas de calidad y la versión se publicó.',
    commit: 'b7e1d08 · fix: optimiza consulta de stock en pago',
    pipeline: [
      { stage: 'Commit', state: 'ok', time: '0s' },
      { stage: 'Build', state: 'ok', time: '40s' },
      { stage: 'Pruebas', state: 'ok', time: '2m 51s' },
      { stage: 'Despliegue', state: 'ok', time: '58s' },
    ],
    kpis: {
      virtualUsers: 100,
      requests: 14960,
      errorRate: 0,
      avgMs: 286,
      throughput: 49.9,
      unitPassed: 52,
      unitTotal: 52,
    },
    timeline: series(11, 260, 90, null, 0),
    flows: [
      { name: 'Login', avgMs: 190, p90: 310, samples: 3740, errors: 0 },
      { name: 'Catálogo', avgMs: 240, p90: 380, samples: 3740, errors: 0 },
      { name: 'Carrito', avgMs: 310, p90: 470, samples: 3740, errors: 0 },
      { name: 'Pago', avgMs: 404, p90: 620, samples: 3740, errors: 0 },
    ],
  },
];

// Quality gate thresholds used to flag each flow
export const thresholds = { avgMs: 1000, errorRate: 1 };
