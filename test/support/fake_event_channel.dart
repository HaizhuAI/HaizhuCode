import 'package:haizhucode/domain/models.dart';
import 'package:haizhucode/domain/server_gateway.dart';

export 'package:haizhucode/domain/server_gateway.dart'
    show LiveEventChannel, StreamStatus;

/// Controllable event channel for controller tests, with no wire transport.
class FakeEventChannel implements LiveEventChannel {
  FakeEventChannel({
    required this.api,
    required this.onEvent,
    required this.onStatus,
    this.onError,
    this.global = false,
  });
  final ServerGateway api;
  final void Function(EventEnvelope) onEvent;
  final void Function(StreamStatus) onStatus;
  final void Function(Object)? onError;
  final bool global;
  @override
  void start() => onStatus(StreamStatus.connected);
  @override
  Future<void> dispose() async {}
}
