import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import JSZip from 'jszip';
import { createExtractorFromData } from 'node-unrar-js';

const materials = JSON.parse(await readFile('src/data/materials.json', 'utf8'));
const known = new Map(materials.map((file) => [file.sha256, file.file]));
const catalog = {};
for (const archive of materials.filter((f) => ['RAR', 'ZIP'].includes(f.format))) {
  const bytes = await readFile(path.join('public', archive.file));
  let entries;
  if (archive.format === 'ZIP') {
    const zip = await JSZip.loadAsync(bytes);
    entries = await Promise.all(Object.values(zip.files).filter((f) => !f.dir).map(async (f) => ({ name: f.name, bytes: await f.async('nodebuffer') })));
  } else {
    const extractor = await createExtractorFromData({ data: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) });
    entries = [...extractor.extract().files].filter((f) => !f.fileHeader.flags.directory).map((f) => ({ name: f.fileHeader.name, bytes: Buffer.from(f.extraction) }));
  }
  catalog[archive.file] = [];
  for (const entry of entries) {
    const format = path.extname(entry.name).slice(1).toUpperCase();
    const digest = createHash('sha256').update(entry.bytes).digest('hex');
    let file = known.get(digest);
    if (!file) {
      // Content-addressed names keep archive paths out of filesystem writes.
      file = `docs/archive-previews/${digest}.${format.toLowerCase().replace(/[^a-z0-9]/g, '') || 'bin'}`;
      await mkdir(path.dirname(path.join('public', file)), { recursive: true });
      await writeFile(path.join('public', file), entry.bytes);
      known.set(digest, file);
    }
    catalog[archive.file].push({ title: path.basename(entry.name.replaceAll('\\', '/')), original: entry.name, format, file, size: entry.bytes.length });
  }
  console.log(`${archive.title}: ${catalog[archive.file].length} archivos disponibles dentro del visor.`);
}
await writeFile('src/data/archiveContents.json', JSON.stringify(catalog, null, 2) + '\n');
