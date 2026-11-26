import { cp, mkdir } from 'node:fs/promises';
const target = 'public/vendor/pdfjs';
await mkdir(target, { recursive: true });
await Promise.all(['standard_fonts', 'cmaps', 'wasm'].map((dir) => cp(`node_modules/pdfjs-dist/${dir}`, `${target}/${dir}`, { recursive: true })));
