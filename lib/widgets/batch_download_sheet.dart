import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../core/batch_links.dart';
import '../core/batch_link_preview.dart';
import '../core/batch_csv_import.dart';
import '../core/batch_text_import.dart';
import '../services/download_repository.dart';

class BatchDownloadSheet extends StatefulWidget {
  const BatchDownloadSheet({super.key, required this.repo, required this.strings,
    this.initialText = ''});
  final DownloadRepository repo;
  final AppStrings strings;
  final String initialText;
  @override
  State<BatchDownloadSheet> createState() => _BatchDownloadSheetState();
}

class _BatchDownloadSheetState extends State<BatchDownloadSheet> {
  late final TextEditingController controller = TextEditingController(text:widget.initialText);
  bool busy=false;
  bool later=false;
  String mode='auto';
  Future<void> _importLinksFile() async {
    if (busy) return;
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom, allowedExtensions: const ['txt', 'csv', 'tsv'],
      );
      if (selected == null || !mounted) return;
      final knownLength = selected.lengthSync();
      if (knownLength != null && knownLength > BatchTextImport.maxBytes) {
        throw const FormatException('Link list exceeds 1 MiB');
      }
      // Read through the picker API: Android SAF documents may not have a
      // usable local path or report a file size.
      final decoded = await BatchTextImport.decodeStream(
        selected.readAsByteStream(),
      );
      final filename = selected.name.toLowerCase();
      final imported = filename.endsWith('.csv') || filename.endsWith('.tsv')
          ? BatchCsvImport.extractUrls(decoded)
          : decoded;
      if (!mounted) return;
      final previous = controller.text.trimRight();
      controller.text = previous.isEmpty ? imported : '$previous\n$imported';
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.strings.t('batchImportFailed')),
        ));
      }
    }
  }

  @override void dispose(){ controller.dispose();super.dispose(); }
  @override Widget build(BuildContext context){
    final t=widget.strings.t;
    final unique=BatchLinks.parse(controller.text,
      existing:widget.repo.items.map((e)=>e.url).toSet());
    final previews = unique.map((url) =>
      BatchLinkPreview.fromUrl(url, preferred: mode)).toList();
    return SafeArea(child:Padding(padding:EdgeInsets.only(
      left:18,right:18,top:12,bottom:MediaQuery.viewInsetsOf(context).bottom+18),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(t('batchTitle'),style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),Text(t('batchHint')),
          const SizedBox(height:12),TextField(controller:controller,maxLines:8,
            textDirection:TextDirection.ltr, onChanged:(_)=>setState((){}),
            decoration:InputDecoration(hintText:'https://example.com/file.zip\nhttps://example.com/video.mp4',
              border:const OutlineInputBorder())),
          Align(alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: busy ? null : _importLinksFile,
              icon: const Icon(Icons.file_open_rounded),
              label: Text(t('batchImportTxt')),
            )),
          const SizedBox(height:8),Text('${t('batchUnique')}: ${unique.length} / ${BatchLinks.maxLinks}'),
          Wrap(spacing: 6, children: [
            for (final entry in const [
              ('auto','autoDetect'), ('direct','direct'),
              ('video','video'), ('mp3','mp3')])
              ChoiceChip(label:Text(t(entry.$2)), selected:mode==entry.$1,
                onSelected:busy?null:(_)=>setState(()=>mode=entry.$1)),
          ]),
          if (previews.isNotEmpty) ExpansionTile(
            title: Text(t('batchPreview')),
            subtitle: Text(t('batchPreviewHint')),
            children: [
              for (final item in previews)
                ListTile(
                  dense: true,
                  leading: Icon(item.kind == 'mp3'
                      ? Icons.music_note_rounded
                      : item.kind == 'video'
                          ? Icons.movie_rounded
                          : Icons.insert_drive_file_rounded),
                  title: Text(item.suggestedName ?? t('batchNameUnknown'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr),
                  subtitle: Text('${t(item.kind)} · ${item.host}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          SwitchListTile(title:Text(t('batchLater')),value:later,
            onChanged:busy?null:(v)=>setState(()=>later=v)),
          const SizedBox(height:10),FilledButton.icon(
            icon:const Icon(Icons.playlist_add_rounded),
            label:Text(t('batchAdd')),
            onPressed:busy||unique.isEmpty?null:() async {
              setState(()=>busy=true);
              try {
                var count=0;
                for(final item in previews){
                  await widget.repo.enqueue(url:item.url,name:'',
                    kind:item.kind,
                    playlist:item.isPlaylist,priority:8,startNow:!later);
                  count++;
                }
                if(context.mounted){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content:Text('${t('batchAdded')}: $count')));}
              } catch(_) {if(mounted){ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content:Text(t('downloadFailed'))));}}
              finally{if(mounted)setState(()=>busy=false);}
            }),
        ]))));
  }
}
