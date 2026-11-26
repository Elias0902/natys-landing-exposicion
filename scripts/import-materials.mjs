import { readdir, readFile, writeFile, mkdir, copyFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';

// Importa los originales sin modificar su contenido. Las carpetas de origen
// son versiones distintas: se conservan ambas y se identifican en el catálogo.
const source = path.resolve(process.argv[2] || '');
if (!process.argv[2]) throw new Error('Indica la carpeta de materiales como argumento.');
const root = process.cwd();
const slug = (value) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9.]+/g, '-').replace(/^-|-$/g, '');
const records = [];
async function walk(dir, parts = []) {
  const entries = await readdir(dir, { withFileTypes: true });
  entries.sort((a, b) => a.name.localeCompare(b.name, 'es'));
  for (const entry of entries) {
    const next = [...parts, entry.name];
    const original = path.join(dir, entry.name);
    if (entry.isDirectory()) { await walk(original, next); continue; }
    const ext = path.extname(entry.name).slice(1).toLowerCase();
    const file = ['docs', 'materiales', ...next.map(slug)].join('/');
    await mkdir(path.dirname(path.join(root, 'public', file)), { recursive: true });
    await copyFile(original, path.join(root, 'public', file));
    const database = /bases de datos/i.test(next[0]);
    const test = /pruebas|trazabilidad/i.test(entry.name);
    const category = database ? 'base-datos' : test ? 'pruebas' : 'ingenieria';
    const group = parts.length > 1 ? parts.slice(1).join(' / ') : database ? 'Paquetes completos' : test ? 'Planificación e informes' : 'Requisitos y diseño';
    const title = entry.name.replace(/\.(docx|pdf|drawio|rar|zip|sql|png|svg)$/i, '').replace(/[_]+/g, ' ').replace(/ \(1\)$/, '');
    records.push({ id: `material-${records.length + 1}`, title, category, group, format: ext.toUpperCase(), file, size: (await stat(original)).size, original: next.join(' / '), version: next[0] === '03 - Bases de Datos' ? 'Carpeta 03 · versión alternativa' : database ? 'Carpeta Bases de Datos' : '', sha256: createHash('sha256').update(await readFile(original)).digest('hex') });
  }
}
await walk(source);
await writeFile(path.join(root, 'src/data/materials.json'), JSON.stringify(records, null, 2) + '\n');
console.log(`Importados ${records.length} archivos originales.`);
