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
  });

  test('api2 reports the customProviders capability', () {
    expect(api2ServerCapabilities.customProviders, isTrue);
  });

  test('upsert/remove/default hit PATCH /experimental/config', () async {
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
      request.response.statusCode = 204;
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

    expect(calls.length, 3);
    for (final call in calls) {
      expect(call.method, 'PATCH');
      expect(call.uri.path, endsWith('/experimental/config'));
      expect(call.uri.queryParameters['location[directory]'], '/work/first');
    }

    final provider = calls[0].body['provider'] as Map<String, dynamic>;
    final entry = provider['deepseek'] as Map<String, dynamic>;
    expect(entry['npm'], '@ai-sdk/openai-compatible');
    expect((entry['options'] as Map)['baseURL'], 'https://api.deepseek.com/v1');
    expect((entry['options'] as Map)['apiKey'], 'sk-fixture');
    expect((entry['models'] as Map).keys, ['deepseek-chat']);

    expect(calls[1].body['model'], 'deepseek/deepseek-chat');
    expect(calls[2].body['provider'], {'deepseek': null});
  });
}
