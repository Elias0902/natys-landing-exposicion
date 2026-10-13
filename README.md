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

Todo está en `src/data/content.js`:

- **Dashboards**: pon la URL del hosting en `url` (y opcional `video` en `public/`).
- **Documentos**: copia el PDF a `public/docs/` y escribe la ruta en `file`. Los que tienen `file: ''` aparecen como *Pendiente* (guía, informe, mapa conceptual, presentación).
- **Guía**: puntos que expone cada integrante.
