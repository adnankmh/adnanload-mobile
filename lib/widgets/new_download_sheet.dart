import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_strings.dart';
import '../core/url_guard.dart';
import '../core/playlist_rules.dart';
import '../core/playlist_selection.dart';
import '../services/download_repository.dart';
import 'playlist_explorer_sheet.dart';

class NewDownloadSheet extends StatefulWidget {
  final DownloadRepository repo;
  final AppStrings strings;
  final String initialUrl;
  final String initialKind;
  const NewDownloadSheet({super.key, required this.repo, required this.strings,
    this.initialUrl = '', this.initialKind = 'direct'});

  @override
  State<NewDownloadSheet> createState() => _NewDownloadSheetState();
}

class _NewDownloadSheetState extends State<NewDownloadSheet> {
  late final TextEditingController url = TextEditingController(text:widget.initialUrl);
  late final TextEditingController filename = TextEditingController(text:UrlGuard.nameFromUrl(widget.initialUrl));
  late String kind = widget.initialKind;
  late bool playlist = widget.initialKind == 'playlist' ||
      PlaylistRules.looksLikePlaylist(widget.initialUrl);
  String audioFormat = 'mp3';
  bool separatePlaylistItems = false;
  final TextEditingController positions = TextEditingController();
  String quality = 'best';
  bool loadingName = false;
  bool busy = false;
  bool userEditedName = false;
  String error = '';
  int requestSerial = 0;
  MediaSnapshot? preview;
  final TextEditingController expectedHash = TextEditingController();
  bool scheduled = false;
  DateTime? scheduledAt;
  int priority = 5;

