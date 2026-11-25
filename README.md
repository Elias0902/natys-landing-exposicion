# Natys · Equipo 8 — Landing de la exposición

Landing en React + Vite: dashboard (menú desplegable), guía de la exposición y visor de documentos.

## Uso local

```bash
npm install
npm run dev
```

## Publicar en GitHub Pages

1. Sube el repositorio a GitHub (rama `main`).
2. En **Settings › Pages**, elige **Source: GitHub Actions**.
3. Cada push a `main` publica la landing automáticamente (`.github/workflows/deploy.yml`).

## Editar contenido

El contenido de la portada se edita en `src/data/content.js`:

- **Dashboards**: pon la URL del hosting en `url` (y opcional `video` en `public/`).
- **Documentos**: copia el PDF a `public/docs/` y escribe la ruta en `file`. Los que tienen `file: ''` aparecen como *Pendiente* (guía, informe, mapa conceptual, presentación).
- **Guía**: puntos que expone cada integrante.

## Agregar un informe de pruebas

1. Copia el PDF a `public/docs/pruebas/`. Si tienes el archivo Word, guárdalo en la misma carpeta. La miniatura opcional va en `public/img/pruebas/`.
2. En `src/data/pruebas.js`, busca la tarjeta del módulo existente y añade sus rutas en `pdf`, `docx` y `thumb`, sin el prefijo `public/`. Las tarjetas de Edmairys tienen los identificadores `clientes`, `proveedores` y `categorias`.
3. Abre `#/pruebas` y selecciona el filtro de la persona para comprobar el informe. Los Word se muestran dentro del visor como las demás pruebas y también ofrecen descarga.
