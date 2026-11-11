import '../../domain/models.dart';

class ExperimentalServerCapabilities {
  final bool backgroundSubagents;

  const ExperimentalServerCapabilities({required this.backgroundSubagents});
}

/// Runtime permission on v1; the v2 session protocol supports both kinds.
enum BackgroundWorkSupport { unavailable, subagents, subagentsAndShells }

/// v2 acknowledges the request with 204, which can also mean an idle no-op.
/// Only v1's true response confirms that something was promoted.
enum BackgroundWorkResult { promoted, unchanged, requested }

class CodingToolInfo {
  final String id;
  final String description;
  final Object? parameters;

  const CodingToolInfo({
    required this.id,
    required this.description,
    required this.parameters,
  });
}

class ChatDefaults {
  final ModelRef? model;
  final String? agent;

  const ChatDefaults({this.model, this.agent});
}

class McpServerInfo {
  final String name;
  final String status;
  final String? error;

  const McpServerInfo({required this.name, required this.status, this.error});
}

enum McpServerKind { remote, local }

enum McpConfigScope { project, global, runtimeLocation }

class McpServerDraft {
  final String name;
  final McpServerKind kind;
  final String? url;
  final List<String> command;
  final String? cwd;
  final Map<String, String> headers;
  final Map<String, String> environment;
  final bool detectOAuth;
  final int? timeoutMs;

  const McpServerDraft({
    required this.name,
    required this.kind,
    this.url,
    this.command = const [],
    this.cwd,
    this.headers = const {},
    this.environment = const {},
    this.detectOAuth = true,
    this.timeoutMs,
  });

  String get normalizedName => name.trim();

  Map<String, Object?> toConfigJson() {
    final serverName = normalizedName;
    if (serverName.isEmpty || serverName.contains(RegExp(r'[\r\n]'))) {
      throw const ProductException('Enter a valid MCP server name');
    }
    final timeout = timeoutMs;
    if (timeout != null && timeout <= 0) {
      throw const ProductException('MCP timeout must be greater than zero');
    }
    switch (kind) {
      case McpServerKind.remote:
        final value = url?.trim() ?? '';
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !uri.hasScheme ||
            !uri.hasAuthority ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            uri.userInfo.isNotEmpty) {
          throw const ProductException(
            'Enter an HTTP or HTTPS MCP server URL without credentials',
          );
        }
        _validatePairs(headers, 'HTTP header');
        return {
          'type': 'remote',
          'url': uri.toString(),
          if (headers.isNotEmpty) 'headers': Map.of(headers),
          if (!detectOAuth) 'oauth': false,
          'timeout': ?timeout,
        };
      case McpServerKind.local:
        final parts = command.map((part) => part.trim()).toList();
        if (parts.isEmpty || parts.any((part) => part.isEmpty)) {
          throw const ProductException(
            'Enter the local command and each argument on its own line',
          );
        }
        _validatePairs(environment, 'environment variable');
        return {
          'type': 'local',
          'command': parts,
          if (cwd?.trim().isNotEmpty == true) 'cwd': cwd!.trim(),
          if (environment.isNotEmpty) 'environment': Map.of(environment),
          'timeout': ?timeout,
        };
    }
  }

  static void _validatePairs(Map<String, String> values, String label) {
    for (final entry in values.entries) {
      if (entry.key.trim().isEmpty ||
          entry.key.contains(RegExp(r'[\r\n=]')) ||
          entry.value.contains(RegExp(r'[\r\n]'))) {
        throw ProductException('Enter a valid $label name and value');
      }
    }
  }
}

class McpResourceInfo {
  final String name;
  final String server;
  final String uri;
  final String? description;
  final String? mimeType;

  const McpResourceInfo({
    required this.name,
    required this.server,
    required this.uri,
    this.description,
    this.mimeType,
  });
}

class IntegrationInfo {
  final String id;
  final String name;
  final List<IntegrationMethodInfo> methods;
  final List<IntegrationConnectionInfo> connections;
  final int connectionCount;

