/// Outcome of publishing a single Nostr event to the relay pool.
///
/// Returned by NostrRelayManager.publish() after relays have
/// responded with OK frames or the timeout has elapsed.
///
/// Used by governance event publishers to determine whether the
/// required ACK quorum was reached (default: 2 relays).
class RelayPublishOutcome {
  final String eventId;
  final List<String> sentToRelays;
  final List<String> acceptedRelays;
  final Map<String, String> rejections; // relayUrl → reason
  final bool timedOut;

  int get acceptedCount => acceptedRelays.length;
  int get rejectedCount => rejections.length;
  int get pendingCount =>
      sentToRelays.length - acceptedRelays.length - rejections.length;

  RelayPublishOutcome({
    required this.eventId,
    required this.sentToRelays,
    required this.acceptedRelays,
    required this.rejections,
    required this.timedOut,
  });

  @override
  String toString() =>
      'RelayPublishOutcome(eventId: ${eventId.length >= 8 ? eventId.substring(0, 8) : eventId}, '
      'sent: ${sentToRelays.length}, '
      'accepted: $acceptedCount, '
      'rejected: $rejectedCount, '
      'timedOut: $timedOut)';
}

/// Tracks the publish lifecycle of a Nostr event across relays.
///
/// Created when a governance event is published, updated as
/// relay OK/NOTICE responses arrive. Used by the retry queue
/// (Phase 1 of G2 preparation) to ensure governance events
/// reach the required relay quorum (default: 2).
///
/// Status lifecycle and column semantics: see PublishResultStatus
/// and the publish_results table schema in pod_database.dart.
class PublishResult {
  final String publishResultId;
  final String localEventId;
  final String? nostrEventId;
  final int eventKind;
  final String? proposalId;
  final String? cellId;
  final String? voteId;
  final String status;
  final int attemptedAt;
  final int? ackReceivedAt;
  final String? errorCode;
  final String? errorMessage;
  final int retryCount;
  final int? nextRetryAt;
  final int requiredAckCount;
  final int acceptedRelayCount;
  final int failedRelayCount;
  final String? finalStatus;
  final int createdAt;
  final int updatedAt;

  PublishResult({
    required this.publishResultId,
    required this.localEventId,
    this.nostrEventId,
    required this.eventKind,
    this.proposalId,
    this.cellId,
    this.voteId,
    this.status = 'PENDING',
    required this.attemptedAt,
    this.ackReceivedAt,
    this.errorCode,
    this.errorMessage,
    this.retryCount = 0,
    this.nextRetryAt,
    this.requiredAckCount = 2,
    this.acceptedRelayCount = 0,
    this.failedRelayCount = 0,
    this.finalStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PublishResult.fromMap(Map<String, dynamic> map) {
    return PublishResult(
      publishResultId: map['publish_result_id'] as String,
      localEventId: map['local_event_id'] as String,
      nostrEventId: map['nostr_event_id'] as String?,
      eventKind: map['event_kind'] as int,
      proposalId: map['proposal_id'] as String?,
      cellId: map['cell_id'] as String?,
      voteId: map['vote_id'] as String?,
      status: map['status'] as String? ?? 'PENDING',
      attemptedAt: map['attempted_at'] as int,
      ackReceivedAt: map['ack_received_at'] as int?,
      errorCode: map['error_code'] as String?,
      errorMessage: map['error_message'] as String?,
      retryCount: map['retry_count'] as int? ?? 0,
      nextRetryAt: map['next_retry_at'] as int?,
      requiredAckCount: map['required_ack_count'] as int? ?? 2,
      acceptedRelayCount: map['accepted_relay_count'] as int? ?? 0,
      failedRelayCount: map['failed_relay_count'] as int? ?? 0,
      finalStatus: map['final_status'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// Maps to SQLite row. Null values are omitted to avoid overwriting
  /// existing column data with null on partial updates.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'publish_result_id': publishResultId,
      'local_event_id': localEventId,
      'event_kind': eventKind,
      'status': status,
      'attempted_at': attemptedAt,
      'retry_count': retryCount,
      'required_ack_count': requiredAckCount,
      'accepted_relay_count': acceptedRelayCount,
      'failed_relay_count': failedRelayCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (nostrEventId != null) map['nostr_event_id'] = nostrEventId;
    if (proposalId != null) map['proposal_id'] = proposalId;
    if (cellId != null) map['cell_id'] = cellId;
    if (voteId != null) map['vote_id'] = voteId;
    if (ackReceivedAt != null) map['ack_received_at'] = ackReceivedAt;
    if (errorCode != null) map['error_code'] = errorCode;
    if (errorMessage != null) map['error_message'] = errorMessage;
    if (nextRetryAt != null) map['next_retry_at'] = nextRetryAt;
    if (finalStatus != null) map['final_status'] = finalStatus;
    return map;
  }

  PublishResult copyWith({
    String? publishResultId,
    String? localEventId,
    String? nostrEventId,
    int? eventKind,
    String? proposalId,
    String? cellId,
    String? voteId,
    String? status,
    int? attemptedAt,
    int? ackReceivedAt,
    String? errorCode,
    String? errorMessage,
    int? retryCount,
    int? nextRetryAt,
    int? requiredAckCount,
    int? acceptedRelayCount,
    int? failedRelayCount,
    String? finalStatus,
    int? createdAt,
    int? updatedAt,
  }) {
    return PublishResult(
      publishResultId: publishResultId ?? this.publishResultId,
      localEventId: localEventId ?? this.localEventId,
      nostrEventId: nostrEventId ?? this.nostrEventId,
      eventKind: eventKind ?? this.eventKind,
      proposalId: proposalId ?? this.proposalId,
      cellId: cellId ?? this.cellId,
      voteId: voteId ?? this.voteId,
      status: status ?? this.status,
      attemptedAt: attemptedAt ?? this.attemptedAt,
      ackReceivedAt: ackReceivedAt ?? this.ackReceivedAt,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      requiredAckCount: requiredAckCount ?? this.requiredAckCount,
      acceptedRelayCount: acceptedRelayCount ?? this.acceptedRelayCount,
      failedRelayCount: failedRelayCount ?? this.failedRelayCount,
      finalStatus: finalStatus ?? this.finalStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
