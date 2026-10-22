# Frogdadday website

Live site: **https://frogdadday.com/**

This is the public, static GitHub Pages website of Frogdadday, an independent developer of free Android applications. The website's source is public; each app's source repository and signing materials remain private.

## Current state

- Ten app information pages; Frog File Viewer is still in development.
- Nine apps have published direct APK assets in the website repository's GitHub Releases.
- App download sections and homepage badges check the **current GitHub public Releases API** in `apps/apk-downloads.js`. There is deliberately **no stale offline download list**: if the API fails, release availability is unknown and the button stays hidden.
- Published GitHub SHA-256 asset digests, where available, appear on app pages as a downloadable-file integrity check. **This is not proof of valid Android signing or app security.**
- Frog Pond comments run through the separately managed Garrul Cloudflare Worker.
- GitHub Pages custom domain: `frogdadday.com`, HTTPS, crawler metadata and sitemap.

## Local preview

```powershell
python -m http.server 4173
```

Then open http://localhost:4173. Network restrictions may prevent the preview from checking GitHub Releases.

## Launcher images

The original PNG launcher icons remain in `assets/` and are not redrawn, replaced, or AI-generated. `scripts/optimize_site_icons.py` creates smaller WebP display derivatives from those same icons and can update HTML `img` elements without modifying original PNGs, page metadata, or app binaries. See `IMAGE_OPTIMIZATION.md`.

## Publishing and QA

See `APK_DISTRIBUTION.md` and `RELEASE_CHECKLIST.md`. A public GitHub Release confirms the file is listed and downloadable; it does not establish APK signing, installability, security review, or compatibility with Play Store installations. Check and document these before promoting any APK publicly.
