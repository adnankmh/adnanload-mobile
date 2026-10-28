import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/app_strings.dart';
import 'core/theme.dart';
import 'core/playlist_rules.dart';
import 'services/download_repository.dart';
import 'services/android_schedule_service.dart';
import 'services/crash_journal.dart';
import 'screens/browser_page.dart';
import 'screens/downloads_page.dart';
import 'screens/files_hub_page.dart';
import 'screens/neon_home_page.dart';
import 'screens/settings_page.dart';
import 'widgets/new_download_sheet.dart';
import 'widgets/privacy_gate.dart';
import 'widgets/batch_download_sheet.dart';
import 'core/batch_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(CrashJournal.record('framework'));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(CrashJournal.record('platform'));
    return false; // do not silently mark an unhandled error as recovered
  };
  try { await AndroidScheduleService.initialize(); }
  catch (_) { /* in-app scheduler remains as fallback */ }
  final repo = DownloadRepository();
  try {
    await repo.init();
  } catch (_) {
    await CrashJournal.record('startup');
    rethrow;
  }
  runApp(AdnanLoadMobile(repo: repo));
}

class AdnanLoadMobile extends StatelessWidget {
  final DownloadRepository repo;
  const AdnanLoadMobile({super.key, required this.repo});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repo, builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ADNANLOAD',
      locale: Locale(repo.language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BrandThemes.build(repo.theme, fontScale: repo.fontScale),
      home: Directionality(
        textDirection: repo.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: PrivacyGate(repo:repo, child: AdnanHome(repo: repo)),
      ),
    ),
  );
}

class AdnanHome extends StatefulWidget {
  final DownloadRepository repo;
  const AdnanHome({super.key, required this.repo});
  @override
  State<AdnanHome> createState() => _AdnanHomeState();
}

class _AdnanHomeState extends State<AdnanHome> with WidgetsBindingObserver {
  int page = 0;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_receiveFiles,
      onError: (Object _) {});
    ReceiveSharingIntent.instance.getInitialMedia().then((items) {
      _receiveFiles(items);
      ReceiveSharingIntent.instance.reset();
    }).catchError((Object _) {});
  }

  void _receiveFiles(List<SharedMediaFile> items) {
    if (!mounted) return;
    final incoming=BatchLinks.parse(items.map((e)=>e.path).join('\n'));
    if(incoming.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(!mounted) return;
      if(incoming.length > 1){_showBatch(incoming.join('\n'));}
      else {
        final raw=incoming.single;
        _showDownload(raw,PlaylistRules.looksLikePlaylist(raw)?'playlist'
          :PlaylistRules.looksLikeMediaSite(raw)?'video':'direct');
      }
    });
  }

  void _showBatch([String input='']) {
    showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,
      showDragHandle:true,backgroundColor:Theme.of(context).colorScheme.surface,
      builder:(_)=>BatchDownloadSheet(repo:widget.repo,
        strings:AppStrings(widget.repo.language),initialText:input));
  }

  void _showDownload(String url, String kind) {
    final s = AppStrings(widget.repo.language);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => NewDownloadSheet(repo: widget.repo, strings: s,
        initialUrl: url, initialKind: kind),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(AppStrings(widget.repo.language).t('settings'))),
        body: SettingsPage(repo: widget.repo, strings: AppStrings(widget.repo.language)),
      ),
    ));
  }

  void _openHelp() {
    final s = AppStrings(widget.repo.language);
    showModalBottomSheet<void>(context: context, showDragHandle: true,
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(22), child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('quickHelp'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(s.t('emptyDesc')),
            const SizedBox(height: 8),
            Text(s.t('allSitesDisclaimer')),
            const SizedBox(height: 10),
            Text(s.t('author'), textAlign: TextAlign.center),
          ],
        ),
      )),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.repo.onForeground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(widget.repo.language);
    final colors = Theme.of(context).colorScheme;
    final secondaryText = colors.onSurface.withValues(alpha: .63);
    final navEntries = [
      (key: 'home', icon: Icons.home_outlined, selected: Icons.home_rounded),
      (key: 'downloads', icon: Icons.download_outlined, selected: Icons.download_rounded),
      (key: 'browser', icon: Icons.language_outlined, selected: Icons.language_rounded),
      (key: 'files', icon: Icons.folder_outlined, selected: Icons.folder_rounded),
    ];
    final largeScreen = MediaQuery.sizeOf(context).width >= 700;
    final content = IndexedStack(index: page, children: [
      NeonHomePage(repo: widget.repo, strings: s,
        onDownload: _showDownload, onSeeAll: () => setState(() => page = 1)),
      DownloadsPage(repo: widget.repo, strings: s,
        addDownload: () => _showDownload('', 'direct')),
      BrowserPage(strings: s, repo: widget.repo, onDownload: _showDownload),
      FilesHubPage(repo: widget.repo, strings: s, onAdd: _showDownload),
    ]);
    return Scaffold(
      appBar: AppBar(toolbarHeight: 77, titleSpacing: 16,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/adnanload_mark.png', height: 42,
              width: 42, fit: BoxFit.cover)),
          const SizedBox(width: 9),
          Expanded(child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: [
              const Color(0xFF00F5D4), colors.primary, colors.secondary,
            ]).createShader(bounds),
            child: const Text('ADNANLOAD',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 23, letterSpacing: .6,
                fontWeight: FontWeight.w900, color: Colors.white)),
          )),
        ]),
        actions: [
          IconButton(tooltip:s.t('batchTitle'),onPressed:_showBatch,
            icon:const Icon(Icons.playlist_add_rounded)),
          _HeaderAction(icon: Icons.help_outline_rounded, label: s.t('quickHelp'),
            textColor: secondaryText, onTap: _openHelp),
          const SizedBox(width: 8),
          _HeaderAction(icon: Icons.settings_outlined, label: s.t('settings'),
            textColor: secondaryText, onTap: _openSettings),
          const SizedBox(width: 14),
        ],
      ),
      body: largeScreen ? Row(children: [
        NavigationRail(
          selectedIndex: page,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected:(next)=>setState(()=>page=next),
          destinations:[for(final tab in navEntries)
            NavigationRailDestination(icon:Icon(tab.icon),
              selectedIcon:Icon(tab.selected),label:Text(s.t(tab.key))),
          ],
        ),
        const VerticalDivider(width:1),
        Expanded(child:content),
      ]) : content,
      bottomNavigationBar: largeScreen ? null : NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: colors.primary.withValues(alpha: .15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11, fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? colors.primary : secondaryText,
          )),
        ),
        child: NavigationBar(height: 69, elevation: 0,
          selectedIndex: page,
          onDestinationSelected: (next) => setState(() => page = next),
          destinations: [
            for (final tab in navEntries)
              NavigationDestination(icon: Icon(tab.icon, color: secondaryText),
                selectedIcon: Icon(tab.selected, color: colors.primary),
                label: s.t(tab.key)),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.label,
    required this.textColor, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: textColor)),
        ])),
  );
}
