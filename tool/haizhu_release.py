#!/usr/bin/env python3
"""HaizhuCode one-command release: bump, build, tag, publish.

Every change is a release. Run from the repo root:

    python tool/haizhu_release.py [--bump patch|minor|major|none]
                                  [--no-build] [--notes <file>]

What it does, in order:
  1. Optionally bumps `version:` in pubspec.yaml (x.y.z+N -> next).
  2. Builds the signed release APK (skippable to reuse build/ output).
  3. Verifies the signer fingerprint matches the public upgrade lineage.
  4. Tags v<x.y.z+N>, pushes the tag, then creates or updates the GitHub
     release and uploads HaizhuCode-release.apk to it.

Auth: reads a github.com token from `git credential fill` or GITHUB_TOKEN.
Remote: the `haizhu` remote (HaizhuAI/HaizhuCode) by default.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import urllib.request
import urllib.error

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBSPEC = os.path.join(REPO_ROOT, "pubspec.yaml")
APK_OUT = os.path.join(
    REPO_ROOT, "build", "app", "outputs", "flutter-apk", "app-release.apk"
)
ASSET_NAME = "HaizhuCode-release.apk"
LINEAGE_SHA256 = (
    "24CE74B61F293402F98483AFBA7745CC95F5E3D538DEEA2DF8DEB5AEA91C6D19"
)
DEFAULT_REMOTE = "haizhu"


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=REPO_ROOT, text=True, **kw)


def pubspec_version() -> tuple[str, int]:
    text = open(PUBSPEC, encoding="utf-8").read()
    m = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)", text, re.M)
    if not m:
        sys.exit("pubspec.yaml: no x.y.z+N version line found")
    return ".".join(m.group(i) for i in (1, 2, 3)), int(m.group(4))


def bump_version(part: str) -> None:
    name, code = pubspec_version()
    major, minor, patch = (int(x) for x in name.split("."))
    if part == "major":
        major, minor, patch = major + 1, 0, 0
    elif part == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    new = f"{major}.{minor}.{patch}+{code + 1}"
    text = open(PUBSPEC, encoding="utf-8").read()
    text = re.sub(r"^version:.*$", f"version: {new}", text, count=1, flags=re.M)
    open(PUBSPEC, "w", encoding="utf-8").write(text)
    print(f"version -> {new}")


def build_apk() -> None:
    env = dict(os.environ)
    env.setdefault("GRADLE_USER_HOME", r"D:\Devin\gradle-home")
    r = subprocess.run(
        ["flutter", "build", "apk", "--release"], cwd=REPO_ROOT, env=env
    )
    if r.returncode:
        sys.exit("flutter build apk --release failed")


def repo_slug(remote: str) -> str:
    url = run(
        ["git", "remote", "get-url", remote], capture_output=True
    ).stdout.strip()
    m = re.search(r"github\.com[:/]([^/]+/[^/.]+)", url)
    if not m:
        sys.exit(f"remote '{remote}' is not a github.com URL: {url}")
    return m.group(1)


def github_token() -> str:
    tok = os.environ.get("GITHUB_TOKEN", "").strip()
    if tok:
        return tok
    r = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        capture_output=True,
        text=True,
    )
    m = re.search(r"^password=(.+)$", r.stdout, re.M)
    if not m:
        sys.exit("no github credential: set GITHUB_TOKEN or credential.helper")
    return m.group(1).strip()


def api(slug: str, token: str, method: str, path: str,
        body: dict | None = None, raw: bytes | None = None,
        ctype: str = "application/json") -> dict:
    url = f"https://api.github.com/repos/{slug}{path}"
    data = raw if raw is not None else (
        json.dumps(body).encode() if body is not None else None
    )
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": f"token {token}",
                 "Accept": "application/vnd.github+json",
                 "Content-Type": ctype},
    )
    try:
        return json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return {}
        raise


def signer_sha256(apk: str) -> str:
    import zipfile
    # The cert fingerprint Gradle printed; apksigner is not on PATH here, so
    # ask keytool to parse the APK signing block via jarsigner instead.
    r = subprocess.run(
        ["keytool", "-list", "-printcert", "-jarfile", apk],
        capture_output=True, text=True,
    )
    m = re.search(r"SHA256:\s*([0-9A-F:]+)", r.stdout + r.stderr)
    if not m:
        sys.exit("could not read APK signer certificate")
    return m.group(1).replace(":", "").upper()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bump", choices=["patch", "minor", "major", "none"],
                    default="patch")
    ap.add_argument("--no-build", action="store_true",
                    help="reuse build/.../app-release.apk instead of rebuilding")
    ap.add_argument("--notes", help="release notes markdown file "
                                   "(default docs/releases/<tag>.md when present)")
    ap.add_argument("--remote", default=DEFAULT_REMOTE)
    args = ap.parse_args()

    if args.bump != "none":
        bump_version(args.bump)
    name, code = pubspec_version()
    tag = f"v{name}+{code}"
    version = f"{name}+{code}"
    print(f"releasing {tag}")

    if not args.no_build:
        build_apk()
    if not os.path.isfile(APK_OUT):
        sys.exit(f"missing {APK_OUT}")
    fp = signer_sha256(APK_OUT)
    if fp != LINEAGE_SHA256:
        sys.exit(f"signer {fp} != lineage {LINEAGE_SHA256}")

    r = run(["git", "rev-parse", "--verify", tag], capture_output=True)
    if r.returncode:
        run(["git", "tag", "-a", tag, "-m", f"HaizhuCode {version}"], check=True)
    run(["git", "push", args.remote, tag], check=True)

    slug = repo_slug(args.remote)
    token = github_token()
    notes_path = args.notes or os.path.join(
        REPO_ROOT, "docs", "releases", f"{tag}.md"
    )
    body = ""
    if os.path.isfile(notes_path):
        body = open(notes_path, encoding="utf-8").read()

    rel = api(slug, token, "GET", f"/releases/tags/{tag}")
    if not rel:
        rel = api(slug, token, "POST", "/releases", body={
            "tag_name": tag,
            "name": f"HaizhuCode {name}",
            "body": body,
            "draft": False,
            "prerelease": False,
        })
        print("created", rel.get("html_url"))
    else:
        api(slug, token, "PATCH", f"/releases/{rel['id']}",
            body={"body": body} if body else {})
        print("updated", rel.get("html_url"))

    for a in api(slug, token, "GET", f"/releases/{rel['id']}/assets") or []:
        if a.get("name") == ASSET_NAME:
            api(slug, token, "DELETE", f"/releases/assets/{a['id']}")

    upload = rel["upload_url"].split("{")[0] + f"?name={ASSET_NAME}"
    req = urllib.request.Request(
        upload, data=open(APK_OUT, "rb").read(), method="POST",
        headers={"Authorization": f"token {token}",
                 "Content-Type": "application/vnd.android.package-archive"},
    )
    asset = json.load(urllib.request.urlopen(req))
    print("asset:", asset["browser_download_url"])


if __name__ == "__main__":
    main()
