part of '../library_screen.dart';

/// The assistant-preset form: it writes an `agent.<id>` entry into the
/// server's configuration through the config patch (OpenCode 2), so a
/// persona bundling its own model, sampling params and system prompt
/// appears in the agent picker — the same way assistants work in
/// client-side agent apps, here backed by the server's own config so the
/// desktop CLI sees them too.
///
/// Saving the same id rewrites the whole entry.
class _AssistantPresetSheet extends StatefulWidget {
  const _AssistantPresetSheet({required this.controller, this.existing});

  final ConnectionController controller;

  /// The config entry being edited; null authors a new assistant.
  final AssistantPresetSpec? existing;

  @override
  State<_AssistantPresetSheet> createState() => _AssistantPresetSheetState();
}

class _AssistantPresetSheetState extends State<_AssistantPresetSheet> {
  late final TextEditingController _id = TextEditingController(
    text: widget.existing?.id ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.existing?.model ?? '',
  );
  late final TextEditingController _prompt = TextEditingController(
    text: widget.existing?.prompt ?? '',
  );
  late final TextEditingController _temperature = TextEditingController(
    text: widget.existing?.temperature?.toString() ?? '',
  );
  late final TextEditingController _topP = TextEditingController(
    text: widget.existing?.topP?.toString() ?? '',
  );
  late final TextEditingController _color = TextEditingController(
    text: widget.existing?.color ?? '',
  );

  String _mode = 'primary';
  bool _saving = false;
  bool _showErrors = false;
  String? _error;

  /// The location the sheet was opened on; the controller's own scope
  /// check refuses the write if the person moved elsewhere meanwhile.
  late final int _location = widget.controller.locationRevision;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    final mode = widget.existing?.mode;
    if (mode == 'subagent' || mode == 'all') _mode = mode!;
  }

  String? get _idError {
    final id = _id.text.trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9-_]{0,62}$').hasMatch(id)) {
      return _l10n.assistantErrorId;
    }
    return null;
  }

  String? get _promptError =>
      _prompt.text.trim().isEmpty ? _l10n.assistantErrorPrompt : null;

  String? get _modelError {
    final model = _model.text.trim();
    if (model.isNotEmpty && !model.contains('/')) {
      return _l10n.assistantErrorModel;
    }
    return null;
  }

  String? get _temperatureError {
    final raw = _temperature.text.trim();
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value < 0 || value > 2) {
      return _l10n.assistantErrorTemperature;
    }
    return null;
  }

  String? get _topPError {
    final raw = _topP.text.trim();
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value <= 0 || value > 1) {
      return _l10n.assistantErrorTopP;
    }
    return null;
  }

  String? get _colorError {
    final raw = _color.text.trim();
    if (raw.isNotEmpty && !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(raw)) {
      return _l10n.assistantErrorColor;
    }
    return null;
  }

  double? get _temperatureValue {
    final raw = _temperature.text.trim();
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  double? get _topPValue {
    final raw = _topP.text.trim();
    return raw.isEmpty ? null : double.tryParse(raw);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _showErrors = true;
      _error = null;
    });
    if (_idError != null ||
        _promptError != null ||
        _modelError != null ||
        _temperatureError != null ||
        _topPError != null ||
        _colorError != null) {
      return;
    }
    final l10n = _l10n;
    final spec = AssistantPresetSpec(
      id: _id.text.trim(),
      description: _description.text.trim(),
      mode: _mode,
      model: _model.text.trim().isEmpty ? null : _model.text.trim(),
      prompt: _prompt.text,
      temperature: _temperatureValue,
      topP: _topPValue,
      color: _color.text.trim().isEmpty ? null : _color.text.trim(),
    );
    setState(() => _saving = true);
    try {
      await widget.controller.importAssistantPreset(
        spec,
        locationRevision: _location,
      );
      if (!mounted) return;
      Navigator.of(context).pop(spec.id);
    } on ProductException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.assistantSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _description.dispose();
    _model.dispose();
    _prompt.dispose();
    _temperature.dispose();
    _topP.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final tokens = KitTokens.of(context);
    final gap = SizedBox(height: tokens.space3);
    final editing = widget.existing != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitText(
          l10n.assistantSheetIntro,
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        gap,
        if (_error case final error?) ...[
          KitNotice(
            key: const ValueKey('assistant-error'),
            tone: AppStatusTone.failure,
            message: error,
          ),
          gap,
        ],
        KitField(
          fieldKey: const ValueKey('assistant-id'),
          label: l10n.assistantIdField,
          controller: _id,
          kind: KitFieldKind.mono,
          hint: 'code-reviewer',
          helper: editing ? null : l10n.assistantIdHelper,
          error: _showErrors ? _idError : null,
          // The id is the config key: renaming would orphan the entry.
          enabled: !_saving && !editing,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('assistant-description'),
          label: l10n.assistantDescriptionField,
          controller: _description,
          hint: l10n.assistantDescriptionHint,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitText(
          l10n.assistantModeLabel,
          role: KitTextRole.secondary,
          tone: KitTextTone.secondary,
        ),
        SizedBox(height: tokens.space2),
        KitSegmented<String>(
          segments: [
            KitSegment(value: 'primary', label: l10n.assistantModePrimary),
            KitSegment(value: 'subagent', label: l10n.assistantModeSubagent),
            KitSegment(value: 'all', label: l10n.assistantModeAll),
          ],
          selected: _mode,
          semanticsLabel: l10n.assistantModeLabel,
          onChanged: _saving ? null : (value) => setState(() => _mode = value),
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('assistant-model'),
          label: l10n.assistantModelField,
          controller: _model,
          kind: KitFieldKind.mono,
          hint: 'anthropic/claude-sonnet-4-5',
          helper: l10n.assistantModelHelper,
          error: _showErrors ? _modelError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('assistant-prompt'),
          label: l10n.assistantPromptField,
          controller: _prompt,
          kind: KitFieldKind.multiline,
          hint: l10n.assistantPromptHint,
          error: _showErrors ? _promptError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('assistant-temperature'),
          label: l10n.assistantTemperatureField,
          controller: _temperature,
          hint: '0.7',
          helper: l10n.assistantTemperatureHelper,
          error: _showErrors ? _temperatureError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('assistant-top-p'),
          label: l10n.assistantTopPField,
          controller: _topP,
          hint: '0.9',
          helper: l10n.assistantTopPHelper,
          error: _showErrors ? _topPError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitField(
          fieldKey: const ValueKey('assistant-color'),
          label: l10n.assistantColorField,
          controller: _color,
          kind: KitFieldKind.mono,
          hint: '#A64F2E',
          helper: l10n.assistantColorHelper,
          error: _showErrors ? _colorError : null,
          enabled: !_saving,
          disabledReason: _saving ? l10n.e7LibraryUpdating : null,
        ),
        gap,
        KitButton.primary(
          key: const ValueKey('assistant-save'),
          label: editing ? l10n.assistantSaveChanges : l10n.assistantSave,
          working: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
