import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../state/download_size.dart';
import '../builtin_folders.dart';
import '../builtin_linux.dart';
import 'haizhu_bundle.dart';
import 'setup_contract.dart';

/// The HaizhuCode security payload as a phone setup component
/// ([SetupComponent.app]): the kernel prompt, skills, agent roles, the MCP
/// registry and the prompt library, wired into the OpenCode 2 server config
/// and every agent profile home by `hz seed`.
///
/// A script component cannot carry it: install scripts run as a single
/// `/bin/sh -c` argument inside Ubuntu, which is far smaller than the
/// payload. So the app decodes the embedded files into `/opt/haizhu`
/// itself — the rootfs is ordinary app storage ([BuiltinRootfsFolders]) —
/// and one short command inside Ubuntu puts `hz` on PATH and runs the
/// seeding. Writing the whole tree every run keeps the component
/// idempotent; the seeded agent config stays write-if-absent, so files a
/// user edited survive a reinstall.
class HaizhuSetupComponent implements SetupAppComponent {
  HaizhuSetupComponent({
    BuiltinLinux? linux,
    Future<Directory?> Function()? locate,
  }) : _linux = linux ?? BuiltinLinux(),
       _locate = locate ?? BuiltinRootfsFolders.locateRootfs;

  static HaizhuSetupComponent? _instance;

  /// The one the registry uses (components.dart).
  static HaizhuSetupComponent get instance =>
      _instance ??= HaizhuSetupComponent();

  @visibleForTesting
  static set instance(HaizhuSetupComponent? value) => _instance = value;

  final BuiltinLinux _linux;
  final Future<Directory?> Function() _locate;
  bool _cancelled = false;

  static const _kernel = 'kernel/universal-kernel-v31.md';

  @override
  Future<SetupAppOffer?> offer() async {
    if (!BuiltinLinux.supported) return null;
    final installed = (await check()).ok;
    return SetupAppOffer(
      // Nothing is fetched: the payload is inside the APK. For an installed
      // component this field is what removing it frees.
      downloadBytes: installed ? HaizhuBundle.totalBytes : 0,
      installed: installed,
      downloadSize: const DownloadSize.exact(0),
    );
  }

  /// Installed means the current payload is unpacked and wired: the kernel
  /// file and the `hz` PATH link are the two ends of that.
  @override
  Future<({bool ok, String? version})> check() async {
    final rootfs = await _locate();
    if (rootfs == null) return (ok: false, version: null);
    final base = '${rootfs.path}${HaizhuBundle.root}';
    try {
      final version = (await File('$base/VERSION').readAsString()).trim();
      final kernel = await File('$base/$_kernel').exists();
      final hz = await File('${rootfs.path}/usr/local/bin/hz').exists();
      final ok = kernel && hz && version == HaizhuBundle.version;
      return (ok: ok, version: version);
    } catch (_) {
      return (ok: false, version: null);
    }
  }

  @override
  Future<String?> install({
    required void Function(SetupAppProgress progress) onProgress,
  }) async {
    final rootfs = await _locate();
    if (rootfs == null) {
      throw const SetupAppFailure(SetupAppFailureKind.unsupported);
    }
    _cancelled = false;
    final base = '${rootfs.path}${HaizhuBundle.root}';
    var done = 0;
    try {
      for (final entry in HaizhuBundle.files.entries) {
        if (_cancelled) {
          throw const SetupAppFailure(SetupAppFailureKind.cancelled);
        }
        final file = File('$base/${entry.key}');
        await file.parent.create(recursive: true);
        final data = base64.decode(entry.value);
        await file.writeAsBytes(data);
        done += data.length;
        onProgress(
          SetupAppProgress(
            stage: SetupAppStage.downloading,
            bytesDone: done,
            bytesTotal: HaizhuBundle.totalBytes,
          ),
        );
      }
    } on SetupAppFailure {
      rethrow;
    } on FileSystemException catch (error) {
      throw SetupAppFailure(
        error.osError?.errorCode == 28
            ? SetupAppFailureKind.noSpace
            : SetupAppFailureKind.failed,
      );
    }
    onProgress(const SetupAppProgress(stage: SetupAppStage.verifying));
    try {
      final wired = await _linux.run(
        'chmod -R a+rX /opt/haizhu &&'
        ' install -m 0755 /opt/haizhu/bin/hz /usr/local/bin/hz && hz seed',
        timeout: const Duration(minutes: 2),
      );
      if (!wired.ok) throw const SetupAppFailure(SetupAppFailureKind.failed);
    } on SetupAppFailure {
      rethrow;
    } catch (_) {
      throw const SetupAppFailure(SetupAppFailureKind.failed);
    }
    return HaizhuBundle.version;
  }

  @override
  void cancel() => _cancelled = true;

  /// `hz remove` deletes every seeded path its manifests record, then the
  /// payload and the PATH link; the `rm` fallbacks cover a partial install
  /// where `hz` never reached PATH. Leftover seeded config inside user
  /// homes is configuration, not payload.
  @override
  Future<void> remove() async {
    final rootfs = await _locate();
    if (rootfs == null) return;
    try {
      await _linux.run(
        'sh /opt/haizhu/bin/hz remove 2>/dev/null;'
        ' rm -rf /opt/haizhu; rm -f /usr/local/bin/hz',
        timeout: const Duration(minutes: 1),
      );
    } catch (_) {
      // Ubuntu may be mid-teardown; deleting from the app still frees it.
      try {
        await Directory('${rootfs.path}${HaizhuBundle.root}').delete(
          recursive: true,
        );
        await File('${rootfs.path}/usr/local/bin/hz').delete();
      } catch (_) {}
    }
    if (await Directory('${rootfs.path}${HaizhuBundle.root}').exists()) {
      throw const SetupAppFailure(SetupAppFailureKind.failed);
    }
  }
}
