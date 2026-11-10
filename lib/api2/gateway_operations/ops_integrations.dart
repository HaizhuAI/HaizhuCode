part of '../gateway_operations.dart';

mixin _Api2IntegrationOps on _Api2Core {
  /// v2 OAuth attempt routes are integration-scoped, but the domain contract
  /// only carries the attempt ID (matrix risk 7). Remember the owning
  /// integration for every attempt this gateway started.
  final Map<String, ({String integrationID, Map<String, dynamic> location})>
  _oauthAttempts = {};
  final Map<String, IntegrationAuthStatus> _oauthTerminalStatuses = {};

  // ---------------- Integrations ----------------

  @override
  Future<List<IntegrationInfo>> listIntegrations() =>
      _guard('Could not load integrations', () async {
        final json = await _transport.getJson('/integration', query: _loc());
        return [
          for (final item in _dataMaps(json))
            if ((item['id'] ?? '').toString().isNotEmpty) _integration(item),
        ];
      });

  /// One sign-in question in the app's prompt shape. OpenCode 2 sends form
  /// fields (`title`, `type: string`, `options`, `custom`, `required`,
  /// `default`, `hidden`); the beta's `text`/`select` prompts pass through.
  /// A hidden field is never asked: null, and its default is a preset answer.
  static Map<String, dynamic>? _formPrompt(Map<String, dynamic> field) {
    if (field['hidden'] == true) return null;
    final type = field['type']?.toString();
    if (type == 'text' || type == 'select') return field;
    final options = [
      for (final option in (field['options'] as List? ?? const []))
        if (option is Map && option.containsKey('value'))
          {
            'value': option['value'].toString(),
            'label': (option['label'] ?? option['value']).toString(),
          },
    ];
    return {
      'key': field['key'],
      'message': field['title'] ?? field['message'] ?? field['key'],
      'type': options.isNotEmpty && field['custom'] != true ? 'select' : 'text',
      if (options.isNotEmpty) 'options': options,
      'required': field['required'] == true,
      if (field['placeholder'] != null) 'placeholder': field['placeholder'],
      if (field['default'] != null) 'default': '${field['default']}',
      if (field['when'] is Map) 'when': field['when'],
    };
  }

  IntegrationInfo _integration(Map<String, dynamic> json) {
    final methods = <IntegrationMethodInfo>[];
    if (json['methods'] is List) {
      for (final raw in json['methods'] as List) {
        if (raw is! Map) continue;
        final method = Map<String, dynamic>.from(raw);
        final type = (method['type'] ?? '').toString();
        if (type.isEmpty) continue;
        final presets = <String, String>{};
        final prompts = <Map<String, dynamic>>[];
        if (method['form'] is List) {
          for (final field in method['form'] as List) {
            if (field is! Map) continue;
            final prompt = _formPrompt(Map<String, dynamic>.from(field));
            if (prompt == null) {
              final key = field['key']?.toString();
              final value = field['default'];
              if (key != null && value != null) presets[key] = '$value';
            } else {
              prompts.add(prompt);
            }
          }
        }
        methods.add(
          IntegrationMethodInfo(
            type: type,
            id: method['id']?.toString(),
            label: (method['label'] ?? type).toString(),
            prompts: prompts,
            presetAnswers: presets,
            environmentNames: method['names'] is List
                ? (method['names'] as List)
                      .map((value) => value.toString())
                      .toList()
                : const [],
          ),
        );
      }
    }
    final connections = <IntegrationConnectionInfo>[];
    if (json['connections'] is List) {
      for (final raw in json['connections'] as List) {
        if (raw is! Map) continue;
        final connection = Map<String, dynamic>.from(raw);
        final type = (connection['type'] ?? '').toString();
        connections.add(
          IntegrationConnectionInfo(
            type: type,
            id: connection['id']?.toString(),
            label: (connection['label'] ?? connection['name'] ?? type)
                .toString(),
          ),
        );
      }
    }
    return IntegrationInfo(
      id: json['id'].toString(),
      name: (json['name'] ?? json['id']).toString(),
      methods: methods,
      connections: connections,
      connectionCount: connections.length,
    );
  }

  @override
  Future<void> renameCredential(
    String id,
    String label,
  ) => _guard('Could not rename the credential', () async {
    final location = _loc();
    final path = _credentialPath(id);
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty ||
        normalizedLabel.runes.length > 128 ||
        label.contains(RegExp(r'[\x00-\x1f\x7f-\x9f]'))) {
      throw const ProductException(
        'Enter a credential label of 1–128 characters without control characters',
      );
    }
    await _transport.patchJson(
      path,
      query: location,
      body: {'label': normalizedLabel},
    );
  });

  @override
  Future<void> activateCredential(String id) =>
      _guard('Could not activate the credential', () async {
        final location = _loc();
        await _transport.postJson(
          '${_credentialPath(id)}/activate',
          query: location,
        );
      });

  @override
  Future<void> removeCredential(String id) =>
      _guard('Could not remove the credential', () async {
        final location = _loc();
        await _transport.deleteJson(_credentialPath(id), query: location);
      });

  static String _credentialPath(String id) {
    if (id.trim().isEmpty) {
      throw const ProductException('Enter a nonempty credential ID');
    }
    return '/credential/${Uri.encodeComponent(id)}';
  }

  @override
  Future<void> connectIntegrationKey(String id, String key, {String? label}) =>
      _guard('Could not connect the integration', () {
        KitRedact.registerKnownSecret(key);
        return _transport.postJson(
          '/integration/${Uri.encodeComponent(id)}/connect/key',
          query: _loc(),
          body: {'key': key, 'label': ?label},
        );
      });

  @override
  Future<void> disconnectIntegration(IntegrationInfo integration) =>
      _guard('Could not disconnect the integration', () async {
        final credentialIDs = integration.credentialIDs;
        if (credentialIDs.isEmpty) {
          throw ProductException(
            integration.hasEnvironmentConnection
                ? 'This integration is connected through server environment '
                      'variables and cannot be disconnected from the app'
                : 'This integration has no stored credential to remove',
          );
        }
        for (final credentialID in credentialIDs) {
          await _transport.deleteJson(
            '/credential/${Uri.encodeComponent(credentialID)}',
          );
        }
      });

  @override
  Future<void> refreshProviderRuntime() => Future.error(
    const ProductException(
      'Provider runtime refresh is unavailable on this server',
    ),
  );

  @override
  Future<IntegrationAuthLaunch> startIntegrationOAuth(
    String id,
    String methodID, {
    Map<String, String> inputs = const {},
    String? label,
  }) => _commandAuthGuard('Could not start the sign-in', () async {
    final location = _loc();
    final json = await _transport.postJson(
      '/integration/${Uri.encodeComponent(id)}/connect/oauth',
      query: location,
      body: {
        'methodID': methodID,
        if (inputs.isNotEmpty) 'answer': inputs,
        'label': ?label,
      },
    );
    final data = _dataMap(json);
    final attemptID = (data['attemptID'] ?? '').toString();
    if (attemptID.isEmpty) {
      throw const ProductException('OpenCode returned no sign-in attempt');
    }
    _oauthAttempts[attemptID] = (integrationID: id, location: location);
    if (_oauthAttempts.length > 32) {
      _oauthAttempts.remove(_oauthAttempts.keys.first);
    }
    _oauthTerminalStatuses.remove(attemptID);
    final time = data['time'];
    return IntegrationAuthLaunch(
      attemptID: attemptID,
      url: (data['url'] ?? '').toString(),
      instructions: (data['instructions'] ?? '').toString(),
      mode: data['mode']?.toString() == 'code'
          ? IntegrationAuthMode.code
          : IntegrationAuthMode.auto,
      expiresAt: time is Map ? (time['expires'] as num?)?.toInt() : null,
    );
  });

  ({String integrationID, Map<String, dynamic> location}) _attempt(
    String attemptID,
  ) {
    final attempt = _oauthAttempts[attemptID];
    if (attempt == null) {
      throw const ProductException(
        'This sign-in attempt must be restored at its original location',
      );
    }
    return attempt;
  }

  @override
  Future<IntegrationAuthStatus> integrationOAuthStatus(String attemptID) =>
      _commandAuthGuard('Could not check the sign-in status', () async {
        if (_oauthTerminalStatuses[attemptID] case final cached?) return cached;
        final attempt = _attempt(attemptID);
        final json = await _transport.getJson(
          '/integration/${Uri.encodeComponent(attempt.integrationID)}'
          '/connect/oauth/${Uri.encodeComponent(attemptID)}',
          query: attempt.location,
        );
        final data = _dataMap(json);
        final status =
            (data['status'] ??
                    (json is Map<String, dynamic> ? json['status'] : null))
                ?.toString();
        final result = IntegrationAuthStatus(
          state: switch (status) {
            'complete' => IntegrationAuthState.complete,
            'failed' => IntegrationAuthState.failed,
            'expired' => IntegrationAuthState.expired,
            'pending' => IntegrationAuthState.pending,
            _ => throw const ProductException(
              'OpenCode returned an invalid sign-in status',
            ),
          },
        );
        if (result.state != IntegrationAuthState.pending) {
          _oauthAttempts.remove(attemptID);
          _oauthTerminalStatuses[attemptID] = result;
          if (_oauthTerminalStatuses.length > 32) {
            _oauthTerminalStatuses.remove(_oauthTerminalStatuses.keys.first);
          }
        }
        return result;
      });

  @override
  Future<void> completeIntegrationOAuth(String attemptID, {String? code}) =>
      _commandAuthGuard('Could not finish the sign-in', () async {
        if (_oauthTerminalStatuses[attemptID]?.state ==
            IntegrationAuthState.complete) {
          return;
        }
        final attempt = _attempt(attemptID);
        await _transport.postJson(
          '/integration/${Uri.encodeComponent(attempt.integrationID)}'
          '/connect/oauth/${Uri.encodeComponent(attemptID)}/complete',
          query: attempt.location,
          body: {'code': ?code},
        );
      });

  @override
  Future<void> cancelIntegrationOAuth(String attemptID) =>
      _commandAuthGuard('Could not cancel the sign-in', () async {
        if (_oauthTerminalStatuses.remove(attemptID) != null) return;
        final attempt = _attempt(attemptID);
        await _transport.deleteJson(
          '/integration/${Uri.encodeComponent(attempt.integrationID)}'
          '/connect/oauth/${Uri.encodeComponent(attemptID)}',
          query: attempt.location,
        );
        _oauthAttempts.remove(attemptID);
      });

  final _commandAttemptLocations = <(String, String), Map<String, dynamic>>{};

  @override
  void restoreIntegrationAuthAttempt({
    required String integrationID,
    required String attemptID,
    required bool command,
    String? directory,
    String? workspace,
  }) {
    _validateCommandAuthID(integrationID);
    _validateCommandAuthID(attemptID);
    final location = <String, dynamic>{
      'location[directory]': ?directory,
      'location[workspace]': ?workspace,
    };
    if (command) {
      _commandAttemptLocations[(integrationID, attemptID)] = location;
      if (_commandAttemptLocations.length > 32) {
        _commandAttemptLocations.remove(_commandAttemptLocations.keys.first);
      }
    } else {
      // Attempt IDs alone are not a source identity. A previous location's
      // terminal cache must never satisfy a restored attempt at another source.
      _oauthTerminalStatuses.remove(attemptID);
      _oauthAttempts[attemptID] = (
        integrationID: integrationID,
        location: location,
      );
      if (_oauthAttempts.length > 32) {
        _oauthAttempts.remove(_oauthAttempts.keys.first);
      }
    }
  }

  // No browser or local command is involved. Rehydrated attempts retain the
  // original location even if this gateway later changes its selected location.
  @override
  Future<IntegrationAuthLaunch> startIntegrationCommand(
    String integrationID,
    String methodID, {
    String? label,
  }) => _commandAuthGuard('Could not start command sign-in', () async {
    final location = _loc();
    final path = _commandAuthPath(integrationID);
    _validateCommandAuthID(methodID);
    final json = await _transport.postJson(
      path,
      query: location,
      body: {'methodID': methodID, 'label': ?label},
    );
    final data = _commandAuthData(json);
    final attemptID = data['attemptID'];
    if (attemptID is! String) {
      throw const ProductException(
        'OpenCode returned an invalid sign-in attempt',
      );
    }
    _validateCommandAuthID(attemptID);
    _commandAttemptLocations[(integrationID, attemptID)] = location;
    if (_commandAttemptLocations.length > 32) {
      _commandAttemptLocations.remove(_commandAttemptLocations.keys.first);
    }
    return IntegrationAuthLaunch(
      attemptID: attemptID,
      url: '',
      instructions: '',
      mode: IntegrationAuthMode.auto,
      expiresAt: _commandAuthExpiry(data),
    );
  });

  @override
  Future<IntegrationAuthStatus> integrationCommandStatus(
    String integrationID,
    String attemptID,
  ) => _commandAuthGuard('Could not check command sign-in status', () async {
    final location =
        _commandAttemptLocations[(integrationID, attemptID)] ?? _loc();
    final json = await _transport.getJson(
      _commandAuthPath(integrationID, attemptID),
      query: location,
    );
    final data = _commandAuthData(json);
    final state = switch (data['status']) {
      'pending' => IntegrationAuthState.pending,
      'complete' => IntegrationAuthState.complete,
      'failed' => IntegrationAuthState.failed,
      'expired' => IntegrationAuthState.expired,
      _ => throw const ProductException(
        'OpenCode returned an invalid command sign-in status',
      ),
    };
    return IntegrationAuthStatus(
      state: state,
      // Provider messages can contain credentials or executable commands.
      message: state == IntegrationAuthState.failed
          ? 'Command sign-in failed'
          : null,
      expiresAt: _commandAuthExpiry(data),
    );
  });

  @override
  Future<void> cancelIntegrationCommand(
    String integrationID,
    String attemptID,
  ) => _commandAuthGuard('Could not cancel command sign-in', () async {
    final location =
        _commandAttemptLocations[(integrationID, attemptID)] ?? _loc();
    await _transport.deleteJson(
      _commandAuthPath(integrationID, attemptID),
      query: location,
    );
    _commandAttemptLocations.remove((integrationID, attemptID));
  });

  static void _validateCommandAuthID(String id) {
    if (id.trim().isEmpty ||
        id == '.' ||
        id == '..' ||
        id.contains(RegExp(r'[\x00-\x1f\x7f-\x9f]'))) {
      throw const ProductException('Enter a valid command sign-in ID');
    }
  }

  static String _commandAuthPath(String integrationID, [String? attemptID]) {
    _validateCommandAuthID(integrationID);
    if (attemptID != null) _validateCommandAuthID(attemptID);
    return '/integration/${Uri.encodeComponent(integrationID)}/connect/command'
        '${attemptID == null ? '' : '/${Uri.encodeComponent(attemptID)}'}';
  }

  static Map<dynamic, dynamic> _commandAuthData(dynamic json) {
    final data = json is Map && json.containsKey('data') ? json['data'] : json;
    if (data is! Map) {
      throw const ProductException(
        'OpenCode returned an invalid command sign-in response',
      );
    }
    return data;
  }

  static int? _commandAuthExpiry(Map<dynamic, dynamic> data) {
    final time = data['time'];
    if (time == null) return null;
    if (time is Map) {
      final expires = time['expires'];
      if (expires == null) return null;
      if (expires is int && expires >= 0) return expires;
    }
    throw const ProductException('OpenCode returned an invalid sign-in expiry');
  }

  static Future<T> _commandAuthGuard<T>(
    String message,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on ProductException {
      rethrow;
    } catch (_) {
      // Do not retain raw transport/provider errors even as a diagnostic cause.
      throw ProductException(message);
    }
  }

  /// `PATCH /experimental/config` accepts `{shell}` alone (the schema is
  /// `Config.Patch` with `additionalProperties: false`) — provider and
  /// agent entries have no dedicated write endpoint in v2. They land in
  /// the server's config file instead: `experimental/fs/write` replaces
  /// the document the server already loads, and the running instance
  /// hot-reloads it (the same file `hz provider`/`hz assistant` edits on
  /// a managed host).
  ///
  /// `_serverConfigPath` picks the file: the `opencode.json`/`.jsonc`
  /// document inside the reported config directory, or that directory's
  /// `opencode.json` when no document exists yet. A stray project-level
  /// document only serves as the fallback when the server reports no
  /// config directory at all.
  Future<String> _serverConfigPath() async {
    final config = await _transport.getJson('/config', query: _loc());
    String? directory;
    final documents = <String>[];
    for (final entry in _dataMaps(config)) {
      final path = entry['path'];
      if (path is! String || path.trim().isEmpty) continue;
      switch (entry['type']) {
        case 'directory':
          directory ??= path;
        case 'document':
          final name = path.replaceAll('\\', '/').split('/').last;
          if (name == 'opencode.json' || name == 'opencode.jsonc') {
            documents.add(path);
          }
      }
    }
    final root = directory
        ?.replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    String? target;
    if (root != null) {
      for (final document in documents) {
        if (document.replaceAll('\\', '/').startsWith('$root/')) {
          target = document;
        }
      }
      target ??= '$root/opencode.json';
    }
    target ??= documents.isEmpty ? null : documents.last;
    if (target == null || target.isEmpty) {
      throw const ProductException('OpenCode reported no writable config file');
    }
    return target;
  }

  /// `/fs/read/<name>` is confined to the requested location, so the
  /// location query points at the file's own directory. A missing file
  /// reads as an empty document; JSONC comments and trailing commas are
  /// tolerated on the way in (the rewrite lands plain JSON).
  Future<Map<String, Object?>> _readServerConfig(String path) async {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final dir = slash >= 0 ? normalized.substring(0, slash) : normalized;
    final name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    final List<int> bytes;
    try {
      bytes = await _transport.getBytes(
        '/fs/read/${Uri.encodeComponent(name)}',
        query: {'location[directory]': dir},
      );
    } on Api2Error catch (error) {
      if (error.isNotFound) return <String, Object?>{};
      rethrow;
    }
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.isEmpty) return <String, Object?>{};
    final decoded = _decodeConfig(text);
    if (decoded is! Map) {
      throw const ProductException('Could not parse the server config file');
    }
    return decoded.cast<String, Object?>();
  }

  static Object? _decodeConfig(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      // JSONC: strip comments outside strings, then trailing commas.
      final stripped = _stripJsonComments(text);
      try {
        return jsonDecode(stripped);
      } on FormatException {
        return jsonDecode(
          stripped.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!),
        );
      }
    }
  }

  static String _stripJsonComments(String text) {
    final out = StringBuffer();
    var inString = false;
    var escaped = false;
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (inString) {
        out.write(c);
        if (escaped) {
          escaped = false;
        } else if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        i++;
        continue;
      }
      if (c == '"') {
        inString = true;
        out.write(c);
        i++;
        continue;
      }
      if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
        while (i < text.length && text[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < text.length && text[i + 1] == '*') {
        i += 2;
        while (i + 1 < text.length && !(text[i] == '*' && text[i + 1] == '/')) {
          i++;
        }
        i += 2;
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  /// Read-modify-write on the server's config file: [merge] edits the
  /// decoded document in place, then the whole body goes back through
  /// `experimental/fs/write`. Because the write replaces the entry map
  /// wholesale, a key the form cleared disappears for good — no stale
  /// fields survive like they could under a merge patch.
  Future<void> _updateServerConfig(
    void Function(Map<String, Object?> json) merge,
  ) async {
    final path = await _serverConfigPath();
    final json = await _readServerConfig(path);
    merge(json);
    final body = utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(json)}\n',
    );
    await _transport.postBytes(
      '/experimental/fs/write',
      body: body,
      query: _loc({'path': path}),
    );
  }

  static Map<String, Object?> _entryMap(Map<String, Object?> json, String key) {
    final section = json[key];
    final map = section is Map
        ? section.cast<String, Object?>()
        : <String, Object?>{};
    json[key] = map;
    return map;
  }

  @override
  Future<void> upsertCustomProvider(CustomProviderSpec spec) =>
      _guard('Could not save the provider', () async {
        // Validation lives in toConfigJson so a bad spec never reaches the
        // wire. The apiKey inside the written file is never logged: _guard
        // wraps errors without echoing request data.
        final entry = spec.toConfigJson();
        await _updateServerConfig((json) {
          _entryMap(json, 'provider')[spec.id] = entry;
        });
      });

  @override
  Future<void> removeCustomProvider(String providerID) =>
      _guard('Could not remove the provider', () async {
        final id = providerID.trim();
        if (id.isEmpty) {
          throw const ProductException('Enter a provider id');
        }
        await _updateServerConfig((json) {
          _entryMap(json, 'provider').remove(id);
          final model = json['model'];
          if (model is String && model.startsWith('$id/')) {
            json.remove('model');
          }
        });
      });

  @override
  Future<void> setServerDefaultModel(String providerID, String modelID) =>
      _guard('Could not set the default model', () async {
        await _updateServerConfig((json) {
          json['model'] = '${providerID.trim()}/${modelID.trim()}';
        });
      });

  @override
  Future<void> upsertAssistantPreset(AssistantPresetSpec spec) =>
      _guard('Could not save the assistant', () async {
        // Validation lives in toConfigJson so a bad spec never reaches the
        // wire. Writing the file replaces `agent.<id>` wholesale, so a
        // cleared model, colour or sampling field does not linger.
        final entry = spec.toConfigJson();
        await _updateServerConfig((json) {
          _entryMap(json, 'agent')[spec.id] = entry;
        });
      });

  @override
  Future<void> removeAssistantPreset(String agentID) =>
      _guard('Could not remove the assistant', () async {
        final id = agentID.trim();
        if (id.isEmpty) {
          throw const ProductException('Enter an assistant id');
        }
        await _updateServerConfig((json) {
          _entryMap(json, 'agent').remove(id);
        });
      });

  @override
  Future<List<AssistantPresetSpec>> configuredAssistants() =>
      _guard('Could not read the assistants', () async {
        // `/config` answers `{data: [{type, path, info}]}` — one entry per
        // config document, lowest to highest priority; each `info` is that
        // document's parsed body in the server's normalized shape, where
        // the file's `agent.*` map surfaces as `agents` (`model` becomes a
        // {providerID, model} pair, `prompt` is `system`, sampling lives
        // under `request.body`, `disable` reads `disabled`). `agent` stays
        // accepted as a fallback. Entries merge the way the server does:
        // a later document wins, a `null` value deletes.
        final config = await _transport.getJson('/config', query: _loc());
        final merged = <String, Map<String, Object?>>{};
        for (final entry in _dataMaps(config)) {
          final info = entry['info'];
          final agents = info is Map ? (info['agents'] ?? info['agent']) : null;
          if (agents is! Map) continue;
          for (final agent in agents.entries) {
            final id = '${agent.key}';
            if (agent.value is Map) {
              merged[id] = (agent.value as Map).cast<String, Object?>();
            } else if (agent.value == null) {
              merged.remove(id);
            }
          }
        }
        return [
          for (final entry in merged.entries)
            AssistantPresetSpec.fromConfigJson(entry.key, entry.value),
        ];
      });
}
