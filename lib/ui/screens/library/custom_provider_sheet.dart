part of '../library_screen.dart';

/// The custom-API form: it writes a `provider.<id>` entry into the
/// server's configuration through the config patch (OpenCode 2), so an
/// endpoint the server does not ship — OpenRouter, DeepSeek, vLLM, LM
/// Studio, any OpenAI- or Anthropic-compatible gateway — appears in the
/// catalog and the model picker.
///
/// The API key is write-only: it goes straight into the patch body and
/// into the server's config file, and it is never shown, kept in a draft,
/// or logged (SEC-3). Saving the same id rewrites the whole entry, so the
/// sheet says the key must be entered again.
class _CustomProviderSheet extends StatefulWidget {
  const _CustomProviderSheet({required this.controller});

  final ConnectionController controller;

  @override
  State<_CustomProviderSheet> createState() => _CustomProviderSheetState();
}

class _CustomProviderSheetState extends State<_CustomProviderSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _id = TextEditingController();
  final TextEditingController _baseURL = TextEditingController();
  final TextEditingController _key = TextEditingController();
  final TextEditingController _models = TextEditingController();
  final TextEditingController _headers = TextEditingController();
  final TextEditingController _context = TextEditingController();
  final TextEditingController _input = TextEditingController();
  final TextEditingController _output = TextEditingController();

  String _protocol = CustomProviderSpec.openAICompatibleNpm;
  bool _reasoning = false;
  String? _defaultEffort;
  bool _setDefault = false;
  bool _saving = false;
  bool _showErrors = false;
  String? _error;

  /// The location the sheet was opened on; the controller's own scope
  /// check refuses the write if the person moved elsewhere meanwhile.
  late final int _location = widget.controller.locationRevision;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  /// The five wire tiers read as friendly words in the picker.
  String _effortLabel(AppLocalizations l10n, String tier) => switch (tier) {
    'none' => l10n.customProviderEffortNone,
    'low' => l10n.customProviderEffortLow,
    'medium' => l10n.customProviderEffortMedium,
    'high' => l10n.customProviderEffortHigh,
    'xhigh' => l10n.customProviderEffortXhigh,
    _ => tier,
  };

  List<String> get _modelIDs => _models.text
      .split(RegExp(r'[\s,]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .toList(growable: false);

  Map<String, String> get _headerMap {
    final headers = <String, String>{};
    for (final line in _headers.text.split('\n')) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final name = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (name.isNotEmpty) headers[name] = value;
    }
    return headers;
  }

  String? get _idError {
    final id = _id.text.trim();
    if (id.isEmpty) return _l10n.customProviderErrorId;
    if (!RegExp(r'^[a-z0-9][a-z0-9-_]{0,62}$').hasMatch(id)) {
      return _l10n.customProviderErrorId;
    }
    return null;
  }

  String? get _urlError {
    final uri = Uri.tryParse(_baseURL.text.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return _l10n.customProviderErrorUrl;
    }
    return null;
  }

  String? get _modelsError =>
      _modelIDs.isEmpty ? _l10n.customProviderErrorModels : null;

  /// A numeric token field: empty is fine (the server default holds),
  /// anything typed must be a positive whole number.
  int? _limitOf(TextEditingController field) {
    final text = field.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  bool get _limitsValid {
    for (final field in [_context, _input, _output]) {
      final text = field.text.trim();
      if (text.isNotEmpty &&
          (_limitOf(field) == null || _limitOf(field)! <= 0)) {
        return false;
      }
    }
    return true;
  }

  String? get _limitsError {
    if (!_limitsValid) return _l10n.customProviderErrorLimit;
    // The server's `limit` object takes context+output as a pair.
    if ((_context.text.trim().isEmpty) != (_output.text.trim().isEmpty)) {
      return _l10n.customProviderErrorLimitPair;
    }
    final context = _limitOf(_context);
    final input = _limitOf(_input);
    if (context != null && input != null && input > context) {
      return _l10n.customProviderErrorLimitInput;
    }
    return null;
  }

  String? get _headersError {
    // Every non-empty line must read "Name: value" or the person sees a
    // header that silently never reached the server.
    for (final line in _headers.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final separator = line.indexOf(':');
      if (separator <= 0 || line.substring(0, separator).trim().isEmpty) {
        return _l10n.customProviderErrorHeaders;
      }
    }
    return null;
  }

  /// An empty id follows the display name so the common case needs one
  /// field less; typing in the id field takes over.
  void _suggestId() {
    if (_id.text.trim().isNotEmpty) return;
    final suggestion = _name.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (suggestion.isNotEmpty) {
      _id.value = TextEditingValue(
        text: suggestion,
        selection: TextSelection.collapsed(offset: suggestion.length),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _showErrors = true;
      _error = null;
    });
    if (_idError != null ||
        _urlError != null ||
        _modelsError != null ||
        _headersError != null ||
        _limitsError != null) {
      return;
    }
    final l10n = _l10n;
    final spec = CustomProviderSpec(
      id: _id.text.trim(),
      name: _name.text.trim(),
      baseURL: _baseURL.text.trim(),
      apiKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
      models: _modelIDs,
      npm: _protocol,
      headers: _headerMap,
      contextLimit: _limitOf(_context),
      inputLimit: _limitOf(_input),
      outputLimit: _limitOf(_output),
      reasoning: _reasoning,
      defaultEffort: _reasoning ? _defaultEffort : null,
    );
    setState(() => _saving = true);
    try {
      await widget.controller.importCustomProvider(
        spec,
        defaultModelID: _setDefault ? _modelIDs.first : null,
        locationRevision: _location,
      );
      if (!mounted) return;
      Navigator.of(context).pop(spec.name.isEmpty ? spec.id : spec.name);
    } on ProductException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.customProviderSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(_suggestId);
  }

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _baseURL.dispose();
    _key.dispose();
    _models.dispose();
    _headers.dispose();
    _context.dispose();
    _input.dispose();
    _output.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final tokens = KitTokens.of(context);
    final gap = SizedBox(height: tokens.space3);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitText(
          l10n.customProviderSheetIntro,
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        gap,
        if (_error case final error?) ...[
          KitNotice(
            key: const ValueKey('custom-provider-error'),
            tone: AppStatusTone.failure,
            message: error,
          ),
          gap,
        ],
        KitField(
          fieldKey: const ValueKey('custom-provider-name'),
          label: l10n.customProviderNameField,
          controller: _name,
          hint: 'DeepSeek',
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('custom-provider-id'),
          label: l10n.customProviderIdField,
          controller: _id,
          kind: KitFieldKind.mono,
          hint: 'deepseek',
          helper: l10n.customProviderIdHelper,
          error: _showErrors ? _idError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('custom-provider-base-url'),
          label: l10n.customProviderBaseUrlField,
          controller: _baseURL,
          kind: KitFieldKind.url,
          hint: 'https://api.deepseek.com/v1',
          error: _showErrors ? _urlError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField.secret(
          fieldKey: const ValueKey('custom-provider-key'),
          label: l10n.customProviderKeyField,
          controller: _key,
          helper: l10n.customProviderKeyHelper,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('custom-provider-models'),
          label: l10n.customProviderModelsField,
          controller: _models,
          kind: KitFieldKind.multiline,
          hint: 'deepseek-chat\ndeepseek-reasoner',
          helper: l10n.customProviderModelsHelper,
          error: _showErrors ? _modelsError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('custom-provider-context'),
          label: l10n.customProviderContextField,
          controller: _context,
          kind: KitFieldKind.number,
          hint: '512000',
          helper: l10n.customProviderLimitsHelper,
          error: _showErrors ? _limitsError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('custom-provider-output'),
          label: l10n.customProviderOutputField,
          controller: _output,
          kind: KitFieldKind.number,
          hint: '64000',
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('custom-provider-input'),
          label: l10n.customProviderInputField,
          controller: _input,
          kind: KitFieldKind.number,
          hint: '448000',
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('custom-provider-headers'),
          label: l10n.customProviderHeadersField,
          controller: _headers,
          kind: KitFieldKind.multiline,
          hint: 'X-Title: HaizhuCode',
          helper: l10n.customProviderHeadersHelper,
          error: _showErrors ? _headersError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitText(
          l10n.customProviderProtocolLabel,
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        SizedBox(height: tokens.space2),
        KitSegmented<String>(
          segments: [
            KitSegment(
              value: CustomProviderSpec.openAICompatibleNpm,
              label: l10n.customProviderProtocolOpenAI,
            ),
            KitSegment(
              value: CustomProviderSpec.anthropicNpm,
              label: l10n.customProviderProtocolAnthropic,
            ),
          ],
          selected: _protocol,
          semanticsLabel: l10n.customProviderProtocolLabel,
          onChanged: _saving
              ? null
              : (value) => setState(() => _protocol = value),
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitRowGroup(
          margin: EdgeInsets.zero,
          children: [
            KitSwitchRow(
              title: l10n.customProviderThinking,
              supporting: l10n.customProviderThinkingHint,
              value: _reasoning,
              switchKey: const ValueKey('custom-provider-thinking'),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _reasoning = value),
              disabledReason: _saving ? l10n.e7LibraryUpdating : null,
            ),
            if (_reasoning)
              KitPickerRow<String>(
                title: l10n.customProviderDefaultEffort,
                rowKey: const ValueKey('custom-provider-effort'),
                choices: [
                  KitChoice(value: '', title: l10n.customProviderEffortServer),
                  for (final tier in CustomProviderSpec.reasoningEffortTiers)
                    KitChoice(value: tier, title: _effortLabel(l10n, tier)),
                ],
                selected: _defaultEffort ?? '',
                onSelected: _saving
                    ? null
                    : (value) => setState(
                        () => _defaultEffort = value.isEmpty ? null : value,
                      ),
                disabledReason: _saving ? l10n.e7LibraryUpdating : null,
              ),
            KitSwitchRow(
              title: l10n.customProviderSetDefault,
              supporting: l10n.customProviderSetDefaultHint,
              value: _setDefault,
              switchKey: const ValueKey('custom-provider-default'),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _setDefault = value),
              disabledReason: _saving ? l10n.e7LibraryUpdating : null,
            ),
          ],
        ),
        gap,
        KitButton.primary(
          key: const ValueKey('custom-provider-save'),
          label: l10n.customProviderSave,
          working: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
