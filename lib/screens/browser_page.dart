import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/app_strings.dart';
import '../core/url_guard.dart';
import '../core/media_detector.dart';
import '../services/download_repository.dart';

/// A small tabbed browser. Captures user-initiated direct file navigations,
/// not arbitrary streaming requests or private app traffic.
class BrowserPage extends StatefulWidget {
  final AppStrings strings;
  final DownloadRepository repo;
  final void Function(String url, String mode) onDownload;
  const BrowserPage({super.key, required this.strings, required this.repo,
    required this.onDownload});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with WidgetsBindingObserver {
  final TextEditingController address = TextEditingController();
  final List<WebViewController> browsers = [];
  final List<String> urls = [];
  int active = 0;
  int progress = 100;
  bool privateSession = false;
  bool _clearingSession = false;
  final Map<WebViewController,List<String>> detected = {};

  static final RegExp downloadable = RegExp(
    r'\.(zip|rar|7z|tar|gz|apk|pdf|epub|mp3|m4a|mp4|mkv|webm|iso|exe|docx?|xlsx?|pptx?)$',
    caseSensitive: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addTab('https://www.google.com');
  }

  void _addTab(String initial) {
    late final WebViewController web;
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress:(value) {
          if (mounted && browsers.indexOf(web) == active) setState(()=>progress=value);
        },
        onUrlChange:(change) {
          final index = browsers.indexOf(web);
          if (change.url == null || !mounted || index < 0) return;
          setState(() {
            urls[index] = change.url!;
            if (index == active) address.text = change.url!;
          });
        },
        onPageFinished: (_) => _scanPage(web),
        onNavigationRequest:(request) {
          if (UrlGuard.validate(request.url) == null) return NavigationDecision.prevent;
          final path = Uri.parse(request.url).path;
          if (downloadable.hasMatch(path)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onDownload(request.url, 'direct');
            });
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    detected[web] = [];
    browsers.add(web);
    urls.add(initial);
    active=browsers.length-1;
    address.text=initial;
    web.loadRequest(Uri.parse(initial));
    if (mounted) setState(() {});
  }

  void _closeTab(int idx) {
    if (browsers.length == 1) return;
    setState(() {
      final removed=browsers.removeAt(idx);
      detected.remove(removed);
      urls.removeAt(idx);
      active = active.clamp(0, browsers.length - 1).toInt();
      address.text=urls[active];
    });
  }

  void go() {
    var raw=address.text.trim();
    if(!raw.startsWith('http://')&&!raw.startsWith('https://')) raw='https://$raw';
    final uri=UrlGuard.validate(raw);
    if(uri==null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(widget.strings.t('validUrl'))));
      return;
    }
    browsers[active].loadRequest(uri);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _scanPage(WebViewController web) async {
    try {
      final raw=await web.runJavaScriptReturningResult(MediaDetector.domProbe);
      final matches=MediaDetector.parse(raw);
      if(mounted&&browsers.contains(web))setState(()=>detected[web]=matches);
    } catch (_) {
      if(mounted&&browsers.contains(web))setState(()=>detected[web]=[]);
    }
  }

