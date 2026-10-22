/* Frogdadday static-site download check. No accounts, cookies, or telemetry. */
(() => {
  'use strict';
  const status = document.getElementById('camera-download-status');
  const detail = document.getElementById('camera-download-detail');
  const link = document.getElementById('camera-download-link');
  const version = document.getElementById('camera-download-version');
  if (!status || !detail || !link || !version) return;

  // This public site repository hosts release assets; the app source stays private.
  const endpoint = 'https://api.github.com/repos/frogdadday/frogdadday.github.io/releases?per_page=100';
  const expectedPrefix = 'https://github.com/frogdadday/frogdadday.github.io/releases/download/';
  const versionTag = /^frog-easy-camera-v(\\d+)\\.(\\d+)\\.(\\d+)$/i;

  async function checkForPublicApk() {
    try {
      const response = await fetch(endpoint, {
        headers: { 'Accept': 'application/vnd.github+json' }
      });
      if (!response.ok) throw new Error('Release check unavailable');
      const releases = await response.json();
      if (!Array.isArray(releases)) throw new Error('Invalid release response');

      const available = [];
      for (const release of releases) {
        if (release.draft || release.prerelease || typeof release.tag_name !== 'string') continue;
        const match = versionTag.exec(release.tag_name);
        if (!match || !Array.isArray(release.assets)) continue;
        const filename = 'Frog-Easy-Camera-v' + match.slice(1).join('.') + '.apk';
        const asset = release.assets.find((item) =>
          item.name === filename &&
          item.state === 'uploaded' &&
          item.size > 0 &&
          typeof item.browser_download_url === 'string' &&
          item.browser_download_url.startsWith(expectedPrefix)
        );
        if (asset) available.push({ tag: match.slice(1).map(Number), filename, asset });
      }
      available.sort((a, b) => {
        for (let i = 0; i < 3; i++) {
          if (a.tag[i] !== b.tag[i]) return b.tag[i] - a.tag[i];
        }
        return 0;
      });
      const chosen = available[0];
      if (!chosen) {
        status.textContent = 'Public APK not available yet';
        detail.textContent = 'The app is still in testing. A verified release will appear here once published.';
        return;
      }
      link.href = chosen.asset.browser_download_url;
      link.textContent = 'Download Frog Easy Camera ↓';
      link.hidden = false;
      version.textContent = 'Available version: ' + chosen.tag.join('.') + ' · APK · ' +
        (chosen.asset.size / 1048576).toFixed(1) + ' MB';
      version.hidden = false;
      status.textContent = 'Direct download available';
      detail.textContent = 'This file is published in the official Frogdadday website releases.';
      status.closest('.apk-availability')?.setAttribute('data-ready', 'true');
    } catch (_) {
      status.textContent = 'Could not check download status';
      detail.textContent = 'The release service is temporarily unavailable. Please try again later.';
    }
  }

  checkForPublicApk();
})();