  const IntegrationInfo({
    required this.id,
    required this.name,
    required this.methods,
    this.connections = const [],
    required this.connectionCount,
  });

  List<String> get credentialIDs => connections
      .where((connection) => connection.type == 'credential')
      .map((connection) => connection.id)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  bool get hasEnvironmentConnection =>
      connections.any((connection) => connection.type == 'env');
}

class IntegrationConnectionInfo {
  final String type;
  final String? id;
  final String label;

  const IntegrationConnectionInfo({
    required this.type,
    this.id,
    required this.label,
  });
}

class IntegrationMethodInfo {
  final String type;
  final String? id;
  final String label;
  final List<Map<String, dynamic>> prompts;
  final List<String> environmentNames;

  /// Answers the server fixed itself (OpenCode 2 hidden form fields with a
  /// default, such as the Console address); sent with every start, never
  /// asked.
  final Map<String, String> presetAnswers;

  const IntegrationMethodInfo({
    required this.type,
    this.id,
    required this.label,
    this.prompts = const [],
    this.environmentNames = const [],
    this.presetAnswers = const {},
  });
}

/// A provider the server does not know: the app writes its entry into
/// `opencode.json` (`provider.<id>`) so the catalog starts serving its
/// models. [apiKey] is write-only — the server never returns it and the
/// app never asks for it back; leaving it null keeps the stored key.
class CustomProviderSpec {
  /// The `provider.<id>` key and the wire id the models hang under.
  final String id;

  /// Display name; empty falls back to [id] on the server.
  final String name;

  /// The endpoint the adapter calls (`options.baseURL` in the config).
  final String baseURL;

  /// The key stored in the provider's `options.apiKey`; never read back.
  /// Null or blank writes the placeholder `'none'` — the OpenAI-compatible
  /// adapter refuses an empty key, so an unauthenticated endpoint (a
  /// loopback gateway) still needs a string. Replacing a provider always
  /// rewrites its key, so the form asks for it again.
  final String? apiKey;

  /// Model wire ids this endpoint serves (`models.<id>` entries).
  final List<String> models;

  /// The AI SDK package that speaks to the endpoint (`npm` in the
  /// config). Defaults to the OpenAI-compatible adapter.
  final String npm;

  /// Extra HTTP headers merged into `options.headers`.
  final Map<String, String> headers;

  /// The model's total context window (`limit.context`). Without it the
  /// server falls back to 200k for every custom model, so the usage
  /// meter and truncation planning lie for anything bigger or smaller.
  final int? contextLimit;

  /// `limit.output` — the maximum the model may emit per reply. Written
  /// whenever [contextLimit] is set: the server's `limit` object requires
  /// the pair.
  final int? outputLimit;

  /// `limit.input` — the prompt-side ceiling when it differs from the
  /// window (the window counts input + output + thinking). Optional.
  final int? inputLimit;

  /// Marks the models as reasoning-capable (`reasoning: true`) and
  /// declares the five-tier effort picker — [reasoningEffortTiers] —
  /// so the variant control offers off/low/medium/high/max instead of
  /// the server's built-in three.
  final bool reasoning;

  /// The effort the model defaults to when the chat sends no variant:
  /// `options.reasoningEffort`. Null leaves the server/model default.
  /// Ignored unless [reasoning] is on.
  final String? defaultEffort;

  const CustomProviderSpec({
    required this.id,
    required this.name,
    required this.baseURL,
    required this.models,
    this.apiKey,
    this.npm = openAICompatibleNpm,
    this.headers = const {},
    this.contextLimit,
    this.outputLimit,
    this.inputLimit,
    this.reasoning = false,
    this.defaultEffort,
  });

  /// The adapter for endpoints that speak `/v1/chat/completions` (also
  /// `/v1/responses` when the gateway supports it): OpenRouter, DeepSeek,
  /// vLLM, LM Studio, and OpenAI-compatible gateways generally.
  static const openAICompatibleNpm = '@ai-sdk/openai-compatible';

