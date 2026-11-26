import { cp, mkdir, readFile, writeFile, access } from 'node:fs/promises';
const target = 'public/vendor/pdfjs';
const directories = ['standard_fonts', 'cmaps', 'wasm'];
const { version } = JSON.parse(await readFile('node_modules/pdfjs-dist/package.json', 'utf8'));
try {
  if (await readFile(`${target}/.version`, 'utf8') === version) {
    await Promise.all(directories.map((dir) => access(`${target}/${dir}`)));
    process.exit(0);
  }
} catch { /* Primera preparación o una versión nueva de PDF.js. */ }
await mkdir(target, { recursive: true });
await Promise.all(directories.map((dir) => cp(`node_modules/pdfjs-dist/${dir}`, `${target}/${dir}`, { recursive: true })));
await writeFile(`${target}/.version`, version);
