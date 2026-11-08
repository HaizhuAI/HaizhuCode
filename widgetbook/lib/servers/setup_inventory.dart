import 'package:flutter/widgets.dart';
import 'package:haizhucode/l10n/app_localizations.dart';
import 'package:haizhucode/ui/kit/kit.dart';
import 'package:haizhucode/ui/screens/phone_setup/phone_setup_customize_sheet.dart';
import 'package:haizhucode/ui/screens/phone_setup/phone_setup_selection.dart';
import 'package:haizhucode/ui/screens/team/team_intro_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';
import '../fakes/setup_inventory.dart';

Widget _scene({
  bool addTools = false,
  Set<String> installed = const {},
  bool unavailable = false,
}) => FakeAppScene<SetupInventoryScene>(
  platform: FakePlatform.android,
  create: () => SetupInventoryScene.create(
    installed: installed,
    unavailable: unavailable,
  ),
  builder: (context, scene) {
    scene.engine.strings = lookupAppLocalizations(
      Localizations.localeOf(context),
    );
    if (addTools) {
      return KitScreen(
        body: SetupCustomizeSheet(
          registry: installableComponents(scene.engine.registry),
          addMode: true,
          loadInstalledOptional: scene.engine.installedOptional,
          deviceProbe: catalogSetupPhone,
        ),
      );
    }
    return TeamIntroScreen(
      controller: scene.app.connection,
      deviceProbe: catalogSetupPhone,
    );
  },
);

CatalogComponent teamIntroScreen() => catalogComponent(
  area: 'Servers',
  screen: 'TeamIntroScreen',
  name: 'AI Team introduction',
  useCases: [
    WidgetbookUseCase(
      name: 'Programs need installing',
      builder: (_) => _scene(),
    ),
    WidgetbookUseCase(
      name: 'AI Team already installed',
      builder: (_) => _scene(installed: const {'python', 'aiteam'}),
    ),
    WidgetbookUseCase(
      name: 'Inventory unavailable with retry',
      builder: (_) => _scene(unavailable: true),
    ),
  ],
);

CatalogComponent setupCustomizeSheet() => catalogComponent(
  area: 'Servers',
  screen: 'SetupCustomizeSheet',
  name: 'Add tools',
  useCases: [
    WidgetbookUseCase(
      name: 'Optional tools available',
      builder: (_) => _scene(addTools: true),
    ),
    WidgetbookUseCase(
      name: 'Python and AI Team installed',
      builder: (_) =>
          _scene(addTools: true, installed: const {'python', 'aiteam'}),
    ),
    WidgetbookUseCase(
      name: 'Inventory unavailable with retry',
      builder: (_) => _scene(addTools: true, unavailable: true),
    ),
  ],
);