  @override
  void initState() {
    super.initState();
    if (kind == 'playlist') { kind = 'video'; filename.text = widget.strings.t('playlist'); }
    if (playlist && kind == 'direct') kind = 'video';
    if (kind != 'direct' && widget.initialUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _suggestName());
    }
  }

  Future<void> _inspect() async {
    if (kind == 'direct' || UrlGuard.validate(url.text) == null) return;
    setState(() { loadingName = true; error = ''; });
    final result = await widget.repo.inspectMedia(url.text.trim());
    if (!mounted) return;
    setState(() {
      preview = result;
      loadingName = false;
      if (result == null) error = widget.strings.t('noPreview');
      if (!userEditedName && result != null && result.title.isNotEmpty) {
        filename.text = '${UrlGuard.safeName(result.title)}.${kind == 'mp3' ? audioFormat : 'mp4'}';
      }
    });
  }

  Future<void> _selectSchedule() async {
    final day = await showDatePicker(context:context,
      initialDate: DateTime.now().add(const Duration(days:1)),
      firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));
    if (day == null || !mounted) return;
    final tm = await showTimePicker(context:context, initialTime:TimeOfDay.now());
    if (tm == null || !mounted) return;
    setState(() { scheduledAt=DateTime(day.year,day.month,day.day,tm.hour,tm.minute); });
  }

  Future<void> _suggestName() async {
    final candidate = url.text.trim();
    if (UrlGuard.validate(candidate) == null) return;
    final serial = ++requestSerial;
    if (kind == 'direct') {
      if (!userEditedName) filename.text = UrlGuard.nameFromUrl(candidate);
      return;
    }
    setState(() { loadingName = true; error = ''; });
    final suggested = await widget.repo.suggestMediaTitle(candidate);
    if (!mounted || serial != requestSerial) return;
    setState(() {
      loadingName = false;
      if (suggested != null && !userEditedName) {
        filename.text = playlist ? suggested : '$suggested.${kind == 'mp3' ? audioFormat : 'mp4'}';
      }
    });
  }

  Future<void> _start(bool now) async {
    if (UrlGuard.validate(url.text) == null) {
      setState(() => error = widget.strings.t('validUrl'));
      return;
    }
    try { if (playlist) { PlaylistRules.parseItems(positions.text);
      if (separatePlaylistItems) PlaylistSelection.expand(positions.text); } }
    on FormatException { setState(() => error = widget.strings.t('invalidPlaylistItems')); return; }
    final digest = expectedHash.text.trim().toLowerCase();
    if (digest.isNotEmpty && !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      setState(() => error = widget.strings.t('invalidSha256'));
      return;
    }
    if (scheduled && scheduledAt == null) { await _selectSchedule(); if (scheduledAt == null) return; }
    setState(() { busy = true; error = ''; });
    try {
      if (!userEditedName) {
        await _suggestName();
      }
      if (playlist && separatePlaylistItems && positions.text.trim().isNotEmpty) {
        await widget.repo.enqueueSelectedPlaylist(url:url.text.trim(), name:filename.text,
            kind:kind, positions:positions.text, quality:quality,
            audioFormat:audioFormat, startNow:now || scheduled,
            schedule:scheduled ? scheduledAt : null, priority:priority);
      } else {
      await widget.repo.enqueue(url: url.text.trim(), name: filename.text, kind: kind,
          quality:quality, startNow:now || scheduled, playlist:playlist,
          playlistItems:positions.text, audioFormat:audioFormat,
          expectedSha256:kind == 'direct' ? digest : '',
          schedule:scheduled ? scheduledAt : null, priority:priority);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { url.dispose(); filename.dispose(); positions.dispose(); expectedHash.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final tt = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children:[
            Container(padding: const EdgeInsets.all(11), decoration:BoxDecoration(
                color:tt.colorScheme.primary.withValues(alpha:.15), borderRadius:BorderRadius.circular(16)),
              child:Icon(Icons.download_rounded,color:tt.colorScheme.primary,size:28)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(s.t('downloadOptions'),style:tt.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
              const SizedBox(height:4),
              Text(s.t('selectFormat'),style:tt.textTheme.bodySmall),
            ])),
            IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close)),
          ]),
          const SizedBox(height:20),
          TextField(controller:url,textDirection:TextDirection.ltr,keyboardType:TextInputType.url,
            decoration:InputDecoration(labelText:s.t('url'),suffixIcon: IconButton(
              tooltip:s.t('paste'),icon:const Icon(Icons.content_paste_rounded),
              onPressed:() async {
                final data=await Clipboard.getData('text/plain');
                if (data?.text != null) {url.text=data!.text!;
                  setState((){playlist = PlaylistRules.looksLikePlaylist(url.text);
                    if (kind == 'playlist') { kind = 'video'; filename.text = widget.strings.t('playlist'); }
    if (playlist && kind == 'direct') kind = 'video';});
                  await _suggestName();}
              },)),
            onSubmitted:(_) {setState((){playlist=PlaylistRules.looksLikePlaylist(url.text);
              if(playlist&&kind=='direct')kind='video';});_suggestName();},
          ),
          const SizedBox(height:12),
          SegmentedButton<String>(
            showSelectedIcon:false,
            segments:[
              ButtonSegment(value:'direct',label:Text(s.t('direct')),icon:const Icon(Icons.insert_drive_file_outlined)),
              ButtonSegment(value:'video',label:Text(s.t('video')),icon:const Icon(Icons.video_library_outlined)),
              ButtonSegment(value:'mp3',label:Text(s.t('mp3')),icon:const Icon(Icons.music_note_rounded)),
            ], selected:{kind}, onSelectionChanged:busy?null:(v){
              setState((){kind=v.first; if(kind=='direct')playlist=false; userEditedName=false;
                filename.text=UrlGuard.nameFromUrl(url.text);});
              _suggestName();
            }),
          if (kind != 'direct') ...[
            const SizedBox(height:10),
            OutlinedButton.icon(onPressed:busy||loadingName?null:_inspect,
              icon:const Icon(Icons.info_outline_rounded),label:Text(s.t('mediaPreview'))),
            if (preview != null) Card(child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[
              if (preview!.thumbnail.isNotEmpty) ClipRRect(borderRadius:BorderRadius.circular(9),
                child:Image.network(preview!.thumbnail,width:72,height:65,fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>const SizedBox(width:72,child:Icon(Icons.movie_rounded)))),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(preview!.title,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontWeight:FontWeight.w700)),
                Text('${s.t('publisher')}: ${preview!.uploader}',maxLines:1,overflow:TextOverflow.ellipsis),
                Text('${s.t('duration')}: ${preview!.durationSeconds}s · ${s.t('formatsCount')}: ${preview!.formats}'),
              ])),
            ]))),
          ],
          if (kind != 'direct') ...[
            const SizedBox(height:14),
            SwitchListTile.adaptive(
              contentPadding:EdgeInsets.zero,
              value:playlist, title:Text(s.t('playlist')), subtitle:Text(s.t('playlistSubtitle')),
              onChanged:busy?null:(v){setState((){playlist=v; userEditedName=false;
                if(v) filename.text = widget.strings.t('playlist');}); _suggestName();}),
            if (playlist) ...[
              OutlinedButton.icon(icon:const Icon(Icons.view_list_rounded),
                label:Text(s.t('playlistExplore')),
                onPressed:busy?null:() async {
                  if(UrlGuard.validate(url.text)==null) return;
                  final selected=await showModalBottomSheet<String>(context:context,
                    isScrollControlled:true,useSafeArea:true,showDragHandle:true,
                    builder:(_)=>PlaylistExplorerSheet(url:url.text.trim(),strings:s));
                  if(selected!=null && mounted){setState((){
                    positions.text=selected;separatePlaylistItems=true;
                  });}
                }),
              SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,
                title:Text(s.t('separatePlaylistItems')),
                subtitle:Text(s.t('separatePlaylistHint')),
                value:separatePlaylistItems,
                onChanged:busy?null:(v)=>setState(()=>separatePlaylistItems=v)),
              const SizedBox(height:8),
              TextField(controller:positions,
                textDirection:TextDirection.ltr,
                decoration:InputDecoration(labelText:s.t('playlistSelect'),
                  hintText:s.t('playlistItemsHint'),helperText:s.t('playlistAll')),
              ),
            ],
          ],
          const SizedBox(height:14),
          TextField(controller:filename, onChanged:(_)=>userEditedName=true, decoration:InputDecoration(labelText:s.t('name'),
            helperText:s.t('customName'),suffixIcon:loadingName
                ?const Padding(padding:EdgeInsets.all(14),child:SizedBox(height:16,width:16,
                   child:CircularProgressIndicator(strokeWidth:2)))
                : IconButton(onPressed:_suggestName,icon:const Icon(Icons.auto_fix_high))),
          ),
          if (kind=='mp3') ...[
            const SizedBox(height:10),
            DropdownButtonFormField<String>(initialValue:audioFormat,
              decoration:InputDecoration(labelText:s.t('audioFormat')),
              items:const ['mp3','m4a','flac','wav','opus'].map((k)=>DropdownMenuItem(
                value:k,child:Text(k.toUpperCase()))).toList(),
              onChanged:(v){setState((){audioFormat=v??'mp3'; userEditedName=false;});_suggestName();}),
          ],
          if (kind=='video') ...[
            const SizedBox(height:10),
            DropdownButtonFormField<String>(initialValue:quality,
              decoration:InputDecoration(labelText:s.t('quality')),
              items:['best','p2160','p1440','p1080','p720','p480','p360'].map((k)=>DropdownMenuItem(
                value:k,child:Text(s.t(k)))).toList(),
              onChanged:(v)=>setState(()=>quality=v??'best')),
          ],
          if (kind == 'direct') ...[
            const SizedBox(height:10),
            TextField(controller:expectedHash,textDirection:TextDirection.ltr,
              decoration:InputDecoration(labelText:s.t('expectedHash'))),
          ],
          const SizedBox(height:12),
          DropdownButtonFormField<int>(initialValue:priority,
            decoration:InputDecoration(labelText:s.t('priority')),
            items:[(0,'priorityHigh'),(5,'priorityNormal'),(9,'priorityLow')].map((p)=>
              DropdownMenuItem(value:p.$1,child:Text(s.t(p.$2)))).toList(),
            onChanged:(value)=>setState(()=>priority=value??5)),
          SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,
            title:Text(s.t('scheduleDownload')),value:scheduled,
            onChanged:(value)=>setState(()=>scheduled=value)),
          if (scheduled) OutlinedButton.icon(onPressed:_selectSchedule,
            icon:const Icon(Icons.calendar_month_rounded),
            label:Text(scheduledAt == null ? s.t('chooseTime') : scheduledAt!.toLocal().toString().substring(0,16))),
          const SizedBox(height:12),
          Text(s.t('storage'), style:tt.textTheme.bodySmall),
          if (playlist) Padding(padding:const EdgeInsets.only(top:8),child:Text(s.t('playlistWarning'),
            style:tt.textTheme.bodySmall)),
          if (kind != 'direct') Padding(padding:const EdgeInsets.only(top:8),child:Text(s.t('mediaTip'),
            style:tt.textTheme.bodySmall?.copyWith(color:tt.colorScheme.primary))),
          if (error.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:12),
            child:Text(error,style:TextStyle(color:tt.colorScheme.error))),
          const SizedBox(height:22),
          Container(
            height:52,
            decoration:BoxDecoration(
              gradient:LinearGradient(colors:[const Color(0xFF00F5D4),tt.colorScheme.primary,tt.colorScheme.secondary]),
              borderRadius:BorderRadius.circular(16),
              boxShadow:[BoxShadow(color:tt.colorScheme.primary.withValues(alpha:.22),blurRadius:16)],
            ),
            child:ElevatedButton.icon(
              onPressed:busy?null:()=>_start(true),
              style:ElevatedButton.styleFrom(backgroundColor:Colors.transparent,
                shadowColor:Colors.transparent,foregroundColor:const Color(0xFF0B0F17),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
              icon:const Icon(Icons.download_rounded),
              label:Text(busy?s.t('working'):s.t('downloadNow'),
                style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800)),
            ),
          ),
          const SizedBox(height:9),
          OutlinedButton(onPressed:busy?null:()=>_start(false),child:Text(s.t('downloadLater'))),
        ]),
      ))),
    );
  }
}
