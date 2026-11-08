import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:haizhucode/builtin/builtin_linux.dart';
import 'package:haizhucode/builtin/setup/components.dart';
import 'package:haizhucode/builtin/setup/phone_setup.dart';
import 'package:haizhucode/builtin/setup/setup_contract.dart';
import 'package:haizhucode/l10n/app_localizations.dart';
import 'package:haizhucode/state/connection.dart';
import 'package:haizhucode/state/profiles.dart';
import 'package:haizhucode/voice/device.dart';

import 'fake_app.dart';

/// Inventory-only setup: no catalog action can start a native install.
class CatalogSetupInventory implements SetupEngine {
  CatalogSetupInventory({this.installed = const {}, this.unavailable = false});

  final Set<String> installed;
  final bool unavailable;
  final _progress = ValueNotifier<SetupProgress>(SetupProgress.idle);
  AppLocalizations strings = lookupAppLocalizations(const Locale('en'));

  @override
  List<SetupComponent> get registry => [
    for (final component in setupComponents(strings))
      if (component.app == null) component,
  ];

  @override
  ValueListenable<SetupProgress> get progress => _progress;

  @override
  Future<Set<String>> installedOptional() async {
    if (unavailable) throw StateError('Catalog inventory unavailable');
    return Set.of(installed);
  }

  @override
  Future<void> restore({SetupReadScope? scope}) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> run(
    Set<String> ids, {
    Map<String, Map<String, String>> params = const {},
  }) async {}

  void dispose() => _progress.dispose();
}

/// Owns and restores the shared setup seam when a catalog scene closes.
class SetupInventoryScene implements SceneResource {
  SetupInventoryScene(this.app, this.engine) : _previous = PhoneSetup.engine {
    PhoneSetup.engine = engine;
  }

  final FakeApp app;
  final CatalogSetupInventory engine;
  final SetupEngine _previous;

  static Future<SetupInventoryScene> create({
    Set<String> installed = const {},
    bool unavailable = false,
  }) async {
    final app = await FakeApp.create(
      controllerFactory: _CatalogPhoneConnection.new,
      profiles: [
        FakeProfile('phone', 'This phone', url: BuiltinLinux.serverUrl),
      ],
    );
    return SetupInventoryScene(
      app,
      CatalogSetupInventory(installed: installed, unavailable: unavailable),
    );
  }

  @override
  void dispose() {
    PhoneSetup.engine = _previous;
    engine.dispose();
    app.dispose();
  }
}

Future<VoiceDeviceInfo> catalogSetupPhone() async => const VoiceDeviceInfo(
  supportedAbis: ['arm64-v8a'],
  totalMemoryMb: 8192,
  memoryClassMb: 512,
  hasMicrophone: true,
  availableStorageBytes: 20000000000,
);

class _CatalogPhoneConnection extends ConnectionController {
  _CatalogPhoneConnection(super.store);

  @override
  ServerProfile? get profile => store.active;
}
