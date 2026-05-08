import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/system_config.dart';
import '../../shared/theme/app_theme.dart';
import '../chat/chat_provider.dart';
import 'cell.dart';
import 'cell_founding_permit.dart';
import 'cell_founding_permit_service.dart';

/// Antrag-Formular für eine Zell-Gründungsfreigabe.
///
/// Nicht-Admins nutzen diesen Screen, um beim N.E.X.U.S.-Administrator
/// eine Genehmigung zum Gründen einer Zelle anzufragen.
class RequestCellPermitScreen extends StatefulWidget {
  const RequestCellPermitScreen({super.key});

  @override
  State<RequestCellPermitScreen> createState() =>
      _RequestCellPermitScreenState();
}

class _RequestCellPermitScreenState extends State<RequestCellPermitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _motivationCtrl = TextEditingController();

  CellType _cellType = CellType.thematic;
  String _category = cellCategories.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _regionCtrl.dispose();
    _motivationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Guard: admin pubkey must be configured for the request to be deliverable.
    final adminPubkey =
        SystemConfig.instance.bootstrapCellAuthors.firstOrNull;
    if (adminPubkey == null || adminPubkey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kein Administrator konfiguriert. Antrag kann nicht gesendet werden.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Create the local permit record first (sync RAM lock before any await).
    final CellFoundingPermit permit;
    try {
      permit = await CellFoundingPermitService.instance.requestPermit(
        cellType: _cellType,
        proposedName: _nameCtrl.text.trim(),
        proposedDescription:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        proposedCategory:
            _cellType == CellType.thematic ? _category : null,
        regionHint:
            _cellType == CellType.local ? _regionCtrl.text.trim() : null,
        requestMessage: _motivationCtrl.text.trim().isEmpty
            ? null
            : _motivationCtrl.text.trim(),
      );
    } on StateError catch (e) {
      print('[PERMIT] requestPermit failed: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Der Antrag konnte nicht erstellt werden, weil der '
              'Nostr-Schlüssel noch nicht bereit ist. Bitte starte die App '
              'neu oder versuche es später erneut.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    } catch (e) {
      print('[PERMIT] requestPermit unexpected error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen des Antrags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Publish via Nostr (best-effort; local record already persisted).
    final published =
        await context.read<ChatProvider>().publishPermitRequest(permit);

    if (!mounted) return;

    if (!published) {
      setState(() => _isSubmitting = false);
      // Stay on screen — the local record is intact; user can retry manually.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Antrag lokal gespeichert, konnte aber nicht gesendet werden. '
            'Bitte stelle sicher, dass du online bist und versuche es '
            'später erneut.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 6),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dein Antrag wurde gesendet.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gründungsantrag stellen'),
        backgroundColor: AppColors.deepBlue,
      ),
      backgroundColor: AppColors.deepBlue,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Cell type
            _Label('Gemeinschaftstyp *'),
            Row(
              children: [
                Expanded(
                  child: _TypeChip(
                    label: 'Lokal\n(Ort/Region)',
                    icon: Icons.location_on,
                    selected: _cellType == CellType.local,
                    onTap: () => setState(() => _cellType = CellType.local),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeChip(
                    label: 'Thematisch\n(Interessengruppe)',
                    icon: Icons.group_work,
                    selected: _cellType == CellType.thematic,
                    onTap: () =>
                        setState(() => _cellType = CellType.thematic),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Proposed name
            _Label('Vorgeschlagener Name *'),
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  _deco('z. B. Hamburg Altona oder Vegane Ernährung'),
              style: const TextStyle(color: AppColors.onDark),
              maxLength: 60,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Name ist Pflichtfeld.';
                }
                if (v.trim().length < 3) return 'Mindestens 3 Zeichen.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Short description
            _Label('Kurzbeschreibung (optional)'),
            TextFormField(
              controller: _descCtrl,
              decoration: _deco('Worum geht es in dieser Gemeinschaft?'),
              style: const TextStyle(color: AppColors.onDark),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            // Local: region hint (required)
            if (_cellType == CellType.local) ...[
              _Label('Region / Ort *'),
              TextFormField(
                controller: _regionCtrl,
                decoration:
                    _deco('z. B. Puerto de la Cruz, Teneriffa'),
                style: const TextStyle(color: AppColors.onDark),
                validator: (v) {
                  if (_cellType == CellType.local &&
                      (v == null || v.trim().isEmpty)) {
                    return 'Regions-Hinweis ist für lokale Gemeinschaften Pflichtfeld.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Thematic: category dropdown (required)
            if (_cellType == CellType.thematic) ...[
              _Label('Kategorie *'),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.onDark),
                decoration: _deco(''),
                items: cellCategories
                    .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                validator: (v) {
                  if (_cellType == CellType.thematic &&
                      (v == null || v.isEmpty)) {
                    return 'Kategorie ist Pflichtfeld.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Motivation (optional)
            _Label('Begründung / Motivation (optional)'),
            TextFormField(
              controller: _motivationCtrl,
              decoration:
                  _deco('Warum möchtest du diese Gemeinschaft gründen?'),
              style: const TextStyle(color: AppColors.onDark),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: Text(
                'Dein Antrag wird an den N.E.X.U.S.-Administrator gesendet. '
                'Nach Genehmigung erhältst du eine Freigabe und kannst die '
                'Gemeinschaft selbst auf deinem Gerät gründen.',
                style: TextStyle(
                  color: AppColors.onDark.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Gründungsantrag stellen',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
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
        errorStyle: const TextStyle(color: Colors.redAccent),
        counterStyle:
            TextStyle(color: AppColors.onDark.withValues(alpha: 0.4)),
      );
}

// ── Local widgets ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.onDark.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                selected ? AppColors.gold : AppColors.surfaceVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? AppColors.gold
                  : AppColors.onDark.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? AppColors.gold
                    : AppColors.onDark.withValues(alpha: 0.8),
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
