import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/identity/identity_service.dart';
import '../../features/chat/chat_provider.dart';
import '../../services/backup_service.dart';
import '../../shared/theme/app_theme.dart';

/// Shown after a successful seed-phrase restore.
///
/// Searches the backup directory for files belonging to this identity and
/// offers to import them. A backup copied from another device can be picked
/// as a file (TD-58); without any backup the user continues to [/home].
class RestoreBackupScreen extends StatefulWidget {
  const RestoreBackupScreen({super.key});

  @override
  State<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends State<RestoreBackupScreen> {
  bool _searching = true;
  List<BackupFileInfo> _backups = [];
  bool _restoring = false;
  bool _picking = false;
  String? _error;
  RestoreResult? _result;

  @override
  void initState() {
    super.initState();
    _searchForBackups();
  }

  Future<void> _searchForBackups() async {
    final found = await BackupService.instance.findBackups();
    if (!mounted) return;
    // Even without a backup on this device, offer to pick one copied from
    // another device (TD-58).
    setState(() {
      _searching = false;
      _backups   = found;
    });
  }

  /// Lets the user pick a backup file, e.g. one copied from another device.
  Future<void> _pickBackupFile() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Backup-Datei auswählen (nexus_backup_….enc)',
        type: FileType.any,
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      final mnemonic = await IdentityService.instance.loadSeedPhrase();
      if (mnemonic == null) return;
      final info = await BackupService.instance.previewBackup(path, mnemonic);
      if (!mounted) return;
      if (info == null) {
        setState(() => _error =
            'Diese Datei lässt sich mit deiner Seed Phrase nicht öffnen. '
            'Sie gehört zu einer anderen Identität oder ist beschädigt.');
        return;
      }
      print('[RESTORE] Backup file picked: ${info.filename}');
      setState(() => _backups = [
            info,
            ..._backups.where((b) => b.path != info.path),
          ]);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = 'Datei nicht lesbar: $e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _restore(BackupFileInfo info) async {
    final mnemonic = await IdentityService.instance.loadSeedPhrase();
    if (mnemonic == null || !mounted) return;
    setState(() {
      _restoring = true;
      _error     = null;
    });
    final chat = mounted ? context.read<ChatProvider>() : null;
    final result = await BackupService.instance.restoreFromFile(
      info.path,
      mnemonic,
      onRestored: () async {
        print('[RESTORE] Backup applied, triggering subscription reset...');
        chat?.nostrTransport?.resetSubscriptions();
        print('[RESTORE] Subscriptions successfully reset');
      },
    );
    if (result.success && result.restoredPseudonym != null) {
      // Peers should see the name from the backup instead of the generated
      // one. Held back while the profile is still fetched from the relays.
      await chat?.nostrTransport?.republishMetadata();
    }
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _restoring = false;
        _result    = result;
      });
    } else {
      setState(() {
        _restoring = false;
        _error     = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_searching) {
      return const Scaffold(
        backgroundColor: AppColors.deepBlue,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.gold),
              SizedBox(height: 20),
              Text('Backup wird gesucht…',
                  style: TextStyle(color: AppColors.onDark)),
            ],
          ),
        ),
      );
    }

    if (_result != null) return _buildSuccess(_result!);
    return _buildFound();
  }

  Widget _buildFound() {
    if (_backups.isEmpty) return _buildNotFound();
    final best = _backups.first;
    final d    = best.createdAt;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.backup_outlined,
                  color: AppColors.gold, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Backup gefunden!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ein Backup vom $dateStr wurde gefunden.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.onDark, fontSize: 14),
              ),
              const SizedBox(height: 28),
              // Backup summary
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    _summaryRow(
                        Icons.people_outline,
                        'Kontakte',
                        '${best.contactCount}'),
                    const Divider(height: 1),
                    _summaryRow(
                        Icons.tag,
                        'Kanäle',
                        '${best.channelCount}'),
                    const Divider(height: 1),
                    _summaryRow(
                        Icons.groups_outlined,
                        'Gemeinschaften',
                        '${best.cellCount}'),
                    const Divider(height: 1),
                    _summaryRow(
                        Icons.menu_book_outlined,
                        'Grundsätze',
                        best.hasPrinciples ? '✓' : '–'),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D0000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Fehler: $_error',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _restoring ? null : () => _restore(best),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.deepBlue,
                  disabledBackgroundColor:
                      AppColors.gold.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _restoring
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.deepBlue),
                      )
                    : const Text(
                        'Backup wiederherstellen',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 10),
              _pickFileButton('Andere Backup-Datei wählen'),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _restoring ? null : () => context.go('/home'),
                child: const Text(
                  'Ohne Backup fortfahren',
                  style: TextStyle(
                    color: AppColors.onDark,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.onDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickFileButton(String label) {
    return OutlinedButton.icon(
      onPressed: _restoring || _picking ? null : _pickBackupFile,
      icon: _picking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            )
          : const Icon(Icons.folder_open_outlined),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// No backup of this identity on the device: offer to pick a file copied
  /// from another device, or continue without (TD-58).
  Widget _buildNotFound() {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.search_off_rounded,
                  color: AppColors.gold, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Kein Backup auf diesem Gerät',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kommst du von einem anderen Gerät? Kopiere die Backup-Datei '
                '(nexus_backup_….enc) hierher, zum Beispiel per USB, Cloud '
                'oder Nachricht an dich selbst, und wähle sie aus. Kontakte, '
                'Kanäle, Gemeinschaften und dein Name werden übernommen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.onDark, fontSize: 14, height: 1.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D0000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _pickFileButton('Backup-Datei auswählen'),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _picking ? null : () => context.go('/home'),
                child: const Text(
                  'Ohne Backup fortfahren',
                  style: TextStyle(
                    color: AppColors.onDark,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.onDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(RestoreResult result) {
    return Scaffold(
      backgroundColor: AppColors.deepBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.gold, size: 50),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Wiederhergestellt!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${result.restoredContacts} Kontakte, '
                '${result.restoredChannels} Kanäle und '
                '${result.restoredCells} Gemeinschaften wiederhergestellt.'
                '${result.restoredPseudonym != null ? '\nDein Name: ${result.restoredPseudonym}' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.onDark, fontSize: 15, height: 1.5),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.deepBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Zum Dashboard',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: AppColors.onDark, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
