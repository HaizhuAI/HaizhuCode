import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haizhucode/api2/client.dart';
import 'package:haizhucode/api2/gateway_operations.dart';
import 'package:haizhucode/api2/gateway_mappers.dart';
import 'package:haizhucode/domain/server_gateway.dart';

void main() {
  group('CustomProviderSpec.toConfigJson', () {
    test('serializes an OpenAI-compatible entry', () {
      final json = CustomProviderSpec(
        id: 'deepseek',
        name: 'DeepSeek',
        baseURL: 'https://api.deepseek.com/v1',
        apiKey: 'sk-fixture',
        models: const ['deepseek-chat', 'deepseek-reasoner'],
        headers: const {'X-Title': 'HaizhuCode'},
      ).toConfigJson();
      expect(json['npm'], '@ai-sdk/openai-compatible');
      expect(json['name'], 'DeepSeek');
      final options = json['options']! as Map<String, Object?>;
      expect(options['baseURL'], 'https://api.deepseek.com/v1');
      expect(options['apiKey'], 'sk-fixture');
      expect(options['headers'], {'X-Title': 'HaizhuCode'});
      final models = json['models']! as Map<String, Object?>;
      expect(models.keys, ['deepseek-chat', 'deepseek-reasoner']);
    });

    test('writes the none placeholder for a keyless endpoint', () {
      final json = const CustomProviderSpec(
        id: 'local',
        name: '',
        baseURL: 'http://127.0.0.1:8080/v1',
        apiKey: '',
        models: ['llama3'],
      ).toConfigJson();
      expect(json.containsKey('name'), isFalse);
      expect((json['options']! as Map)['apiKey'], 'none');
    });

    test('rejects invalid specs before the wire', () {
      CustomProviderSpec spec({
        String id = 'ok',
        String baseURL = 'https://example.com/v1',
        List<String> models = const ['m'],
        Map<String, String> headers = const {},
      }) => CustomProviderSpec(
        id: id,
        name: '',
        baseURL: baseURL,
        models: models,
        headers: headers,
      );
      expect(
        () => spec(id: 'Bad Id').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(id: '-lead').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(baseURL: 'ftp://x').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(baseURL: 'not a url').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(models: const []).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(models: const ['bad model!']).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(headers: {'bad\nname': 'v'}).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
    });

    test('writes custom limits and five reasoning tiers per model', () {
      final json = const CustomProviderSpec(
        id: 'mygw',
        name: 'GW',
        baseURL: 'http://127.0.0.1:9/v1',
        models: ['m-a', 'm-b'],
        contextLimit: 512000,
        inputLimit: 448000,
        outputLimit: 64000,
        reasoning: true,
        defaultEffort: 'medium',
      ).toConfigJson();
      final models = json['models']! as Map<String, Object?>;
      for (final entry in models.values) {
        final model = entry! as Map<String, Object?>;
        expect(model['limit'], {
          'context': 512000,
          'input': 448000,
          'output': 64000,
        });
        expect(model['reasoning'], isTrue);
        expect(model['options'], {'reasoningEffort': 'medium'});
        final variants = model['variants']! as Map<String, Object?>;
        expect(variants.keys, ['none', 'low', 'medium', 'high', 'xhigh']);
        for (final variant in variants.values) {
          expect((variant! as Map)['reasoningEffort'], isA<String>());
        }
        expect((variants['low']! as Map)['reasoningEffort'], 'low');
      }
    });

    test('reasoning off keeps the server defaults', () {
      final json = const CustomProviderSpec(
        id: 'p',
        name: '',
        baseURL: 'https://x.example/v1',
        models: ['m'],
        contextLimit: 256000,
        outputLimit: 16000,
      ).toConfigJson();
      final model =
          (json['models']! as Map<String, Object?>)['m']!
              as Map<String, Object?>;
      expect(model['limit'], {'context': 256000, 'output': 16000});
      expect(model.containsKey('reasoning'), isFalse);
      expect(model.containsKey('variants'), isFalse);
      expect(model.containsKey('options'), isFalse);
    });

    test('rejects unpaired or inverted token limits', () {
      CustomProviderSpec spec({
        int? context,
        int? input,
        int? output,
        String? effort,
      }) => CustomProviderSpec(
        id: 'ok',
        name: '',
        baseURL: 'https://example.com/v1',
        models: const ['m'],
        contextLimit: context,
        inputLimit: input,
        outputLimit: output,
        defaultEffort: effort,
      );
      // context without output — the server stores them as a pair.
      expect(
        () => spec(context: 128000).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(output: 8000).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(context: 0, output: 1).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(context: 100, input: 200, output: 8).toConfigJson(),
        throwsA(isA<ProductException>()),
      );
      expect(
        () => spec(effort: 'extreme').toConfigJson(),
        throwsA(isA<ProductException>()),
      );
    });
  });

  test('api2 reports the customProviders capability', () {
    expect(api2ServerCapabilities.customProviders, isTrue);
  });

  test('upsert/remove/default rewrite the server config file', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    // The config file lives at /cfg/opencode.json; the writes go through
    // /experimental/fs/write (PATCH /experimental/config is {shell}-only
    // on a real server).
    var file = jsonEncode({
      'provider': {
        'kept': {
          'npm': '@ai-sdk/openai-compatible',
          'options': {'baseURL': 'https://kept.example/v1'},
        },
      },
      'other': true,
    });
    final writes = <({Uri uri, Map<String, dynamic> json})>[];
    server.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      if (request.method == 'GET' && request.uri.path.endsWith('/config')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'type': 'directory', 'path': '/cfg'},
              {
                'type': 'document',
                'path': '/cfg/opencode.json',
                'info': jsonDecode(file),
              },
            ],
          }),
        );
      } else if (request.method == 'GET' &&
          request.uri.path.startsWith('/api/fs/read/')) {
        request.response.headers.contentType = ContentType.text;
        request.response.write(file);
      } else if (request.method == 'POST' &&
          request.uri.path.endsWith('/experimental/fs/write')) {
        writes.add((uri: request.uri, json: jsonDecode(text)));
        file = text;
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'location': {},
            'data': {'path': '/cfg/opencode.json'},
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

    await gateway.upsertCustomProvider(
      const CustomProviderSpec(
        id: 'deepseek',
        name: 'DeepSeek',
        baseURL: 'https://api.deepseek.com/v1',
        apiKey: 'sk-fixture',
        models: ['deepseek-chat'],
      ),
    );
    await gateway.setServerDefaultModel('deepseek', 'deepseek-chat');
    await gateway.removeCustomProvider('deepseek');

    expect(writes.length, 3);
    for (final write in writes) {
      expect(write.uri.queryParameters['path'], '/cfg/opencode.json');
      expect(write.uri.queryParameters['location[directory]'], '/work/first');
    }

    // The write replaces the file wholesale, so a cleared entry cannot
    // linger the way it could under a merge patch; unrelated keys and
    // providers stay.
    final saved = writes[0].json;
    final provider = saved['provider'] as Map<String, dynamic>;
    expect(provider.keys, containsAll(['kept', 'deepseek']));
    final entry = provider['deepseek'] as Map<String, dynamic>;
    expect(entry['npm'], '@ai-sdk/openai-compatible');
    expect((entry['options'] as Map)['baseURL'], 'https://api.deepseek.com/v1');
    expect((entry['options'] as Map)['apiKey'], 'sk-fixture');
    expect((entry['models'] as Map).keys, ['deepseek-chat']);
    expect(saved['other'], isTrue);

    expect(writes[1].json['model'], 'deepseek/deepseek-chat');

    final removed = writes[2].json;
    expect((removed['provider'] as Map).containsKey('deepseek'), isFalse);
    expect((removed['provider'] as Map).containsKey('kept'), isTrue);
    expect(removed.containsKey('model'), isFalse);
  });
}