  /// The adapter for endpoints that speak Anthropic's `/v1/messages`.
  static const anthropicNpm = '@ai-sdk/anthropic';

  /// The five effort tiers the variant picker offers on reasoning models,
  /// matching the catalog convention (off → max). Each variant carries its
  /// `reasoningEffort` so the wire call maps the pick to the adapter param.
  static const reasoningEffortTiers = [
    'none',
    'low',
    'medium',
    'high',
    'xhigh',
  ];

  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9-_]{0,62}$');
  static final _modelPattern = RegExp(r'^[A-Za-z0-9._:/-]+$');

  /// The `provider.<id>` config value the patch writes.
  Map<String, Object?> toConfigJson() {
    final providerID = id.trim();
    if (!_idPattern.hasMatch(providerID)) {
      throw const ProductException(
        'Enter a provider id in lowercase letters, digits, dashes',
      );
    }
    final uri = Uri.tryParse(baseURL.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const ProductException('Enter an HTTP or HTTPS API base URL');
    }
    final modelIDs = <String>{
      for (final model in models)
        if (model.trim().isNotEmpty) model.trim(),
    };
    if (modelIDs.isEmpty ||
        modelIDs.any((model) => !_modelPattern.hasMatch(model))) {
      throw const ProductException('Enter at least one valid model id');
    }
    for (final entry in headers.entries) {
      if (entry.key.trim().isEmpty ||
          entry.key.contains(RegExp(r'[\r\n=]')) ||
          entry.value.contains(RegExp(r'[\r\n]'))) {
        throw const ProductException(
          'Enter a valid HTTP header name and value',
        );
      }
    }
    // The server's `limit` object requires context+output together, so the
    // pair is all-or-nothing; `input` rides along as the optional third.
    final context = contextLimit;
    final output = outputLimit;
    final input = inputLimit;
    for (final limit in [context, output, input]) {
      if (limit != null && limit <= 0) {
        throw const ProductException(
          'Token limits must be positive whole numbers',
        );
      }
    }
    if ((context == null) != (output == null)) {
      throw const ProductException(
        'Fill in both the context window and the max output',
      );
    }
    if (context != null && input != null && input > context) {
      throw const ProductException(
        'Max input cannot exceed the context window',
      );
    }
    final effort = defaultEffort?.trim();
    if (effort != null &&
        effort.isNotEmpty &&
        !reasoningEffortTiers.contains(effort)) {
      throw const ProductException('Pick one of the five effort tiers');
    }
    // Every declared model gets the same limits/variants: the form is
    // provider-wide, per-model tuning stays a config-file edit.
    Map<String, Object?> modelEntry() => <String, Object?>{
      if (context != null)
        'limit': {
          'context': context,
          'output': output,
          'input': ?input,
        },
      if (reasoning) ...{
        'reasoning': true,
        'variants': {
          for (final tier in reasoningEffortTiers)
            tier: {'reasoningEffort': tier},
        },
        if (effort != null && effort.isNotEmpty)
          'options': {'reasoningEffort': effort},
      },
    };
    final key = apiKey;
    return {
      if (npm.trim().isNotEmpty) 'npm': npm.trim(),
      if (name.trim().isNotEmpty) 'name': name.trim(),
      'options': {
        'baseURL': uri.toString(),
        // The OpenAI-compatible adapter refuses an empty key; a loopback
        // or unauthenticated endpoint still gets a placeholder string.
        'apiKey': (key == null || key.trim().isEmpty) ? 'none' : key.trim(),
        if (headers.isNotEmpty) 'headers': Map.of(headers),
      },
      'models': {for (final model in modelIDs) model: modelEntry()},
    };
  }
}

/// An assistant preset: a named agent the app writes into the server's
/// configuration (`agent.<id>`), after which the agent picker offers it like
/// any built-in agent. The shape mirrors the client-side assistants other
/// agent apps ship — a persona bundling its own model, sampling params and
/// system prompt — flattened onto the keys OpenCode's `agent` config takes.
class AssistantPresetSpec {
  /// The `agent.<id>` key; also the id the picker shows.
  final String id;

