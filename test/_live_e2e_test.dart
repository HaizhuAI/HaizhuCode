// Manual live check against a real OpenCode 2 server — skipped by default:
//   flutter test test/_live_e2e_test.dart --plain-name live
// needs OC2_BASE/OC2_PASSWORD/OC2_DIR env vars; skipped otherwise.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haizhucode/api2/client.dart';
import 'package:haizhucode/api2/gateway_operations.dart';
import 'package:haizhucode/domain/server_gateway.dart';

void main() {
  final base = Platform.environment['OC2_BASE'];
  final password = Platform.environment['OC2_PASSWORD'] ?? '';
  final directory = Platform.environment['OC2_DIR'] ?? '';

  test(
    'live: provider/assistant config writes land on a real server',
    () async {
      final client = Api2Client.connect(
        baseUrl: base!,
        password: password,
        directory: directory,
      );
      addTearDown(client.close);
      final gateway = Api2OperationsGateway(client: client);

      await gateway.upsertCustomProvider(
        const CustomProviderSpec(
          id: 'e2e-check',
          name: 'E2E Check',
          baseURL: 'https://api.e2e.local/v1',
          apiKey: 'sk-e2e',
          models: ['e2e-model'],
        ),
      );
      await gateway.setServerDefaultModel('e2e-check', 'e2e-model');
      await gateway.upsertAssistantPreset(
        const AssistantPresetSpec(
          id: 'e2e-ast',
          description: 'verify',
          prompt: 'be nice',
          mode: 'all',
          temperature: 0.4,
        ),
      );
      final configured = await gateway.configuredAssistants();
      final found = configured.where((a) => a.id == 'e2e-ast');
      expect(found, hasLength(1));
      expect(found.single.mode, 'all');
      expect(found.single.temperature, 0.4);
      expect(found.single.prompt, 'be nice');

      await gateway.removeCustomProvider('e2e-check');
      await gateway.removeAssistantPreset('e2e-ast');
      // fs/write hot-reloads asynchronously; give the server a moment.
      await Future<void>.delayed(const Duration(seconds: 2));
      final after = await gateway.configuredAssistants();
      expect(after.any((a) => a.id == 'e2e-ast'), isFalse);
    },
    skip: base == null ? 'set OC2_BASE/OC2_PASSWORD/OC2_DIR to run live' : false,
  );
}
