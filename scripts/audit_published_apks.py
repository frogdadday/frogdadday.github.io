#!/usr/bin/env python3
"""Audit live Frogdadday releases. Read-only; requires Android SDK build-tools."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.request import Request, urlopen

REPO = "frogdadday/frogdadday.github.io"
ROOT = "https://github.com/" + REPO + "/releases/download/"
API = "https://api.github.com/repos/" + REPO + "/releases?per_page=100"
EXPECTED = {
    "cosmic-converter": ("Cosmic-Converter", "com.frogdadday.cosmicconverter"),
    "cosmic-spinner": ("Cosmic-Spinner", "com.seanjohnston.sean_johnston"),
    "cosmic-chores": ("Cosmic-Chores", "com.frogdadday.cosmicchores"),
    "cosmic-dice": ("Cosmic-Dice", "com.frogdadday.cosmicdice"),
    "cosmic-easy-phone": ("Cosmic-Easy-Phone", "com.frogdadday.android_toolkit"),
    "frog-easy-camera": ("Frog-Easy-Camera", "com.frogdadday.easy_camera"),
    "frog-cleaner": ("Frog-Cleaner", "com.frogdadday.frog_cleaner"),
    "frog-secure-pw-keeper": ("Frog-Secure-PW-Keeper", "app.grounded.password"),
    "frog-construction-toolkit": ("Frog-Construction-Toolkit", "com.frogconstruction.frog_construction_toolkit"),
}
TAG = re.compile(r"^([a-z0-9]+(?:-[a-z0-9]+)*)-v(\d+\.\d+\.\d+)$", re.I)
BADGING = re.compile(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'")
CERT = re.compile(r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F:]+)")
DIGEST = re.compile(r"sha256:([0-9a-fA-F]{64})")

def sdk():
    root = Path(os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or "/opt/android-sdk")
    for directory in sorted((root / "build-tools").glob("*"), reverse=True):
        aapt = directory / "aapt"
        apksigner = directory / "apksigner"
        if aapt.is_file() and apksigner.is_file():
            return str(aapt), str(apksigner)
    raise RuntimeError("Android SDK aapt/apksigner tools unavailable")

def cmd(args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=180)
    if result.returncode:
        raise RuntimeError(f"{Path(args[0]).name} failed: {(result.stdout+result.stderr)[-700:]}")
    return result.stdout + result.stderr

def releases():
    h = {"Accept": "application/vnd.github+json", "User-Agent": "Frogdadday-audit"}
    if os.environ.get("GITHUB_TOKEN"):
        h["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    with urlopen(Request(API, headers=h), timeout=90) as response:
        return json.load(response)

def audit_one(release, asset, app, version, package_id, path, aapt, signer):
    url = ROOT + release["tag_name"] + "/" + asset["name"]
    if asset.get("browser_download_url") != url:
        raise RuntimeError("Unexpected APK download URL")
    published = DIGEST.fullmatch(asset.get("digest") or "")
    if not published:
        raise RuntimeError("GitHub asset digest is unavailable")
    checksum = hashlib.sha256()
    with urlopen(Request(url, headers={"User-Agent": "Frogdadday-audit"}), timeout=180) as response:
        with path.open("wb") as output:
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                checksum.update(block)
                output.write(block)
    calculated = checksum.hexdigest()
    if path.stat().st_size != asset.get("size") or calculated != published.group(1).lower():
        raise RuntimeError("Downloaded size or SHA-256 disagrees with GitHub metadata")
    scope = "full range supported by runner"
    try:
        verification = cmd([signer, "verify", "--verbose", "--print-certs", str(path)])
    except RuntimeError as error:
        # API 37's experimental v3.2 hybrid ML-DSA key is not available
        # in every runner's JDK security provider. Verify API <= 36,
        # and explicitly disclose that the API 37 signer was not checked.
        if "v3.2" not in str(error) or "ML-DSA" not in str(error):
            raise
        verification = cmd([signer, "verify", "--verbose", "--print-certs", "--max-sdk-version", "36", str(path)])
        scope = "Android API <= 36 only; API 37 hybrid ML-DSA not evaluated"
    # Different apksigner versions prefix the signer line differently.
    cert = re.search(r"certificate SHA-256 digest:\s*([0-9a-fA-F:]+)", verification, re.I)
    if not cert:
        raise RuntimeError("Signature certificate SHA-256 digest missing: " + verification[:900])
    if re.search(r"certificate DN:.*Android Debug", verification, re.I):
        raise RuntimeError("Android debug signing certificate detected")
    package_text = cmd([aapt, "dump", "badging", str(path)])
    pkg = BADGING.search(package_text)
    if not pkg:
        raise RuntimeError("Cannot read package ID and versions")
    if pkg.group(1) != package_id:
        raise RuntimeError(f"Package ID {pkg.group(1)} does not match expected {package_id}")
    if pkg.group(3) != version:
        raise RuntimeError(f"APK version {pkg.group(3)} differs from GitHub release {version}")
    return {
        "app": app, "release": release["tag_name"], "file": asset["name"],
        "bytes": path.stat().st_size, "file_sha256": calculated,
        "signer_certificate_sha256": cert.group(1).replace(":", "").lower(),
        "package_id": pkg.group(1), "version_code": pkg.group(2),
        "version_name": pkg.group(3), "android_apk_signature": "valid", "verification_sdk_scope": scope,
        "github_asset_digest": "matches",
        "google_play_signing_compatibility": "not checked",
        "real_device_testing": "not checked"
    }

def main():
    report = {"scope": "Public APK signature, hash, package and version audit", "verified": [], "errors": []}
    try:
        aapt, signer = sdk()
        found = set()
        with tempfile.TemporaryDirectory() as folder:
            for release in releases():
                if release.get("draft") or release.get("prerelease"):
                    continue
                match = TAG.fullmatch(release.get("tag_name", ""))
                if not match or match.group(1) not in EXPECTED:
                    continue
                slug, version = match.groups()
                prefix, package_id = EXPECTED[slug]
                filename = f"{prefix}-v{version}.apk"
                assets = [a for a in release.get("assets", []) if a.get("name") == filename and a.get("state") == "uploaded"]
                if not assets:
                    report["errors"].append({"release": release["tag_name"], "problem": "No matching public APK asset"})
                    continue
                found.add(slug)
                target = Path(folder) / filename
                try:
                    info = audit_one(release, assets[0], slug, version, package_id, target, aapt, signer)
                    report["verified"].append(info)
                    print("PASS", slug, version, info["signer_certificate_sha256"])
                except Exception as exc:
                    report["errors"].append({"release": release["tag_name"], "problem": str(exc)})
                    print("FAIL", release["tag_name"], str(exc), file=sys.stderr)
                finally:
                    target.unlink(missing_ok=True)
        for slug in EXPECTED.keys() - found:
            report["errors"].append({"release": slug, "problem": "Matching public APK release missing"})
    except Exception as exc:
        report["errors"].append({"release": "audit_setup", "problem": str(exc)})
    Path("apk-release-audit.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Audit results: {len(report['verified'])} valid, {len(report['errors'])} flagged")
    return 1 if report["errors"] else 0

if __name__ == "__main__":
    sys.exit(main())
