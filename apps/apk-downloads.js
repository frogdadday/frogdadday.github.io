/* Frogdadday public APK availability. One GitHub release check; no tracking. */
(() => {
  'use strict';
  const prefixes = Object.freeze({
    'cosmic-converter': 'Cosmic-Converter',
    'cosmic-spinner': 'Cosmic-Spinner',
    'cosmic-chores': 'Cosmic-Chores',
    'cosmic-dice': 'Cosmic-Dice',
    'cosmic-easy-phone': 'Cosmic-Easy-Phone',
    'frog-easy-camera': 'Frog-Easy-Camera',
    'frog-cleaner': 'Frog-Cleaner',
    'frog-secure-pw-keeper': 'Frog-Secure-PW-Keeper',
    'frog-construction-toolkit': 'Frog-Construction-Toolkit',
    'frog-file-viewer': 'Frog-File-Viewer'
  });
  const panels = [...document.querySelectorAll('[data-apk-slug]')];
  const cards = [...document.querySelectorAll('[data-app-release]')];
  if (!panels.length && !cards.length) return;

  const api = 'https://api.github.com/repos/frogdadday/frogdadday.github.io/releases?per_page=100';
  const root = 'https://github.com/frogdadday/frogdadday.github.io/releases/download/';
  const pattern = /^([a-z0-9]+(?:-[a-z0-9]+)*)-v(\d+)\.(\d+)\.(\d+)$/i;
  function newer(a, b) {
    if (!b) return true;
    for (let i = 0; i < 3; i++) {
      if (a[i] !== b[i]) return a[i] > b[i];
    }
    return false;
  }
  function findApks(releases) {
    const found = Object.create(null);
    for (const release of releases) {
      if (!release || release.draft || release.prerelease ||
          typeof release.tag_name !== 'string' || !Array.isArray(release.assets)) continue;
      const match = pattern.exec(release.tag_name);
      if (!match) continue;
      const slug = match[1].toLowerCase();
      if (!Object.prototype.hasOwnProperty.call(prefixes, slug)) continue;
      const numeric = match.slice(2).map(Number);
      if (numeric.some(x => !Number.isSafeInteger(x))) continue;
      const version = numeric.join('.');
      const filename = prefixes[slug] + '-v' + version + '.apk';
      const expectedUrl = root + release.tag_name + '/' + filename;
      const asset = release.assets.find(a =>
        a.name === filename && a.state === 'uploaded' &&
        Number.isFinite(a.size) && a.size > 0 &&
        a.browser_download_url === expectedUrl);
      if (!asset || !newer(numeric, found[slug]?.numeric)) continue;
      found[slug] = { numeric, version, url: expectedUrl, bytes: asset.size };
    }
    return found;
  }
  function noDownload(panel, error) {
    const status = panel.querySelector('[data-apk-status]');
    const detail = panel.querySelector('[data-apk-detail]');
    const link = panel.querySelector('[data-apk-link]');
    const version = panel.querySelector('[data-apk-version]');
    if (link) link.hidden = true;
    if (version) version.hidden = true;
    if (status) status.textContent = error ? 'Could not check downloads' : 'Public APK not available yet';
    if (detail) detail.textContent = error
      ? 'The public release check was unavailable. Refresh later.'
      : 'The download will appear when a public APK release is published.';
  }
  async function check() {
    try {
      const r = await fetch(api, { headers: { 'Accept': 'application/vnd.github+json' } });
      if (!r.ok) throw new Error('Release API unavailable');
      const data = await r.json();
      if (!Array.isArray(data)) throw new Error('Unexpected release data');
      const releases = findApks(data);
      for (const panel of panels) {
        const release = releases[panel.dataset.apkSlug];
        if (!release) { noDownload(panel, false); continue; }
        const status = panel.querySelector('[data-apk-status]');
        const detail = panel.querySelector('[data-apk-detail]');
        const link = panel.querySelector('[data-apk-link]');
        const version = panel.querySelector('[data-apk-version]');
        if (status) status.textContent = 'Direct APK available';
        if (detail) detail.textContent = 'Published in the official Frogdadday website releases.';
        if (link) { link.href = release.url; link.hidden = false; }
        if (version) {
          version.textContent = 'Version ' + release.version + ' · APK · ' +
            (release.bytes / 1048576).toFixed(1) + ' MB';
          version.hidden = false;
        }
        panel.querySelector('.apk-availability')?.setAttribute('data-ready', 'true');
        const heroStatus = panel.closest('.detail-main')?.querySelector('.detail-copy .eyebrow');
        if (heroStatus) heroStatus.textContent = 'Direct APK Available · Android';
      }
      for (const card of cards) {
        if (!releases[card.dataset.appRelease]) continue;
        const badge = card.querySelector('.status');
        if (badge) { badge.className = 'status available'; badge.textContent = 'APK Available'; }
      }
    } catch (_) {
      for (const panel of panels) noDownload(panel, true);
    }
  }
  check();
})();
