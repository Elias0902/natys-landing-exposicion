# Natys · Equipo 8 — Repositorio del proyecto

Repositorio en React + Vite con carpetas de pruebas, ingeniería, base de datos y programación de pruebas. Los materiales se muestran en tarjetas con vistas previas, búsqueda, filtros y descarga del original. El menú lateral se puede plegar y recuerda la preferencia.

Los diagramas Draw.io se renderizan dentro de la página con el visor oficial servido localmente: ajuste, zoom, desplazamiento y selección de páginas. Los PDF, Word, imágenes y SQL también tienen vista interna. Los ZIP/RAR muestran su contenido y permiten abrir los documentos sin salir de la landing. La exposición anterior, QR, evaluación, Ismael y simulador se conservan en el apartado secundario «Archivo de la exposición».

## Uso local

```bash
npm ci
npm run dev
```

## Publicar en GitHub Pages

1. Sube el repositorio a GitHub (rama `main`).
2. En **Settings › Pages**, elige **Source: GitHub Actions**.
3. Cada push a `main` publica la landing automáticamente (`.github/workflows/deploy.yml`).

## Materiales y vistas previas

`src/data/materials.json` cataloga los originales de `public/docs/materiales/`. Para incorporar otra carpeta de materiales:

```bash
node scripts/import-materials.mjs "RUTA_A_LA_CARPETA"
npm run prepare:archives
```

La importación conserva los originales y sus hashes. Las dos carpetas de base de datos se identifican por separado; el filtro de versiones permite consultar la alternativa. `prepare:archives` genera el índice de los paquetes y reutiliza los originales idénticos por su hash. Hay que ejecutarlo de nuevo si cambia un ZIP/RAR.

El visor Draw.io y su licencia están en `public/vendor/drawio/`. Los recursos PDF se copian desde la dependencia instalada al ejecutar `dev` o `build`; no se necesita un CDN para los visores. Las rutas relativas permiten cambiar el nombre del repositorio.

```bash
npm run test:previews
npm run build
```

Las pruebas verifican los diagramas reales y sus páginas con el renderer local en un DOM de prueba, el puente y zoom del visor, la integridad de los archivos de los paquetes, la galería, los filtros, el visor interno y el menú plegable. No sustituyen la revisión visual en un navegador.

El contenido de la exposición archivada se conserva en `src/LegacyPresentation.jsx` y `src/data/content.js`.

## Agregar un informe de pruebas

1. Copia el PDF a `public/docs/pruebas/`. Si tienes el archivo Word, guárdalo en la misma carpeta. La miniatura opcional va en `public/img/pruebas/`.
2. En `src/data/pruebas.js`, busca la tarjeta del módulo existente y añade sus rutas en `pdf`, `docx` y `thumb`, sin el prefijo `public/`. Las tarjetas de Edmairys tienen los identificadores `clientes`, `proveedores` y `categorias`.
3. Abre `#/pruebas` y selecciona el filtro de la persona para comprobar el informe. Los Word se muestran dentro del visor como las demás pruebas y también ofrecen descarga.
