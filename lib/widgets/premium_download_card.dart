import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_strings.dart';
import '../models/download_entry.dart';
import '../services/download_repository.dart';

/// Live transfer card. No simulated progress, sizes or download speeds.
class PremiumDownloadCard extends StatelessWidget {
  final DownloadEntry item;
  final DownloadRepository repo;
  final AppStrings strings;
  const PremiumDownloadCard({super.key, required this.item, required this.repo,
      required this.strings});

  Color get accent => item.status == 'complete'
      ? const Color(0xFF00E676)
      : item.kind == 'mp3' ? const Color(0xFFFFBE0B)
      : item.kind == 'video' ? const Color(0xFF7B61FF)
      : const Color(0xFF00E5FF);

  IconData get icon => item.isPlaylist ? Icons.playlist_play_rounded
      : item.kind == 'mp3' ? Icons.graphic_eq_rounded
      : item.kind == 'video' ? Icons.play_circle_filled_rounded
      : Icons.insert_drive_file_rounded;

  Future<void> _act(BuildContext context, String operation) async {
    try {
      switch (operation) {
        case 'pause': await repo.pause(item); break;
        case 'resume': await repo.resume(item); break;
        case 'start': await repo.start(item, userInitiated:true); break;
        case 'cancel': await repo.cancel(item); break;
        case 'retry': await repo.retry(item); break;
        case 'replaceLink':
          if (!context.mounted) break;
          final controller = TextEditingController(text:item.url);
          try {
            final url=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
              title:Text(strings.t('replaceExpiredLink')),
              content:TextField(controller:controller,autofocus:true,
                keyboardType:TextInputType.url,textDirection:TextDirection.ltr,
                decoration:InputDecoration(helperText:strings.t('replaceLinkHint'))),
              actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(strings.t('cancel'))),
                FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:Text(strings.t('retry')))],
            ));
            if(url!=null&&url.trim().isNotEmpty) await repo.retryWithNewUrl(item,url.trim());
          } finally {controller.dispose();}
          break;
        case 'remove': await repo.remove(item); break;
        case 'copy': await Clipboard.setData(ClipboardData(text: item.url)); break;
        case 'export':
          final output = await repo.exportToDownloads(item);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${strings.t('exported')}: $output')));
          break;
        case 'share':
          if (item.path.isNotEmpty && await File(item.path).exists()) {
            await SharePlus.instance.share(ShareParams(files:[XFile(item.path)]));
          }
          break;
        case 'rename':
          if (!context.mounted) break;
          final controller = TextEditingController(text:item.name);
          try {
            final input = await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
              title:Text(strings.t('renameFile')),
              content:TextField(controller:controller,autofocus:true),
              actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(strings.t('cancel'))),
                FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:Text(strings.t('save')))],
            ));
            if (input != null && input.trim().isNotEmpty) await repo.renameFinished(item,input.trim());
          } finally { controller.dispose(); }
          break;
        case 'open':
          if (RegExp(r'\.(apk|exe|msi|bat|cmd|sh|jar)$',caseSensitive:false).hasMatch(item.name) &&
              context.mounted) {
            final confirmed = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
              title:Text(strings.t('fileSafety')),
              content:Text(strings.t('confirmRiskyFile')),
              actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(strings.t('cancel'))),
                FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(strings.t('open')))],
            ));
            if (confirmed != true) break;
          }
          if (item.isPlaylist) {
            await _showPlaylistFiles(context);
          } else if (item.path.isNotEmpty) {
            await OpenFilex.open(item.path);
          }
          break;
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _showPlaylistFiles(BuildContext context) async {
    final folder = Directory(item.path);
    final files = <File>[];
    if (await folder.exists()) {
      await for (final entity in folder.list(recursive: true, followLinks: false)) {
        if (entity is File && !entity.path.endsWith('.part')) files.add(entity);
        if (files.length >= 2000) break;
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context, useSafeArea: true, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(strings.t('playlistFiles'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (files.isEmpty) Text(strings.t('noPlaylistFiles')),
          if (files.isNotEmpty) Flexible(
            child: ListView.builder(shrinkWrap: true, itemCount: files.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(files[i].uri.pathSegments.last),
                onTap: () => OpenFilex.open(files[i].path),
              )),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = strings.t;
    final isComplete = item.status == 'complete';
    final paused = item.status == 'paused';
    final running = item.status == 'running';
    final waiting = item.status == 'waiting';
    final percent = (item.progress * 100).clamp(0.0, 100.0).round();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final dim = primaryText.withValues(alpha: .57);
    final background = Theme.of(context).colorScheme.surface;
    final badge = item.isPlaylist ? t('playlist')
      : item.kind == 'direct' ? t('direct')
      : item.kind == 'mp3' ? '${item.audioFormat.toUpperCase()} · ${t('audioFormat')}'
      : t(item.quality);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: isLight ? .20 : .22)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isLight ? .05 : .24),
          blurRadius: 16, offset: const Offset(0, 7))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 65, width: 65,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: .42)),
              gradient: LinearGradient(colors: [accent.withValues(alpha: .38),
                background.withValues(alpha: .95)])),
            child: Icon(icon, color: accent, size: 31)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 9),
                decoration: BoxDecoration(color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: .37))),
                child: Text(badge, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)))),
              const Spacer(),
              PopupMenuButton<String>(icon: Icon(Icons.more_vert_rounded, color: dim),
                tooltip: t('details'), onSelected: (v) => _act(context, v),
                itemBuilder: (_) => [
                  if (isComplete) PopupMenuItem(value: 'open', child: Text(t('open'))),
                  if (isComplete && !item.isPlaylist) ...[
                    PopupMenuItem(value:'share',child:Text(t('shareFile'))),
                    PopupMenuItem(value:'rename',child:Text(t('renameFile'))),
                    PopupMenuItem(value:'export',child:Text(t('exportDownloads'))),
                  ],
                  if (waiting) PopupMenuItem(value: 'start', child: Text(t('downloadNow'))),
                  if (running && item.kind == 'direct') PopupMenuItem(value: 'pause', child: Text(t('pause'))),
                  if (paused && item.kind == 'direct') PopupMenuItem(value: 'resume', child: Text(t('resume'))),
                  if (running || waiting || paused) PopupMenuItem(value: 'cancel', child: Text(t('cancel'))),
                  if (item.status == 'error' || item.status == 'canceled') ...[
                    PopupMenuItem(value:'retry',child:Text(t('retry'))),
                    PopupMenuItem(value:'replaceLink',child:Text(t('replaceExpiredLink'))),
                  ],
                  PopupMenuItem(value: 'copy', child: Text(t('copyLink'))),
                  PopupMenuItem(value: 'remove', child: Text(t('remove'))),
                ],
              ),
            ]),
            const SizedBox(height: 3),
            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: primaryText, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 5),
            Row(children: [
              if (isComplete) const Icon(Icons.check_circle, size: 15, color: Color(0xFF00E676)),
              if (isComplete) const SizedBox(width: 5),
              Expanded(child: Text(t(item.status == 'submitting' ? 'waiting' : item.status == 'verifying' ? 'verifyHash' : item.status),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isComplete ? const Color(0xFF00E676) : accent, fontSize: 12))),
            ]),
          ])),
        ]),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: Column(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: item.progress.clamp(0.0, 1.0),
                minHeight: 7, backgroundColor: dim.withValues(alpha: .15),
                valueColor: AlwaysStoppedAnimation<Color>(accent))),
            const SizedBox(height: 9),
            Row(children: [
              Text('$percent%', style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (item.speed > 0 && running)
                Text('${item.speed.toStringAsFixed(1)} MB/s',
                  style: TextStyle(fontSize: 12, color: dim)),
            ]),
          ])),
          const SizedBox(width: 12),
          if (running && item.kind == 'direct' || paused && item.kind == 'direct' || waiting)
            Material(color: accent.withValues(alpha: .14), shape: const CircleBorder(),
              child: IconButton(
                tooltip: waiting ? t('downloadNow') : paused ? t('resume') : t('pause'),
                icon: Icon(waiting || paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: accent),
                onPressed: () => _act(context, waiting ? (item.nativeQueued ? 'pause' : 'start') : paused ? 'resume' : 'pause'),
              )),
          if (isComplete) Icon(Icons.check_circle_outline_rounded, color: accent, size: 34),
        ]),
        if (item.scheduledAt > 0 && item.status == 'waiting')
          Text('${t('scheduled')}: ${DateTime.fromMillisecondsSinceEpoch(item.scheduledAt).toString().substring(0,16)}',
            style:TextStyle(color:dim,fontSize:12)),
        if (isComplete && item.path.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.path, maxLines: 2, overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: TextStyle(color: dim, fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                ActionChip(avatar: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(t('open')), onPressed: () => _act(context, 'open')),
                if (!item.isPlaylist) ActionChip(
                  avatar: const Icon(Icons.save_alt_rounded, size: 18),
                  label: Text(t('exportDownloads')),
                  onPressed: () => _act(context, 'export')),
              ]),
            ])),
        if (item.actualSha256.isNotEmpty) Text('SHA-256: ${item.actualSha256.substring(0,16)}…',
          style:TextStyle(color:dim,fontSize:11)),
        if (item.error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9),
          child: Text(t(item.error), maxLines: 3, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
      ]),
    );
  }
}
