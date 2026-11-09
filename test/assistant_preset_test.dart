import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haizhucode/api2/client.dart';
import 'package:haizhucode/api2/gateway_operations.dart';
import 'package:haizhucode/api2/gateway_mappers.dart';
import 'package:haizhucode/domain/server_gateway.dart';

void main() {
  group('AssistantPresetSpec.toConfigJson', () {
    test('serializes a full agent.<id> entry', () {
      final json = const AssistantPresetSpec(
        id: 'code-reviewer',
        description: 'Reviews diffs before they merge',
        mode: 'primary',
        model: 'anthropic/claude-sonnet-4-5',
        prompt: 'You are a careful reviewer.',
        temperature: 0.3,
        topP: 0.9,
        color: '#A64F2E',
      ).toConfigJson();
      expect(json['description'], 'Reviews diffs before they merge');
      expect(json['mode'], 'primary');
      expect(json['model'], 'anthropic/claude-sonnet-4-5');
      expect(json['prompt'], 'You are a careful reviewer.');
      expect(json['temperature'], 0.3);
      expect(json['top_p'], 0.9);
      expect(json['color'], '#A64F2E');
      expect(json.containsKey('disable'), isFalse);
    });

    test('omits the optional fields when unset', () {
      final json = const AssistantPresetSpec(
        id: 'writer',
        description: '',
        prompt: 'Write plainly.',
      ).toConfigJson();
      expect(json['mode'], 'primary');
      expect(json.containsKey('model'), isFalse);
      expect(json.containsKey('temperature'), isFalse);
      expect(json.containsKey('top_p'), isFalse);
      expect(json.containsKey('color'), isFalse);
      expect(json.containsKey('description'), isFalse);
    });

    test('reads a config entry back', () {
      final spec = AssistantPresetSpec.fromConfigJson('ops', {
        'description': 'Runs ops checks',
        'mode': 'subagent',
        'model': 'openai/gpt-5',
        'prompt': 'Check first.',
        'temperature': 1.2,
        'top_p': 0.5,
        'color': '#112233',
        'disable': true,
      });
      expect(spec.id, 'ops');
      expect(spec.mode, 'subagent');
      expect(spec.model, 'openai/gpt-5');
      expect(spec.temperature, 1.2);
      expect(spec.topP, 0.5);
      expect(spec.color, '#112233');
      expect(spec.disable, isTrue);
    });

    test('rejects invalid specs before the wire', () {
      AssistantPresetSpec spec({
        String id = 'ok',
        String mode = 'primary',
        String prompt = 'Do the thing.',
        String? model,
        double? temperature,
        double? topP,
        String? color,
      }) => AssistantPresetSpec(
        id: id,
        description: '',
        mode: mode,
        prompt: prompt,
        model: model,
        temperature: temperature,
        topP: topP,
        color: color,
      );
      expect(
        () => spec(id: 'Bad Id').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(mode: 'everywhere').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(prompt: '   ').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(model: 'nomodel').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(temperature: 3).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(topP: 0).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(color: 'orange').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
    });
  });

  test('api2 reports the assistantPresets capability', () {
    expect(api2ServerCapabilities.assistantPresets, isTrue);
  });

  test('upsert clears the entry then writes it; remove deletes; read merges '
      'the priority-ordered /config documents', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final calls = <({String method, Uri uri, dynamic body})>[];
    server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      calls.add((
        method: request.method,
        uri: request.uri,
        body: text.isEmpty ? null : jsonDecode(text),
      ));
      if (request.method == 'GET' && request.uri.path.endsWith('/config')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          // The real envelope: one entry per config document, lowest to
          // highest priority, each `info` holding the parsed body.
          jsonEncode({
            'data': [
              {
                'type': 'config',
                'path': '/etc/opencode/opencode.json',
                'info': {
                  'agent': {
                    'ops': {'mode': 'primary', 'prompt': 'Old.'},
                    'gone': {'prompt': 'Gone.'},
                  },
                },
              },
              {
                'type': 'config',
                'path': '/work/first/opencode.json',
                'info': {
                  'agent': {
                    'ops': {'mode': 'subagent', 'prompt': 'Check.'},
                    'gone': null,
                    'notes': true, // non-map entries are ignored
                  },
                },
              },
            ],
          }),
        );
      } else {
        request.response.statusCode = 204;
      }
      await request.response.close();
    });
    final client = Api2Client.connect(
      baseUrl: 'http://${server.address.host}:${server.port}',
      password: 'fixture',
      directory: '/work/first',
    );
    addTearDown(client.close);
    final gateway = Api2OperationsGateway(client: client);

    await gateway.upsertAssistantPreset(
      const AssistantPresetSpec(
        id: 'code-reviewer',
        description: 'Reviews diffs',
        prompt: 'Be careful.',
        temperature: 0.2,
      ),
    );
    await gateway.removeAssistantPreset('code-reviewer');
    final configured = await gateway.configuredAssistants();

    expect(calls.length, 4);
    expect(calls[0].method, 'PATCH');
    expect(calls[0].uri.path, endsWith('/experimental/config'));
    expect(calls[0].uri.queryParameters['location[directory]'], '/work/first');
    // Delete first so cleared optional fields cannot linger.
    expect(calls[0].body['agent'], {'code-reviewer': null});
    final agent = calls[1].body['agent'] as Map<String, dynamic>;
    final entry = agent['code-reviewer'] as Map<String, dynamic>;
    expect(entry['prompt'], 'Be careful.');
    expect(entry['temperature'], 0.2);

    expect(calls[2].body['agent'], {'code-reviewer': null});

    expect(calls[3].method, 'GET');
    expect(calls[3].uri.path, endsWith('/config'));
    // Higher-priority document wins; a `null` in it deletes the id.
    expect(configured.length, 1);
    expect(configured.single.id, 'ops');
    expect(configured.single.mode, 'subagent');
    expect(configured.single.prompt, 'Check.');
  });
}
