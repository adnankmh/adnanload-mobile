import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../core/download_list_filter.dart';
import '../core/download_list_sort.dart';
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
  String sortMode = 'newest';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      search = '';
      filter = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.strings.t;
    final scheme = Theme.of(context).colorScheme;
    final entries = DownloadListSort.ordered(
      widget.repo.items.where((item) =>
          DownloadListFilter.matches(item, filter: filter, query: search)),
      sortMode,
    );
    final metrics = widget.repo.metrics;
    final arabic = widget.strings.locale == 'ar';
    final hasFilters = filter != 'all' || search.trim().isNotEmpty;
    final active = metrics.active;
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
        child: TextField(controller: _searchController,
          onChanged: (text) => setState(() => search = text),
          decoration: InputDecoration(hintText: t('search'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: PopupMenuButton<String>(
              tooltip: widget.strings.locale == 'ar'
                  ? 'ترتيب التنزيلات' : 'Sort downloads',
              icon: const Icon(Icons.sort_rounded),
              onSelected: (value) => setState(() => sortMode = value),
              itemBuilder: (context) => [
                for (final mode in DownloadListSort.modes)
                  PopupMenuItem<String>(
                    value: mode,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (sortMode == mode) ...[
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(DownloadListSort.label(mode,
                          arabic: widget.strings.locale == 'ar')),
                    ]),
                  ),
              ],
            )))),
      SizedBox(height: 51, child: ListView(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 17), children: [
          for (final key in DownloadListFilter.filters)
            Padding(padding: const EdgeInsetsDirectional.only(end: 9),
              child: ChoiceChip(label: Text(key == 'retrying' || key == 'verifying'
                  ? DownloadListFilter.label(key, arabic: arabic) : t(key)),
                selected: filter == key,
                onSelected: (_) => setState(() => filter = key))),
        ])),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(17, 2, 17, 6),
        child: Row(children: [
          Expanded(child: Text(arabic
              ? 'عرض ${entries.length} من ${metrics.total} تنزيل'
              : 'Showing ${entries.length} of ${metrics.total} downloads',
            style: Theme.of(context).textTheme.bodySmall)),
          if (hasFilters) TextButton(onPressed: _resetFilters,
            child: Text(arabic ? 'مسح التصفية' : 'Clear filters')),
        ]),
      ),
      Expanded(child: entries.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_download_outlined, size: 72, color: scheme.primary),
            const SizedBox(height: 10),
            Text(hasFilters ? (arabic ? 'لا توجد نتائج مطابقة' : 'No matching downloads')
                : t('empty'), style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 7), Text(hasFilters
                ? (arabic ? 'غيّر البحث أو التصفية لعرض التنزيلات.'
                    : 'Change your search or filters to see downloads.')
                : t('emptyDesc'), textAlign: TextAlign.center),
            const SizedBox(height: 17),
            FilledButton.icon(onPressed: hasFilters ? _resetFilters : widget.addDownload,
              icon: Icon(hasFilters ? Icons.filter_alt_off : Icons.add),
              label: Text(hasFilters ? (arabic ? 'مسح التصفية' : 'Clear filters') : t('add'))),
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
