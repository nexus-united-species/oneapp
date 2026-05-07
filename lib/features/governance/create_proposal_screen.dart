import 'package:flutter/material.dart';

import '../../core/identity/identity_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/help_icon.dart';
import 'cell.dart';
import 'proposal_detail_screen.dart';
import 'proposal_service.dart';
import 'voting_mode.dart';

/// Category entry: (internalKey, displayLabel)
const _kCategories = [
  (null, 'Keine Kategorie'),
  ('umwelt', '🌱 Umwelt'),
  ('finanzen', '💰 Finanzen'),
  ('it', '💻 IT'),
  ('soziales', '🤝 Soziales'),
  ('gesundheit', '❤️ Gesundheit'),
  ('bildung', '📚 Bildung'),
  ('sonstiges', '📋 Sonstiges'),
];

/// Form to create a new proposal as a draft within a cell.
class CreateProposalScreen extends StatefulWidget {
  final Cell cell;
  const CreateProposalScreen({super.key, required this.cell});

  @override
  State<CreateProposalScreen> createState() => _CreateProposalScreenState();
}

class _CreateProposalScreenState extends State<CreateProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _category;
  bool _isSaving = false;

  // Phase 4.7c3: voting mode + options state
  VotingMode _votingMode = VotingMode.YES_NO_ABSTAIN;
  List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    print('[G2-UI] Creating proposal: ${_titleCtrl.text.trim()}');

    try {
      final identity = IdentityService.instance.currentIdentity!;

      // Phase 4.7c3: UI-side pre-check for SC options (service normalizes again).
      List<String> initialOptions = const <String>[];
      if (_votingMode == VotingMode.SINGLE_CHOICE) {
        initialOptions = _optionCtrls
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (initialOptions.length < 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bitte mindestens 2 Optionen angeben.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      final proposal = await ProposalService.instance.createDraft(
        cellId: widget.cell.id,
        creatorDid: identity.did,
        creatorPseudonym: identity.pseudonym,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        votingMode: _votingMode,
        initialOptionLabels: initialOptions,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entwurf gespeichert.'),
          backgroundColor: Colors.green,
        ),
      );
      print('[G2-UI] Opening detail screen for: ${proposal.id}');
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProposalDetailScreen(proposal: proposal),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDeco(String hint, {String? counterText}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.onDark.withValues(alpha: 0.4)),
        counterText: counterText,
        counterStyle:
            TextStyle(color: AppColors.onDark.withValues(alpha: 0.4)),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neuer Antrag'),
        backgroundColor: AppColors.deepBlue,
        actions: const [
          HelpIcon(contextId: 'proposal_general'),
          SizedBox(width: 8),
        ],
      ),
      backgroundColor: AppColors.deepBlue,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Cell info
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.group_work, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zelle: ${widget.cell.name}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title
            _Label('Titel *'),
            TextFormField(
              controller: _titleCtrl,
              decoration: _inputDeco('Worum geht es?'),
              style: const TextStyle(color: AppColors.onDark),
              maxLength: 100,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  Text(
                '$currentLength / ${maxLength ?? 100}',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Bitte gib einen Titel ein.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            _Label('Beschreibung *'),
            TextFormField(
              controller: _descCtrl,
              decoration:
                  _inputDeco('Beschreibe deinen Antrag genauer…'),
              style: const TextStyle(color: AppColors.onDark),
              maxLines: 8,
              maxLength: 2000,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  Text(
                '$currentLength / ${maxLength ?? 2000}',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Bitte gib eine Beschreibung ein.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            _Label('Kategorie (optional)'),
            DropdownButtonFormField<String?>(
              value: _category,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.onDark),
              decoration: _inputDeco(''),
              items: _kCategories
                  .map((e) => DropdownMenuItem<String?>(
                        value: e.$1,
                        child: Text(
                          e.$2,
                          style: const TextStyle(color: AppColors.onDark),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 16),

            // Voting mode
            _Label('Abstimmungsart'),
            DropdownButtonFormField<VotingMode>(
              value: _votingMode,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.onDark),
              decoration: _inputDeco(''),
              items: const [
                DropdownMenuItem(
                  value: VotingMode.YES_NO_ABSTAIN,
                  child: Text('Ja / Nein / Enthaltung',
                      style: TextStyle(color: AppColors.onDark)),
                ),
                DropdownMenuItem(
                  value: VotingMode.SINGLE_CHOICE,
                  child: Text('Auswahl aus Optionen',
                      style: TextStyle(color: AppColors.onDark)),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _votingMode = v);
              },
            ),
            const SizedBox(height: 16),

            // Options block — only for SINGLE_CHOICE
            if (_votingMode == VotingMode.SINGLE_CHOICE) ...[
              _Label('Optionen *'),
              for (var i = 0; i < _optionCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _optionCtrls[i],
                          decoration: _inputDeco('Option ${i + 1}'),
                          style: const TextStyle(color: AppColors.onDark),
                          maxLength: 80,
                          buildCounter: (context,
                                  {required currentLength,
                                  required isFocused,
                                  maxLength}) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                      if (_optionCtrls.length > 2) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.onDark),
                          onPressed: () => setState(() {
                            _optionCtrls.removeAt(i).dispose();
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton.icon(
                  icon: const Icon(Icons.add, color: AppColors.gold),
                  label: const Text('Option hinzufügen',
                      style: TextStyle(color: AppColors.gold)),
                  onPressed: () => setState(() {
                    _optionCtrls.add(TextEditingController());
                  }),
                ),
              ),
            ],

            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Dein Antrag wird zunächst als Entwurf gespeichert. '
                      'Erst wenn du ihn "Zur Diskussion stellst", wird er '
                      'für die anderen Mitglieder sichtbar.',
                      style: TextStyle(
                        color: AppColors.onDark.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                TextButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Abbrechen',
                    style: TextStyle(
                        color: AppColors.onDark.withValues(alpha: 0.6)),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Als Entwurf speichern',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.onDark.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
}
