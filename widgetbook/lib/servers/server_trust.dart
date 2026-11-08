import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:haizhucode/state/profiles.dart';
import 'package:haizhucode/ui/kit/kit.dart';
import 'package:haizhucode/ui/screens/servers_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';

const _fingerprint =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

Widget _editor(String url, {bool pinned = false}) => FakeAppScene<FakeApp>(
  create: () => FakeApp.create(
    profiles: [FakeProfile('trust', 'My server', url: url)],
    prefs: {
      if (pinned)
        '${ProfileStore.certificatePinKeyPrefix}trust': jsonEncode({
          'origin': 'https://private.example:4099',
          'sha256': _fingerprint,
        }),
    },
  ),
  builder: (_, app) => Navigator(
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      settings: const RouteSettings(
        arguments: ServersRouteRequest.edit('trust'),
      ),
      builder: (_) => const ServersScreen(),
    ),
  ),
);

CatalogComponent serverTrustEditor() => catalogComponent(
  area: 'Servers',
  screen: 'ServersScreen',
  name: 'Server transport trust',
  useCases: [
    WidgetbookUseCase(
      name: 'Private HTTP needs permission',
      builder: (_) => _editor('http://192.168.1.20:4098'),
    ),
    WidgetbookUseCase(
      name: 'Tailscale HTTP needs permission',
      builder: (_) => _editor('http://100.64.0.8:4098'),
    ),
    WidgetbookUseCase(
      name: 'Public HTTP needs permission',
      builder: (_) => _editor('http://public.example:4098'),
    ),
    WidgetbookUseCase(
      name: 'Saved certificate can be re-checked',
      builder: (_) => _editor('https://private.example:4099', pinned: true),
    ),
  ],
);

CatalogComponent serverTrustWarning() => catalogComponent(
  area: 'Servers',
  name: 'Certificate trust warning',
  useCases: [
    for (final changed in [false, true])
      WidgetbookUseCase(
        name: changed
            ? 'Changed certificate stays blocked'
            : 'Compare first certificate',
        builder: (_) => KitScreen(
          body: SingleChildScrollView(
            child: KitServerTrustBody(
              origin: 'https://private.example:4099',
              fingerprintSha256: _fingerprint,
              certificateChanged: changed,
            ),
          ),
        ),
      ),
  ],
);
