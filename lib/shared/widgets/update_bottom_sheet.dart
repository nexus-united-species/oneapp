import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';
import '../theme/app_theme.dart';

/// Shows the update details bottom sheet.
///
/// Contains release notes, a "Download" button, a "Later" button and a
/// "Skip this version" button.  All three paths call [onDismiss].
Future<void> showUpdateBottomSheet(
  BuildContext context,
  UpdateInfo info,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _UpdateSheet(info: info),
  );
}

class _UpdateSheet extends StatefulWidget {
  final UpdateInfo info;

  const _UpdateSheet({required this.info});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _error;

  /// Primary action: stream-download the update file and hand it to the OS
  /// installer. Falls back to [_openInBrowser] on failure (shown as a button).
  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _error = null;
    });

    final success = await UpdateService.instance.downloadAndInstall(
      widget.info,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isDownloading = false;
        _progress = 1.0; // ensure full bar on success
      });
    } else {
      setState(() {
        _isDownloading = false;
        _error = 'Download fehlgeschlagen. Bitte erneut versuchen.';
      });
    }
  }

  /// Fallback: open the download URL in the system browser (legacy behaviour).
  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.info.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Download-Link konnte nicht geöffnet werden.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNotes = widget.info.releaseNotes.trim().isNotEmpty;
    final downloadDone = !_isDownloading && _error == null && _progress >= 1.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_outlined,
                      color: AppColors.gold, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update verfügbar',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Neue Version: ${widget.info.version}',
                        style: TextStyle(
                          color: AppColors.onDark.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Release notes ───────────────────────────────────────────────
            if (hasNotes) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.deepBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.releaseNotes,
                    style: TextStyle(
                      color: AppColors.onDark.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Download button ─────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _startDownload,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.deepBlue),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(
                _isDownloading ? 'Wird heruntergeladen...' : 'Jetzt herunterladen',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.deepBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // ── Progress bar (visible while downloading) ────────────────────
            if (_isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                // null = indeterminate when total size is unknown
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppColors.deepBlue,
                color: AppColors.gold,
              ),
            ],

            // ── Success message (after installer launched) ──────────────────
            if (downloadDone) ...[
              const SizedBox(height: 8),
              const Text(
                'Download abgeschlossen. Installation wird gestartet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontSize: 13),
              ),
            ],

            // ── Error message + browser fallback ────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
              TextButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser, size: 16),
                label: const Text('Im Browser öffnen'),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ],

            const SizedBox(height: 8),

            // ── Later ───────────────────────────────────────────────────────
            TextButton(
              // Disabled while downloading to prevent aborting mid-flight.
              onPressed: _isDownloading
                  ? null
                  : () {
                      UpdateService.instance.dismissForSession();
                      Navigator.pop(context);
                    },
              child: const Text(
                'Später',
                style: TextStyle(color: AppColors.gold),
              ),
            ),

            // ── Skip version ────────────────────────────────────────────────
            TextButton(
              // Disabled while downloading to prevent aborting mid-flight.
              onPressed: _isDownloading
                  ? null
                  : () {
                      UpdateService.instance.skipVersion(widget.info.version);
                      Navigator.pop(context);
                    },
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: Text('Version ${widget.info.version} überspringen'),
            ),
          ],
        ),
      ),
    );
  }
}