  /// `agent.<id>.description` — the picker's one-line summary.
  final String description;

  /// `agent.<id>.mode`: `primary`, `subagent` or `all`.
  final String mode;

  /// `agent.<id>.model` (`provider/model`); null keeps the server's default.
  final String? model;

  /// `agent.<id>.prompt` — the system prompt body.
  final String prompt;

  /// `agent.<id>.temperature` / `top_p`; null leaves the server defaults.
  final double? temperature;
  final double? topP;

  /// `agent.<id>.color` (hex `#RRGGBB`) — the picker's swatch; null keeps the
  /// server-chosen colour.
  final String? color;

  /// `agent.<id>.disable` — kept in config but hidden from the picker.
  final bool disable;

  const AssistantPresetSpec({
    required this.id,
    required this.description,
    required this.prompt,
    this.mode = 'primary',
    this.model,
    this.temperature,
    this.topP,
    this.color,
    this.disable = false,
  });

  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9-_]{0,62}$');
  static final _modeValues = {'primary', 'subagent', 'all'};
  static final _colorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// Reads one `agent.<id>` config entry back. Accepts both shapes: the
  /// raw file keys this spec writes, and the normalized `info.agents`
  /// entries `/config` serves (`model` as `{providerID, model}`, the
  /// prompt under `system`, sampling under `request.body`, `disabled`
  /// for `disable`).
  factory AssistantPresetSpec.fromConfigJson(
    String id,
    Map<String, Object?> json,
  ) {
    double? num_(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
    final model = json['model'];
    final request = json['request'];
    final body = request is Map ? request['body'] : null;
    final sampling = body is Map ? body : const <String, Object?>{};
    return AssistantPresetSpec(
      id: id,
      description: json['description'] as String? ?? '',
      mode: json['mode'] as String? ?? 'primary',
      model: model is Map
          ? '${model['providerID']}/${model['model']}'
          : model as String?,
      prompt: json['prompt'] as String? ?? json['system'] as String? ?? '',
      temperature: num_(json['temperature'] ?? sampling['temperature']),
      topP: num_(json['top_p'] ?? sampling['top_p']),
      color: json['color'] as String?,
      disable: json['disable'] == true || json['disabled'] == true,
    );
  }

  /// The `agent.<id>` config value the patch writes.
  Map<String, Object?> toConfigJson() {
    final agentID = id.trim();
    if (!_idPattern.hasMatch(agentID)) {
      throw const ProductException(
        'Enter an assistant id in lowercase letters, digits, dashes',
      );
    }
    if (!_modeValues.contains(mode)) {
      throw const ProductException('Choose where the assistant can run');
    }
    if (prompt.trim().isEmpty) {
      throw const ProductException('Enter the assistant instructions');
    }
    final temperature = this.temperature;
    if (temperature != null &&
        (temperature.isNaN || temperature < 0 || temperature > 2)) {
      throw const ProductException('Temperature must stay between 0 and 2');
    }
    final topP = this.topP;
    if (topP != null && (topP.isNaN || topP <= 0 || topP > 1)) {
      throw const ProductException('Top P must stay within (0, 1]');
    }
    final color = this.color;
    if (color != null && color.isNotEmpty && !_colorPattern.hasMatch(color)) {
      throw const ProductException('Colour must be #RRGGBB');
    }
    final model = this.model;
    if (model != null && model.trim().isNotEmpty && !model.contains('/')) {
      throw const ProductException('Model must look like provider/model');
    }
    return {
      if (description.trim().isNotEmpty) 'description': description.trim(),
      'mode': mode,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
      'prompt': prompt,
      'temperature': ?temperature,
      'top_p': ?topP,
      if (color != null && color.isNotEmpty) 'color': color,
      if (disable) 'disable': true,
    };
  }
}

class IntegrationAuthLaunch {
  final String attemptID;
  final String url;
  final String instructions;
  final IntegrationAuthMode mode;
  final int? expiresAt;

