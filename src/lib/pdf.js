import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url';
import { asset } from '../data/content';
let library;
export function loadPdfjs() {
  library ??= import('pdfjs-dist/build/pdf.mjs').then((pdfjs) => {
    pdfjs.GlobalWorkerOptions.workerSrc = workerUrl;
    return pdfjs;
  });
  return library;
}
export function pdfSource(src) {
  const local = (path) => new URL(asset(`vendor/pdfjs/${path}/`), window.location.href).href;
  return { url: src, standardFontDataUrl: local('standard_fonts'), cMapUrl: local('cmaps'), cMapPacked: true, wasmUrl: local('wasm') };
}
