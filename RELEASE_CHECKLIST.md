# Frogdadday release checklist

Use this when an app becomes publicly available through a verified direct APK or Google Play. See `APK_DISTRIBUTION.md` for the direct APK process. The site is intentionally simple HTML; no account, tracking service, or content management system is needed.

1. **Confirm the actual public listing.** Verify that the public APK release asset exists and downloads for an ordinary visitor, or that the Google Play link opens. Do not add speculative download URLs. Confirm withdrawn releases no longer appear, including when the API is unavailable.
2. **Update the homepage card** in `index.html`: the JavaScript release checker changes its badge to `APK Available` when a matching **live** public APK is discovered. The non-JavaScript fallback should prompt visitors to check availability, not incorrectly say Coming Soon. Add a separate official Google Play link when a Play listing exists. Review any remaining static status wording.
3. **Update that app's detail page** in `apps/*.html`: change the hero status and remove statements that the app is not yet available. The direct APK link is automatically shown for a matching website release. Put the official Google Play link in a prominent place when applicable. Preserve its existing app explanation and honest permission/privacy statements. Check any described features against the shipped version.
4. **Check site-wide release wording.** In `index.html`, check the release note and FAQ answer to "Where can I download them?" for accurate wording about public APK and Play availability. Don't imply the other apps are available.
5. **Update discovery text** in `llms.txt` for the specific app's status and its official release destinations (direct APK and/or Google Play). Keep the Frog Pond AI-agent participation policy unchanged. If relevant, update the app's description tags; do not claim any new permissions or privacy properties without checking the release.
6. **Validate the links** on both mobile and desktop. Check that the homepage, app detail page, Google Play destination, the Frog Pond, and existing verification files still work. Keep `sitemap.xml` listing the canonical app page; a Play link is not another site page and does not belong in this sitemap.
7. **Commit the release update** and confirm GitHub Pages has deployed. Search Console and Bing Webmaster Tools already have the sitemap; request re-indexing if useful, but it's not guaranteed or instant.

The `available` badge style is defined in `styles.css`. The download checker only changes it after detecting an actual published release asset; verification of the APK itself remains a separate pre-release task.

8. **Verify the exact published binary**: record its downloaded SHA-256, signing-certificate SHA-256, actual Android package/version, Play-signature compatibility and test result. This cannot be established by its release filename alone.
