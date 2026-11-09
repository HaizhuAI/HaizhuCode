# Releasing HaizhuCode

**One change = one version = one published APK.** Starting with `v1.0.0+1`,
every change that lands on `main` gets its own version, its own tag, and a
GitHub release carrying the signed `HaizhuCode-release.apk`.

**一次修改 = 一个版本 = 一个已发布的 APK。** 自 `v1.0.0+1` 起，合入 `main`
的每次变更都有独立版本号、独立 tag，并在 GitHub Release 上附带签名后的
`HaizhuCode-release.apk`。

## Versioning / 版本号

`pubspec.yaml` carries `version: x.y.z+N`:

- bump the **patch** (`z`) for fixes and small changes, **minor** (`y`) for
  features, **major** (`x`) for breaking changes;
- always bump the **build number** `+N` — Android and Obtainium compare it.

Tag format: `v<x.y.z+N>` (matches the pubspec line exactly, e.g. `v1.0.0+1`).

## Release checklist / 发版清单

1. Write the release notes: `docs/releases/v<x.y.z+N>.md`
   (see `docs/releases/TEMPLATE.md`).
2. Bump `version:` in `pubspec.yaml`, or let the script do it.
3. Release it — either way produces the same result:

   **Local (one command) / 本地一键**

   ```bash
   python tool/haizhu_release.py            # bump patch, build, tag, publish
   python tool/haizhu_release.py --bump minor
   python tool/haizhu_release.py --no-build # reuse the APK already in build/
   ```

   The script verifies the APK's signer fingerprint against the public
   upgrade lineage (`24CE74B6…C6D19`), tags `v<x.y.z+N>`, pushes it, then
   creates/updates the GitHub release and uploads
   `HaizhuCode-release.apk`. The tag push triggers the workflow below, which
   re-verifies and republishes the same asset.

   **CI / 云端**

   Push the tag yourself — `.github/workflows/haizhu-release.yml` builds
   `flutter build apk --release`, verifies the signer fingerprint and the
   pubspec↔tag version match, then creates or updates the GitHub release and
   uploads `HaizhuCode-release.apk` (release notes come from
   `docs/releases/<tag>.md`).

   ```bash
   git tag -a v1.0.1+2 -m "HaizhuCode 1.0.1+2" && git push haizhu v1.0.1+2
   ```

## Signing lineage / 签名谱系

Releases are signed with the HaizhuCode sideload key, SHA-256 fingerprint

```
24:CE:74:B6:1F:29:34:02:F9:84:83:AF:BA:77:45:CC:95:F5:E3:D5:38:DE:EA:2D:F8:DE:B5:AE:A9:1C:6D:19
```

Android only updates in place over an APK with the same signature — every
release must keep this lineage. The keystore lives outside the repo; CI
rebuilds it from the `HZ_KEYSTORE_*` repository secrets. A run without the
secret fails closed instead of shipping a differently-signed APK.
