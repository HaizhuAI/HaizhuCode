import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haizhucode/domain/agent_catalog.dart';
import 'package:haizhucode/domain/phone_agent_host.dart';
import 'package:haizhucode/domain/phone_agents.dart';
import 'package:haizhucode/domain/phone_agents_source.dart';
import 'package:haizhucode/ui/screens/agents/agent_sheet.dart';
import 'package:haizhucode/ui/screens/chats/chats_host.dart';
import 'package:widgetbook/widgetbook.dart';

import '../catalog.dart';
import '../fakes/fake_app.dart';
import '../fakes/fake_chats_host.dart';

class _CheckAgents extends ChangeNotifier
    implements PhoneAgentsSource, PhoneAgentRecoverySource {
  _CheckAgents(this.failure, {this.downloading = false, this.previous});
  final AgentHostFailure? failure;
  final bool downloading;
  final String? previous;

  @override
  List<AgentRow> get agentRows => [
    buildAgentRow(
      descriptor: AgentCatalog.builtIn.byId('claude')!,
      architecture: AgentArchitecture.arm64,
      serverCapabilities: catalogServerCapabilities,
      runtime: const PhoneAgentRuntime(
        agentId: 'claude',
        installed: true,
        checkRequiredReason: 'helperVersion',
      ),
    ),
  ];

  @override
  List<ChatAgentChoice> get chatAgentChoices => const [];

  @override
  AgentSetupProgress get agentSetupProgress => AgentSetupProgress(
    agentId: 'claude',
    phase: downloading ? AgentSetupPhase.installing : AgentSetupPhase.done,
    componentId: 'agent-claude',
    downloadedBytes: 60000000,
    totalBytes: 240000000,
    checkStep: AgentPhoneCheckStep.install,
  );

  @override
  Future<void> refreshAgentRows() async {}

  @override
  Future<AgentPhoneCheckResult> runAgentPhoneCheck(String agentId) async {
    if (downloading) return Completer<AgentPhoneCheckResult>().future;
    return AgentPhoneCheckResult(
      agentId: agentId,
      architecture: AgentArchitecture.arm64,
      passed: false,
      completed: const [
        AgentPhoneCheckStep.install,
        AgentPhoneCheckStep.version,
        AgentPhoneCheckStep.daemon,
      ],
      failure: failure,
      previousVersion: previous,
      details: 'Paseo expected 0.11.2; observed 0.9.2',
    );
  }

  @override
  Future<AgentPhoneCheckResult> usePreviousAgentVersion(String agentId) =>
      runAgentPhoneCheck(agentId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CheckHost extends FakeHost {
  _CheckHost(this.phone) : super(FakeFeed());
  final _CheckAgents phone;
  @override
  PhoneAgentsSource get agents => phone;
  @override
  Listenable get listenable => phone;
}

class _CheckScene implements SceneResource {
  _CheckScene(this.app, this.agents);
  final FakeApp app;
  final _CheckAgents agents;
  @override
  void dispose() {
    agents.dispose();
    app.dispose();
  }
}

Widget _check({
  AgentHostFailure? failure,
  bool downloading = false,
  String? previous,
}) => FakeAppScene<_CheckScene>(
  platform: FakePlatform.android,
  create: () async => _CheckScene(
    await FakeApp.create(),
    _CheckAgents(failure, downloading: downloading, previous: previous),
  ),
  builder: (context, scene) => ProviderScope(
    overrides: [chatsHostProvider.overrideWithValue(_CheckHost(scene.agents))],
    child: const AgentSheet(agentId: 'claude', step: AgentSheetStep.check),
  ),
);

CatalogComponent agentPhoneCheck() => catalogComponent(
  area: 'Agents',
  screen: 'AgentSheet',
  name: 'Check this phone',
  useCases: [
    WidgetbookUseCase(
      name: 'Downloading a resumed update',
      builder: (_) => _check(downloading: true),
    ),
    WidgetbookUseCase(
      name: 'Paseo needs an update',
      builder: (_) => _check(failure: AgentHostFailure.helperVersion),
    ),
    WidgetbookUseCase(
      name: 'Sign in needed',
      builder: (_) => _check(failure: AgentHostFailure.needsSignIn),
    ),
    WidgetbookUseCase(
      name: 'Retry or use the previous version',
      builder: (_) =>
          _check(failure: AgentHostFailure.hello, previous: '2.1.283'),
    ),
  ],
);