  const IntegrationAuthLaunch({
    required this.attemptID,
    required this.url,
    required this.instructions,
    required this.mode,
    this.expiresAt,
  });
}

enum IntegrationAuthMode { auto, code }

enum IntegrationAuthState { pending, complete, failed, expired }

class IntegrationAuthStatus {
  final IntegrationAuthState state;
  final String? message;
  final int? expiresAt;

  const IntegrationAuthStatus({
    required this.state,
    this.message,
    this.expiresAt,
  });
}

class CommandInfo {
  final String name;
  final String? description;
  final String? agent;
  final bool subtask;

  const CommandInfo({
    required this.name,
    this.description,
    this.agent,
    required this.subtask,
  });
}

class SkillInfo {
  /// Protocol identifier; display names are not necessarily valid selectors.
  final String? id;
  final String name;
  final String? description;
  final String location;
  final String content;
  final bool slashCommand;

  const SkillInfo({
    this.id,
    required this.name,
    this.description,
    required this.location,
    required this.content,
    required this.slashCommand,
  });
}

class ReferenceInfo {
  final String name;
  final String path;
  final String? description;

  const ReferenceInfo({
    required this.name,
    required this.path,
    this.description,
  });
}

class QuestionChoice {
  final String label;
  final String description;

  const QuestionChoice({required this.label, required this.description});
}

class QuestionPrompt {
  final String title;
  final String question;
  final bool multiple;
  final bool custom;

  /// The native agent permits an empty answer for this prompt.
  /// Existing OpenCode questions remain required by default.
  final bool optional;
  final List<QuestionChoice> choices;

  /// The question is Markdown (an agent's plan): drawn as formatted text.
  final bool markdown;

  const QuestionPrompt({
    required this.title,
    required this.question,
    required this.multiple,
    required this.custom,
    this.optional = false,
    this.markdown = false,
    required this.choices,
  });
}

class PendingQuestion {
  final String id;
  final String sessionID;
  final List<QuestionPrompt> prompts;

  const PendingQuestion({
    required this.id,
    required this.sessionID,
    required this.prompts,
  });

  factory PendingQuestion.fromJson(Map<String, dynamic> json) {
    final raw = json['questions'];
    return PendingQuestion(
      id: (json['id'] ?? json['requestID'] ?? '').toString(),
      sessionID: (json['sessionID'] ?? '').toString(),
      prompts: raw is List
          ? raw.whereType<Map>().map((item) {
              final value = Map<String, dynamic>.from(item);
              final options = value['options'];
              return QuestionPrompt(
                title: (value['header'] ?? 'Question').toString(),
                question: (value['question'] ?? '').toString(),
                multiple: value['multiple'] == true,
                custom: value['custom'] != false,
                optional: value['optional'] == true,
                markdown: value['markdown'] == true,
                choices: options is List
                    ? options.whereType<Map>().map((option) {
                        final choice = Map<String, dynamic>.from(option);
                        return QuestionChoice(
                          label: (choice['label'] ?? '').toString(),
                          description: (choice['description'] ?? '').toString(),
                        );
                      }).toList()
                    : const [],
              );
            }).toList()
          : const [],
    );
  }
}

abstract class TerminalChannel {
  Stream<String> get output;
  int? get cursor => null;
  void write(String value);
  Future<void> close();
}

abstract interface class LocationAwareProductRepository {
  int get locationRevision;
}

class ProductException implements Exception {
  final String message;
  final Object? cause;

  const ProductException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// A provider runtime refresh refused because replies are still running.
///
/// Refreshing an OpenCode 1 provider runtime disposes the server instance,
/// which aborts every reply running in it. Nothing was disposed; retry once
/// [runningReplies] have finished, or leave the reload to the automatic
/// retry that runs when the server goes idle.
class ProviderRuntimeBusyException extends ProductException {
  final int runningReplies;

  const ProviderRuntimeBusyException(this.runningReplies)
    : super('Providers reload after the running replies finish');
}
