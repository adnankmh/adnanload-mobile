import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../services/download_repository.dart';
import '../widgets/premium_download_card.dart';

class DownloadsPage extends StatefulWidget {
  final DownloadRepository repo;
  final AppStrings strings;
  final VoidCallback addDownload;
  const DownloadsPage({super.key, required this.repo, required this.strings,
    required this.addDownload});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  String filter = 'all';
  String search = '';

  @override
  Widget build(BuildContext context) {
    final t = widget.strings.t;
    final scheme = Theme.of(context).colorScheme;
    final entries = widget.repo.items.where((item) {
      final matching = switch (filter) {
        'active' => {'running', 'waiting', 'paused'}.contains(item.status),
        'finished' => item.status == 'complete',
        'failed' => {'error', 'canceled'}.contains(item.status),
        _ => true,
      };
      final query = search.trim().toLowerCase();
      return matching && (item.name.toLowerCase().contains(query) ||
          item.url.toLowerCase().contains(query));
    }).toList();
    final metrics = widget.repo.metrics;
    final active = metrics.running;
    final completed = metrics.completed;
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(17, 16, 17, 7),
        child: Row(children: [
          Expanded(child: _Metric(icon: Icons.downloading_rounded,
            value: '$active', label: t('active'), accent: scheme.primary)),
          const SizedBox(width: 11),
          Expanded(child: _Metric(icon: Icons.task_alt_rounded,
            value: '$completed', label: t('finished'), accent: const Color(0xFF00E676))),
        ])),
      if (metrics.failed > 0) Padding(
        padding:const EdgeInsets.symmetric(horizontal:17,vertical:5),
        child:Row(children:[
          Expanded(child:Text('${t('failed')}: ${metrics.failed}  ·  ${t('waiting')}: ${metrics.waiting}  ·  ${metrics.currentMbPerSecond.toStringAsFixed(1)} MB/s',
            style:Theme.of(context).textTheme.bodyMedium)),
          OutlinedButton.icon(onPressed:() async {
            final number=await widget.repo.retryFailed();
            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content:Text('${t('retryFailedCount')}: $number')));
          },icon:const Icon(Icons.replay_rounded,size:18),label:Text(t('retryAllFailed'))),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        child: TextField(onChanged: (text) => setState(() => search = text),
          decoration: InputDecoration(hintText: t('search'),
            prefixIcon: const Icon(Icons.search_rounded)))),
      SizedBox(height: 51, child: ListView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17), children: [
          for (final key in ['all', 'active', 'finished', 'failed'])
            Padding(padding: const EdgeInsetsDirectional.only(end: 9),
              child: ChoiceChip(label: Text(t(key)), selected: filter == key,
                onSelected: (_) => setState(() => filter = key))),
        ])),
      const SizedBox(height: 10),
      Expanded(child: entries.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_download_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: 10),
            Text(t('empty'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7), Text(t('emptyDesc'), textAlign: TextAlign.center),
            const SizedBox(height: 17),
            FilledButton.icon(onPressed: widget.addDownload,
              icon: const Icon(Icons.add), label: Text(t('add'))),
          ])))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(15, 0, 15, 70),
            itemCount: entries.length,
            itemBuilder: (_, index) => PremiumDownloadCard(
              key: ValueKey(entries[index].id), item: entries[index],
              repo: widget.repo, strings: widget.strings))),
    ]);
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  const _Metric({required this.icon, required this.value,
    required this.label, required this.accent});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: .25)),
    ),
    child: Row(children: [
      Icon(icon, color: accent, size: 29),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: accent, fontWeight: FontWeight.w800)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall),
      ])),
    ]),
  );
}
