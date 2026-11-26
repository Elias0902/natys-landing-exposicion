export const previewType = (file) => ({
  PDF: 'pdf', DOCX: 'docx', DRAWIO: 'drawio', PNG: 'image', JPG: 'image', JPEG: 'image', SVG: 'image',
  SQL: 'text', TXT: 'text', XML: 'text', JSON: 'text', PHP: 'text', PY: 'text', JS: 'text', ZIP: 'archive', RAR: 'archive',
})[file.format] || 'download';

export const previewDocument = (file) => ({ ...file, type: previewType(file) });
