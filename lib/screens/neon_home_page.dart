import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_strings.dart';
import '../core/playlist_rules.dart';
import '../core/url_guard.dart';
import '../services/download_repository.dart';
import '../widgets/premium_download_card.dart';

/// Original dashboard using measured transfer states, never demo counters.
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
  final controller = TextEditingController();
  String kind = 'direct';
  @override
  void dispose() {controller.dispose();super.dispose();}

  void start() {
    final url = controller.text.trim();
    if (UrlGuard.validate(url) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(widget.strings.t('validUrl'))));
      return;
    }
    final mode = PlaylistRules.looksLikePlaylist(url) ? 'playlist'
      : kind == 'direct' && PlaylistRules.looksLikeMediaSite(url) ? 'video' : kind;
    widget.onDownload(url, mode);
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() => controller.text = data?.text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.strings.t;
    final cs = Theme.of(context).colorScheme;
    final entries = widget.repo.items;
    final active = entries.where((e) =>
        const {'running','waiting','paused','submitting','verifying'}.contains(e.status)).length;
    final complete = entries.where((e) => e.status == 'complete').length;
    final shown = entries.take(4).toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      children: [
        Text('ADNANLOAD', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900, letterSpacing: .5)),
        const SizedBox(height: 3),
        Text('DOWNLOAD STUDIO', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.primary, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 22),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.link_rounded,color:cs.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(t('pasteLink'), style: const TextStyle(fontWeight:FontWeight.w700))),
            ]),
            const SizedBox(height: 13),
            TextField(
              controller:controller, textDirection:TextDirection.ltr,
              keyboardType:TextInputType.url,
              textInputAction:TextInputAction.go, onSubmitted:(_)=>start(),
              decoration:InputDecoration(
                hintText:'https://',prefixIcon:const Icon(Icons.link_rounded),
                suffixIcon:IconButton(tooltip:t('paste'),onPressed:paste,
                  icon:const Icon(Icons.content_paste_rounded)))),
            const SizedBox(height: 14),
            Wrap(spacing: 8,runSpacing: 8,children: [
              for(final option in [
                ('direct',Icons.download_rounded,'direct'),
                ('video',Icons.smart_display_outlined,'video'),
                ('mp3',Icons.music_note_rounded,'mp3'),
                ('playlist',Icons.playlist_play_rounded,'playlist'),
              ])
                ChoiceChip(
                  avatar:Icon(option.$2,size:19),
                  label:Text(t(option.$3)),
                  selected: kind==option.$1,
                  onSelected:(_)=>setState(()=>kind=option.$1)),
            ]),
            const SizedBox(height: 17),
            FilledButton.icon(onPressed:start,icon:const Icon(Icons.download_rounded),
              label:Text(t('download'),style: const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
          ],
        ))),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _Counter(label:t('active'),value:active,icon:Icons.downloading_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _Counter(label:t('finished'),value:complete,icon:Icons.task_alt_rounded)),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Text(t('activeDownloads'), style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))),
          TextButton.icon(onPressed:widget.onSeeAll,
            label:Text(t('seeAll')), icon:const Icon(Icons.arrow_forward_rounded)),
        ]),
        const SizedBox(height: 10),
        if (shown.isEmpty) Card(child:Padding(padding:const EdgeInsets.all(25),
          child:Column(children: [
            Icon(Icons.cloud_download_outlined,size:46,color:cs.primary),
            const SizedBox(height: 9),
            Text(t('empty'),style:const TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height: 7),
            Text(t('emptyDesc'),textAlign:TextAlign.center),
          ])))
        else for (final item in shown)
          PremiumDownloadCard(key:ValueKey(item.id),item:item,repo:widget.repo,strings:widget.strings),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const _Counter({required this.label,required this.value,required this.icon});
  @override
  Widget build(BuildContext context) {
    final colors=Theme.of(context).colorScheme;
    return Card(child: Padding(padding:const EdgeInsets.all(15),child:Row(children: [
      Icon(icon,color:colors.primary,size:28),
      const SizedBox(width: 10),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children: [
        Text('$value',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
        Text(label,style:Theme.of(context).textTheme.labelMedium),
      ]),
    ])));
  }
}
