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
  const api = 'https://api.github.com/repos/frogdadday/frogdadday.github.io/releases?per_page=100';
  const root = 'https://github.com/frogdadday/frogdadday.github.io/releases/download/';
  const verifiedReleases = Object.freeze([
    ['cosmic-converter-v1.0.4', 'Cosmic-Converter-v1.0.4.apk', 50718891],
    ['cosmic-spinner-v1.0.2', 'Cosmic-Spinner-v1.0.2.apk', 50098886],
    ['cosmic-chores-v0.1.0', 'Cosmic-Chores-v0.1.0.apk', 53834650],
    ['cosmic-dice-v1.0.0', 'Cosmic-Dice-v1.0.0.apk', 52886185],
    ['cosmic-easy-phone-v1.0.1', 'Cosmic-Easy-Phone-v1.0.1.apk', 53828116],
    ['frog-easy-camera-v1.0.1', 'Frog-Easy-Camera-v1.0.1.apk', 48356408],
    ['frog-cleaner-v1.0.1', 'Frog-Cleaner-v1.0.1.apk', 51583822],
    ['frog-secure-pw-keeper-v0.1.1', 'Frog-Secure-PW-Keeper-v0.1.1.apk', 1436094],
    ['frog-construction-toolkit-v1.0.0', 'Frog-Construction-Toolkit-v1.0.0.apk', 57229716]
  ].map(([tag, name, size]) => ({
    tag_name: tag,
    draft: false,
    prerelease: false,
    assets: [{
      name,
      state: 'uploaded',
      size,
      browser_download_url: root + tag + '/' + name
    }]
  })));
  const panels = [...document.querySelectorAll('[data-apk-slug]')];
  const cards = [...document.querySelectorAll('[data-app-release]')];
  if (!panels.length && !cards.length) return;
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
      let data = [];
      try {
        const r = await fetch(api, { headers: { 'Accept': 'application/vnd.github+json' } });
        if (r.ok) {
          const remote = await r.json();
          if (Array.isArray(remote)) data = remote;
        }
      } catch (_) {
        // Keep the verified public baseline available if GitHub's list API is delayed.
      }
      const releases = findApks(data.concat(verifiedReleases));
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
