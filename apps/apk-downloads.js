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
      const matchDigest = /^sha256:([0-9a-f]{64})$/i.exec(asset.digest || '');
      found[slug] = { numeric, version, url: expectedUrl, bytes: asset.size, digest: matchDigest ? matchDigest[1].toLowerCase() : null, publishedAt: release.published_at || null };
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
    panel.querySelector('.apk-fingerprint')?.remove();
    panel.querySelector('.apk-current-checksum')?.remove();
    panel.querySelector('.apk-availability')?.removeAttribute('data-ready');
    if (status) status.textContent = error ? 'Could not check downloads' : 'Public APK not available yet';
    if (detail) detail.textContent = error
      ? 'The public release check was unavailable. Refresh later.'
      : 'The download will appear when a public APK release is published.';
  }
  async function check() {
    try {
      // Require the current GitHub release listing, so withdrawn APKs disappear.
      const response = await fetch(api, { headers: { 'Accept': 'application/vnd.github+json' }, cache: 'no-store' });
      if (!response.ok) throw new Error('GitHub release API is unavailable');
      const data = await response.json();
      if (!Array.isArray(data)) throw new Error('Unexpected release API response');
      const releases = findApks(data);
      for (const panel of panels) {
        const release = releases[panel.dataset.apkSlug];
        if (!release) { noDownload(panel, false); continue; }
        const status = panel.querySelector('[data-apk-status]');
        const detail = panel.querySelector('[data-apk-detail]');
        const link = panel.querySelector('[data-apk-link]');
        const version = panel.querySelector('[data-apk-version]');
        if (status) status.textContent = 'v' + release.version + ' · APK available';
        if (detail) detail.textContent = 'Published in the official Frogdadday website releases.';
        if (link) { link.href = release.url; link.hidden = false; }
        if (version) {
          const publishedDate = release.publishedAt && !Number.isNaN(Date.parse(release.publishedAt))
            ? ' · Released ' + new Date(release.publishedAt).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' })
            : '';
          version.textContent = 'Version ' + release.version + publishedDate + ' · ' +
            (release.bytes / 1048576).toFixed(1) + ' MB';
          version.hidden = false;
        }
        panel.querySelector('.apk-availability')?.setAttribute('data-ready', 'true');
        // A published historical record must not be mistaken for the current download.
        const record = panel.querySelector('.apk-release-record');
        const recordMatches = record &&
          record.dataset.releaseTag === panel.dataset.apkSlug + '-v' + release.version &&
          release.digest && record.dataset.releaseDigest === release.digest;
        if (record) {
          record.classList.toggle('apk-record-older', !recordMatches);
          const heading = record.querySelector('h3');
          if (heading) heading.setAttribute('aria-label', recordMatches
            ? 'Details for currently listed APK release'
            : 'Historical APK record; compare the current release before downloading');
        }
        panel.querySelector('.apk-current-checksum')?.remove();
        if (release.digest && !recordMatches) {
          const current = document.createElement('p');
          current.className = 'apk-current-checksum';
          const title = document.createElement('strong');
          title.textContent = 'SHA-256 for currently listed v' + release.version + ': ';
          const value = document.createElement('code');
          value.textContent = release.digest;
          current.append(title, value);
          panel.querySelector('[data-apk-version]')?.insertAdjacentElement('afterend', current);
        }
        const heroStatus = panel.closest('.detail-main')?.querySelector('.detail-copy .eyebrow');
        if (heroStatus) heroStatus.textContent = 'Direct APK Available · Android';
      }
      let availableCount = 0;
      for (const card of cards) {
        const badge = card.querySelector('.status');
        if (releases[card.dataset.appRelease]) {
          availableCount++;
          if (badge) { badge.className = 'status available'; badge.textContent = 'v' + releases[card.dataset.appRelease].version + ' · APK available'; }
        } else if (badge) {
          badge.className = 'status status-check';
          badge.textContent = 'No public APK';
        }
      }
      const pageSummary = document.getElementById('apk-release-summary');
      if (pageSummary) pageSummary.textContent = availableCount + ' app' + (availableCount === 1 ? '' : 's') + ' with public APKs. Open a detail page for downloads and installation guidance. Google Play listings are separate.';
    } catch (_) {
      for (const panel of panels) noDownload(panel, true);
      const pageSummary = document.getElementById('apk-release-summary');
      if (pageSummary) pageSummary.textContent = 'Could not confirm APK availability right now. Check the app pages or official GitHub Releases.';
    }
  }
  check();
})();
