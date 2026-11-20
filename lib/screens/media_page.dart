import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../services/download_repository.dart';

class MediaPage extends StatefulWidget {
  final AppStrings strings;
  final DownloadRepository repo;
  final void Function(String url, String mode) onAdd;

  const MediaPage({
    super.key,
    required this.strings,
    required this.repo,
    required this.onAdd,
  });

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  bool _updating = false;

  Future<void> _updateEngine() async {
    // An update can take time. Disable repeated requests until it finishes.
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await widget.repo.updateMediaEngine();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.strings.t('engineUpdateSuccess')),
      ));
    } catch (_) {
      if (!mounted) return;
      // Extractor exceptions can contain signed URLs or local file paths.
      // Show a localized status instead of exposing raw exception details.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.strings.t('engineUpdateFailed')),
      ));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.strings.t;
    return ListView(padding: const EdgeInsets.all(18), children: [
      const SizedBox(height: 12),
      Icon(Icons.smart_display_rounded,
          size: 76, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 14),
      Text(t('media'),
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(t('allSitesDisclaimer'), textAlign: TextAlign.center),
      const SizedBox(height: 26),
      Card(
          child: ListTile(
        leading: const Icon(Icons.movie_creation_outlined),
        title: Text(t('video')),
        subtitle: Text(t('quality')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onAdd('', 'video'),
      )),
      Card(
          child: ListTile(
        leading: const Icon(Icons.playlist_play_rounded),
        title: Text(t('playlist')),
        subtitle: Text(t('playlistSubtitle')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onAdd('', 'playlist'),
      )),
      Card(
          child: ListTile(
        leading: const Icon(Icons.music_note_rounded),
        title: Text(t('mp3')),
        subtitle: Text(t('originalName')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onAdd('', 'mp3'),
      )),
      const SizedBox(height: 12),
      Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.security_outlined, size: 28),
          const SizedBox(width: 12),
          Expanded(
              child: Text(t('mediaTip'),
                  style: Theme.of(context).textTheme.bodySmall)),
        ]),
      )),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: _updating ? null : _updateEngine,
        icon: _updating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.update_rounded),
        label: Text(_updating ? t('engineUpdateStarted') : t('updateEngine')),
      ),
    ]);
  }
}