  void _showDetected() {
    final t=widget.strings.t;
    final choices=detected[browsers[active]]??[];
    showModalBottomSheet<void>(context:context,showDragHandle:true,
      isScrollControlled:true,builder:(ctx)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(16),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(t('detectedMedia'),style:Theme.of(ctx).textTheme.titleLarge),
          if(choices.isEmpty)Text(t('noDetectedMedia')),
          if(choices.isNotEmpty)SizedBox(height:300,child:ListView.builder(itemCount:choices.length,
            itemBuilder:(_,i){final link=choices[i];return ListTile(
              leading:const Icon(Icons.download_rounded),title:Text(link,maxLines:2,overflow:TextOverflow.ellipsis),
              onTap:(){Navigator.pop(ctx);widget.onDownload(link,
                RegExp(r'\.(mp4|webm|m3u8)(?:$|\?)',caseSensitive:false).hasMatch(link)
                  ? 'video' : 'direct');},);}))
        ]))));
  }

  /// Best-effort ephemeral WebView session. Android WebView shares cookies
  /// across controllers: this switches sessions by clearing ALL WebView data.
  /// It is NOT a separate OS-level incognito browser profile.
  Future<void> _wipeSession() async {
    if (_clearingSession) return;
    _clearingSession = true;
    try {
      await WebViewCookieManager().clearCookies();
      for (final web in browsers) {
        await web.clearCache();
        await web.clearLocalStorage();
      }
      if (!mounted) return;
      setState(() {
        browsers.clear();
        urls.clear();
        detected.clear();
        active = 0;
        progress = 100;
      });
      _addTab('https://www.google.com');
    } finally { _clearingSession = false; }
  }

  Future<void> _togglePrivateSession() async {
    if (_clearingSession) return;
    final t = widget.strings.t;
    if (!privateSession) {
      final confirmed = await showDialog<bool>(context:context, builder:(ctx)=>AlertDialog(
        title: Text(t('privateSession')),
        content: Text(t('privateSessionWarning')),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx, false),child:Text(t('cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx, true),child:Text(t('continue'))),
        ],
      ));
      if (confirmed != true || !mounted) return;
    }
    await _wipeSession();
    if (mounted) setState(()=>privateSession = !privateSession);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (privateSession && state == AppLifecycleState.paused) {
      // Wipe in background as far as the OS permits; abrupt process death is
      // not guaranteed to invoke Flutter lifecycle callbacks.
      privateSession = false;
      unawaited(_wipeSession());
    }
  }

  Future<void> _clearSiteData() async {
    final t=widget.strings.t;
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(t('clearBrowsingData')),
      content:Text(t('clearBrowsingConfirm')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('confirm')))]));
    if(accepted!=true)return;
    await WebViewCookieManager().clearCookies();
    for(final web in browsers) {
      await web.clearCache();
      await web.clearLocalStorage();
    }
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('browserDataCleared'))));
  }

  void _bookmarks() {
    if (privateSession) return;
    showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,
      builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(widget.strings.t('savedLinks'),style:Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height:10),
          if (widget.repo.bookmarks.isEmpty) Text(widget.strings.t('noBookmarks')),
          if(widget.repo.bookmarks.isNotEmpty) Flexible(child:ListView.builder(
            shrinkWrap:true,itemCount:widget.repo.bookmarks.length,
            itemBuilder:(_,i)=>ListTile(title:Text(widget.repo.bookmarks[i],maxLines:2),
              leading:const Icon(Icons.bookmark_rounded),onTap:(){
                final url=widget.repo.bookmarks[i]; Navigator.pop(ctx);
                browsers[active].loadRequest(Uri.parse(url));
              })) ),
        ]))));
  }

  Future<void> _clearTemporaryDataOnDispose() async {
    try {
      await WebViewCookieManager().clearCookies();
      for (final web in browsers) {
        await web.clearCache();
        await web.clearLocalStorage();
      }
    } catch (_) { /* session cleanup is best-effort at process exit */ }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (privateSession) unawaited(_clearTemporaryDataOnDispose());
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t=widget.strings.t;
    final current=urls[active];
    return Column(children:[
      SizedBox(height:50,child:ListView(scrollDirection:Axis.horizontal,
        children:[for(var i=0;i<browsers.length;i++)
          Padding(padding:const EdgeInsets.symmetric(horizontal:3),
            child:InputChip(selected:i==active,
              label:Text('${i+1} · ${Uri.tryParse(urls[i])?.host ?? ''}',overflow:TextOverflow.ellipsis),
              onPressed:()=>setState(() {active=i;address.text=urls[i];progress=100;}),
              onDeleted:browsers.length>1?()=>_closeTab(i):null)),
          IconButton(icon:const Icon(Icons.add_rounded),tooltip:t('newTab'),
            onPressed:browsers.length>=7?null:()=>_addTab('https://www.google.com')),
        ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),child:Row(children:[
        IconButton(onPressed:() async {
          if(await browsers[active].canGoBack()) await browsers[active].goBack();
        },icon:const Icon(Icons.arrow_back_ios_new_rounded),tooltip:t('back')),
        Expanded(child:TextField(controller:address,textDirection:TextDirection.ltr,
          textInputAction:TextInputAction.go,onSubmitted:(_)=>go(),
          decoration:InputDecoration(hintText:t('browserHint'),isDense:true,
            prefixIcon:const Icon(Icons.public_rounded),
            suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward_rounded),onPressed:go)))),
        IconButton(onPressed:()=>browsers[active].reload(),icon:const Icon(Icons.refresh),tooltip:t('refresh')),
      ])),
      if (privateSession) Container(
        width:double.infinity,padding:const EdgeInsets.all(8),
        color:Theme.of(context).colorScheme.secondaryContainer,
        child:Row(children:[const Icon(Icons.shield_outlined,size:18),
          const SizedBox(width:8), Expanded(child:Text(t('privateSessionActive')))])),
      if(progress<100)LinearProgressIndicator(value:progress/100,minHeight:2),
      Expanded(child:Stack(children:[
        Positioned.fill(child:IndexedStack(index:active,children:[
          for (final web in browsers) WebViewWidget(controller:web),
        ])),
        if((detected[browsers[active]]??[]).isNotEmpty)
          PositionedDirectional(end:16,bottom:16,child:FloatingActionButton.extended(
            heroTag:'detectedMedia',onPressed:_showDetected,
            icon:const Icon(Icons.video_file_rounded),label:Text(t('detectedMedia')))),
      ])),
      SafeArea(top:false,child:Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),child:Row(children:[
        Expanded(child:FilledButton.icon(onPressed:()=>widget.onDownload(current,'direct'),
          icon:const Icon(Icons.download_rounded),label:Text(t('browseDownload')))),
        IconButton.filledTonal(onPressed:()=>widget.onDownload(current,'video'),
          icon:const Icon(Icons.movie_outlined),tooltip:t('video')),
        IconButton.filledTonal(onPressed:()=>widget.onDownload(current,'mp3'),
          icon:const Icon(Icons.music_note_rounded),tooltip:t('mp3')),
        IconButton(onPressed:privateSession?null:()=>widget.repo.toggleBookmark(current),
          icon:Icon(widget.repo.bookmarked(current)?Icons.bookmark_rounded:Icons.bookmark_border_rounded),
          tooltip:t(widget.repo.bookmarked(current)?'removeBookmark':'addBookmark')),
        IconButton(onPressed:privateSession?null:_bookmarks,icon:const Icon(Icons.bookmarks_outlined),tooltip:t('openBookmarks')),
        IconButton(onPressed:_togglePrivateSession,
          icon:Icon(privateSession?Icons.visibility_off_rounded:Icons.shield_outlined),
          tooltip:t(privateSession?'exitPrivateSession':'privateSession')),
        IconButton(onPressed:_clearSiteData,icon:const Icon(Icons.cleaning_services_outlined),tooltip:t('clearBrowsingData')),
        IconButton(onPressed:()=>Clipboard.setData(ClipboardData(text:current)),
          icon:const Icon(Icons.copy_rounded),tooltip:t('copyLink')),
      ]))),
    ]);
  }
}
