import 'cell_member.dart';

/// TD-33: the founder's list of all confirmed members of a cell, published
/// as Kind-31007. Members adopt it so every device knows the same members
/// and roles (new joiners used to know only the founder and themselves,
/// moderator promotions never left the founder's device).
class CellRoster {
  final String cellId;

  /// When the founder built this roster (ms). A roster only replaces a
  /// locally applied one if it is newer.
  final int updatedAtMs;
  final List<CellRosterEntry> members;

  const CellRoster({
    required this.cellId,
    required this.updatedAtMs,
    required this.members,
  });

  /// Builds the roster from [members] (confirmed only), always listing
  /// [founderDid] as founder. Sorted by DID for a stable wire format.
  factory CellRoster.fromMembers({
    required String cellId,
    required String founderDid,
    required List<CellMember> members,
    required DateTime createdAt,
    required int updatedAtMs,
  }) {
    final byDid = <String, CellRosterEntry>{};
    for (final m in members) {
      if (!m.isConfirmed) continue;
      // Exactly one founder: the cell's createdBy. A local founder role of
      // anyone else (e.g. after a device-local founder transfer, which is
      // not synced) is listed as moderator so receivers can parse it.
      final role = m.did == founderDid
          ? MemberRole.founder
          : (m.role == MemberRole.founder ? MemberRole.moderator : m.role);
      byDid[m.did] = CellRosterEntry(
        did: m.did,
        role: role,
        joinedAtMs: m.joinedAt.toUtc().millisecondsSinceEpoch,
      );
    }
    byDid.putIfAbsent(
      founderDid,
      () => CellRosterEntry(
        did: founderDid,
        role: MemberRole.founder,
        joinedAtMs: createdAt.toUtc().millisecondsSinceEpoch,
      ),
    );
    final entries = byDid.values.toList()
      ..sort((a, b) => a.did.compareTo(b.did));
    return CellRoster(
        cellId: cellId, updatedAtMs: updatedAtMs, members: entries);
  }

  Map<String, dynamic> toJson() => {
        'cellId': cellId,
        'updatedAt': updatedAtMs,
        'members': [for (final m in members) m.toJson()],
      };

  /// Parses a received roster; null if it is malformed (missing fields,
  /// duplicate DIDs, pending or unknown roles, or more than one founder).
  static CellRoster? tryParse(Map<String, dynamic> json) {
    final cellId = json['cellId'];
    final updatedAt = json['updatedAt'];
    final rawMembers = json['members'];
    if (cellId is! String || cellId.isEmpty) return null;
    if (updatedAt is! int || rawMembers is! List) return null;
    final entries = <CellRosterEntry>[];
    final seen = <String>{};
    for (final raw in rawMembers) {
      final entry = raw is Map<String, dynamic>
          ? CellRosterEntry.tryParse(raw)
          : null;
      if (entry == null || !seen.add(entry.did)) return null;
      entries.add(entry);
    }
    final founders = entries.where((e) => e.role == MemberRole.founder);
    if (founders.length != 1) return null;
    return CellRoster(
        cellId: cellId, updatedAtMs: updatedAt, members: entries);
  }

  String get founderDid =>
      members.firstWhere((e) => e.role == MemberRole.founder).did;
}

class CellRosterEntry {
  final String did;
  final MemberRole role;
  final int joinedAtMs;

  const CellRosterEntry({
    required this.did,
    required this.role,
    required this.joinedAtMs,
  });

  Map<String, dynamic> toJson() =>
      {'did': did, 'role': role.name, 'joinedAt': joinedAtMs};

  static CellRosterEntry? tryParse(Map<String, dynamic> json) {
    final did = json['did'];
    final roleName = json['role'];
    final joinedAt = json['joinedAt'];
    if (did is! String || !did.startsWith('did:')) return null;
    if (joinedAt is! int) return null;
    final role =
        MemberRole.values.where((r) => r.name == roleName).firstOrNull;
    if (role == null || role == MemberRole.pending) return null;
    return CellRosterEntry(did: did, role: role, joinedAtMs: joinedAt);
  }

  CellMember toMember(String cellId, String founderDid) => CellMember(
        cellId: cellId,
        did: did,
        joinedAt: DateTime.fromMillisecondsSinceEpoch(joinedAtMs, isUtc: true),
        role: role,
        confirmedBy: founderDid,
      );
}
