import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_strings.dart';
import '../core/playlist_rules.dart';
import '../core/url_guard.dart';
import '../services/download_repository.dart';
import '../widgets/premium_download_card.dart';

/// The supplied cyan/violet design, connected to the real download repository.
/// No demo links, simulated timers, fake sizes, or fake progress are used.
class NeonHomePage extends StatefulWidget {
  final DownloadRepository repo;
  final AppStrings strings;
  final void Function(String url, String kind) onDownload;
  final VoidCallback onSeeAll;
  const NeonHomePage({super.key, required this.repo, required this.strings,
    required this.onDownload, required this.onSeeAll});

  @override
  State<NeonHomePage> createState() => _NeonHomePageState();
}

class _NeonHomePageState extends State<NeonHomePage> {
  final TextEditingController _urlController = TextEditingController();
  int categoryIndex = 0;
  final categories = const [
    (key: 'platformVideo', icon: Icons.videocam_rounded, color: Color(0xFF00F5D4), kind: 'video'),
    (key: 'platformSocial', icon: Icons.public_rounded, color: Color(0xFF3A86FF), kind: 'video'),
    (key: 'platformReels', icon: Icons.movie_filter_rounded, color: Color(0xFFFF006E), kind: 'video'),
    (key: 'platformAudio', icon: Icons.headphones_rounded, color: Color(0xFFFFBE0B), kind: 'mp3'),
    (key: 'platformCloud', icon: Icons.cloud_download_rounded, color: Color(0xFF8338EC), kind: 'direct'),
  ];

  @override
  void dispose() { _urlController.dispose(); super.dispose(); }

  void _notify(String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(widget.strings.t(key)),
    ));
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) { _notify('clipboardEmpty'); return; }
    setState(() => _urlController.text = text);
  }

  void _newDownload() {
    final url = _urlController.text.trim();
    if (url.isEmpty) { _notify('downloadLinkFirst'); return; }
    if (UrlGuard.validate(url) == null) { _notify('validUrl'); return; }
    // Ordinary downloadable files should not be passed to a video extractor.
    final resourcePath = Uri.parse(url).path.toLowerCase();
    final fileLink = RegExp(r'\.(pdf|zip|rar|7z|apk|exe|iso|docx?|xlsx?|pptx?|csv|png|jpe?g|gif|webp|tar|gz|mp4|mp3|wav|flac|mov|mkv|webm)$',
      caseSensitive: false).hasMatch(resourcePath);
    final mode = PlaylistRules.looksLikePlaylist(url) ? 'playlist'
      : fileLink ? 'direct'
      : categoryIndex == 3 ? 'mp3'
      : categoryIndex == 4 ? 'direct'
      : PlaylistRules.looksLikeMediaSite(url) ? 'video'
      : 'direct';
    widget.onDownload(url, mode);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final colors = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final items = widget.repo.items;
    final active = items.where((e) => e.status == 'running' || e.status == 'waiting').toList();
    final shown = [
      ...active,
      ...items.where((e) => e.status != 'running' && e.status != 'waiting'),
    ].take(5).toList();
    return Container(
      decoration: BoxDecoration(gradient: RadialGradient(
        center: const Alignment(-.85, -.75), radius: 1.6,
        colors: isLight ? [const Color(0xFFF4FAFF), Theme.of(context).scaffoldBackgroundColor]
          : [Color.lerp(colors.primary, const Color(0xFF162238), .84)!,
            Theme.of(context).scaffoldBackgroundColor],
      )),
      child: ListView(padding: const EdgeInsets.symmetric(horizontal: 18), children: [
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .93),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.primary.withValues(alpha: .40), width: 1.3),
            boxShadow: [
              BoxShadow(color: colors.primary.withValues(alpha: .11), blurRadius: 24, offset: const Offset(0, 6)),
              BoxShadow(color: colors.secondary.withValues(alpha: .10), blurRadius: 22, offset: const Offset(0, -3)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.t('qualitySelect'), style: TextStyle(
              color: colors.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: _urlController,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _newDownload(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: s.t('pasteLink'),
                suffixIcon: TextButton(onPressed: _paste, child: Text(s.t('paste'))),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(height: 52, child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF00F5D4), colors.primary, colors.secondary,
                ]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: .27), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton.icon(
                onPressed: _newDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  foregroundColor: const Color(0xFF0B0F17),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 24),
                label: Text(s.t('download'), style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            )),
          ]),
        ),
        const SizedBox(height: 23),
        SizedBox(height: 94, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final category = categories[i];
            final selected = i == categoryIndex;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => categoryIndex = i),
              child: AnimatedContainer(duration: const Duration(milliseconds: 220),
                width: 74, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    category.color.withValues(alpha: selected ? .27 : .15),
                    colors.surface.withValues(alpha: .95),
                  ]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: category.color.withValues(alpha: selected ? .85 : .30),
                    width: selected ? 1.5 : 1),
                  boxShadow: selected ? [BoxShadow(color: category.color.withValues(alpha: .18), blurRadius: 14)] : [],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(category.icon, color: category.color, size: 26),
                  const SizedBox(height: 9),
                  Text(s.t(category.key), textAlign: TextAlign.center, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: .85))),
                ]),
              ),
            );
          },
        )),
        const SizedBox(height: 25),
        Row(children: [
          Expanded(child: Text(s.t('activeDownloads'),
            style: TextStyle(color: colors.onSurface, fontSize: 19, fontWeight: FontWeight.bold))),
          TextButton(onPressed: widget.onSeeAll,
            child: Text(s.t('seeAll'), style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Container(padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: colors.surface.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Icon(Icons.downloading_rounded, color: colors.primary, size: 58),
              const SizedBox(height: 8),
              Text(s.t('empty'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(s.t('emptyDesc'), textAlign: TextAlign.center),
            ]))
        else ...shown.map((e) => PremiumDownloadCard(key: ValueKey(e.id),
          item: e, repo: widget.repo, strings: s)),
        const SizedBox(height: 28),
      ]),
    );
  }
}
