# Frogdadday release checklist

Use this when one of the apps becomes publicly available on Google Play. The site is intentionally simple HTML; no account, tracking service, or content management system is needed.

1. **Confirm the actual public listing.** Verify that the Google Play link opens for ordinary users before advertising availability. Do not add a speculative download URL.
2. **Update the homepage card** in `index.html`: switch `<span class="status testing">In Testing</span>` (or `soon`) to `<span class="status available">Available Now</span>`. Add a visible, clearly named official Google Play link next to the app's existing "More about" link.
3. **Update that app's detail page** in `apps/*.html`: change the hero status, remove statements that the app is not yet available, and put the official Google Play link in a prominent place. Preserve its existing app explanation and honest permission/privacy statements. Check any described features against the shipped version.
4. **Check site-wide release wording.** In `index.html`, update the intro ("None is publicly available yet"), the release note, and the FAQ answer to "Where can I download them?" to reflect the actual first public app. Don't imply the other apps are available.
5. **Update discovery text** in `llms.txt` for the specific app's status and its official download destination. Keep the Frog Pond AI-agent participation policy unchanged. If relevant, update the app's description tags; do not claim any new permissions or privacy properties without checking the release.
6. **Validate the links** on both mobile and desktop. Check that the homepage, app detail page, Google Play destination, the Frog Pond, and existing verification files still work. Keep `sitemap.xml` listing the canonical app page; a Play link is not another site page and does not belong in this sitemap.
7. **Commit the release update** and confirm GitHub Pages has deployed. Search Console and Bing Webmaster Tools already have the sitemap; request re-indexing if useful, but it's not guaranteed or instant.

The `available` badge style is already defined in `styles.css`. Do not switch statuses automatically or before public release.
