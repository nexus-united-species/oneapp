// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/features/governance/cell_member.dart';
import 'package:nexus_oneapp/features/governance/cell_service.dart';
import 'package:nexus_oneapp/features/governance/delegate_select_sheet.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _cellId = 'cell_delegate_sheet_test';
const _myDid = 'did:key:z6MkMyself0000000000';
const _memberA = 'did:key:z6MkAAAAAAAAAAAAAAAAAAA';
const _memberB = 'did:key:z6MkBBBBBBBBBBBBBBBBBBB';
const _pendingDid = 'did:key:z6MkPending000000000000';

// ── Helpers ───────────────────────────────────────────────────────────────────

CellMember _confirmed(String did) => CellMember(
      cellId: _cellId,
      did: did,
      joinedAt: DateTime.utc(2026),
      role: MemberRole.member,
      confirmedBy: _myDid,
    );

CellMember _pending(String did) => CellMember(
      cellId: _cellId,
      did: did,
      joinedAt: DateTime.utc(2026),
      role: MemberRole.pending,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() => CellService.instance.clearForTest());
  tearDown(() => CellService.instance.clearForTest());

  testWidgets(
      'DelegateSelectSheet zeigt bestätigte Mitglieder außer dem User selbst',
      (tester) async {
    CellService.instance.addMemberForTest(_cellId, _confirmed(_myDid));
    CellService.instance.addMemberForTest(_cellId, _confirmed(_memberA));
    CellService.instance.addMemberForTest(_cellId, _confirmed(_memberB));

    await tester.pumpWidget(_wrap(
      DelegateSelectSheet(cellId: _cellId, myDid: _myDid),
    ));
    await tester.pump();

    // Two confirmed members other than self.
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('DelegateSelectSheet filtert PENDING-Mitglieder',
      (tester) async {
    CellService.instance.addMemberForTest(_cellId, _confirmed(_myDid));
    CellService.instance.addMemberForTest(_cellId, _confirmed(_memberA));
    CellService.instance.addMemberForTest(_cellId, _pending(_pendingDid));

    await tester.pumpWidget(_wrap(
      DelegateSelectSheet(cellId: _cellId, myDid: _myDid),
    ));
    await tester.pump();

    // Only one confirmed candidate (not myself, not pending).
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets(
      'DelegateSelectSheet zeigt Empty-State bei nur einem Mitglied (User selbst)',
      (tester) async {
    CellService.instance.addMemberForTest(_cellId, _confirmed(_myDid));

    await tester.pumpWidget(_wrap(
      DelegateSelectSheet(cellId: _cellId, myDid: _myDid),
    ));
    await tester.pump();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Keine Cell-Mitglieder verfügbar.'), findsOneWidget);
    expect(
      find.textContaining('mindestens ein weiteres Cell-Mitglied'),
      findsOneWidget,
    );
  });

  testWidgets('Tap auf Mitglied öffnet Bestätigungs-Dialog', (tester) async {
    CellService.instance.addMemberForTest(_cellId, _confirmed(_myDid));
    CellService.instance.addMemberForTest(_cellId, _confirmed(_memberA));

    await tester.pumpWidget(_wrap(
      DelegateSelectSheet(cellId: _cellId, myDid: _myDid),
    ));
    await tester.pump();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Stimme delegieren?'), findsOneWidget);
    expect(find.text('Delegieren'), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
  });

  testWidgets(
      'Abbruch im Bestätigungs-Dialog schließt nur den Dialog, Sheet bleibt offen',
      (tester) async {
    CellService.instance.addMemberForTest(_cellId, _confirmed(_myDid));
    CellService.instance.addMemberForTest(_cellId, _confirmed(_memberA));

    await tester.pumpWidget(_wrap(
      DelegateSelectSheet(cellId: _cellId, myDid: _myDid),
    ));
    await tester.pump();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    // Dialog gone, sheet (ListTile) still visible.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('Bestätigung schließt Sheet und gibt Member-DID zurück',
      (tester) async {
    CellService.instance.addMemberForTest(_cellId, _confirmed(_myDid));
    CellService.instance.addMemberForTest(_cellId, _confirmed(_memberA));

    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () async {
            result = await DelegateSelectSheet.show(
              ctx,
              cellId: _cellId,
              myDid: _myDid,
            );
          },
          child: const Text('Open'),
        );
      }),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Sheet is open — tap the single candidate.
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    // Confirm the dialog.
    await tester.tap(find.text('Delegieren'));
    await tester.pumpAndSettle();

    expect(result, equals(_memberA));
  });
}
