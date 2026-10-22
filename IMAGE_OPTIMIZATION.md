# Frogdadday website image optimization

The website uses Frogdadday's **existing launcher art**. This workflow does not generate new artwork, recolor, stylize, or overwrite the original PNGs. The 10 app icons and frog logo remain in `assets/*.png` for full-resolution reference, Google/social previews and regeneration.

## What the script does

- `scripts/optimize_site_icons.py` reads each original PNG and creates a **lossless WebP presentation derivative** under `assets/optimized/`.
- The original artwork retains its source color and outline; the display derivative is resized to at most 512px for app icons and 768px for the larger website logo, with high-quality downsampling. If the derivative is larger than its original PNG, it is discarded.
- Only `<img src="...">` HTML references change to WebP, preserving existing alt text, classes and layout. Open Graph/Twitter social previews keep pointing to their original PNG files.
- No external image service, scripts in the user's browser, analytics, tracking or software subscriptions are required.

To regenerate locally:

```powershell
python -m pip install "Pillow>=11,<13"
python scripts/optimize_site_icons.py
```

When the optimizer workflow is available in the repository's Actions settings, it runs on image changes and can also be started manually. It commits generated WebP derivatives and updated HTML only when something actually changed.

**Release binaries and source application launchers are untouched.** Before promoting the site, compare the live hero, nav logo, 10 app cards, detail-page icons and Frog Pond for appearance and loading. The original PNGs remain easy to restore if required.
