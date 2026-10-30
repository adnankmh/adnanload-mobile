import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../core/batch_links.dart';
import '../core/batch_text_import.dart';
import '../core/smart_link.dart';
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
  Future<void> _importTxt() async {
    if (busy) return;
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: const ['txt'],
        withData: false,
      );
      if (selection == null || !mounted) return;
      final selected = selection.files.single;
      if (selected.size > BatchTextImport.maxBytes || selected.path == null) {
        throw const FormatException('Invalid TXT file');
      }
      final file = File(selected.path!);
      if (await file.length() > BatchTextImport.maxBytes) {
        throw const FormatException('TXT file exceeds 1 MiB');
      }
      final imported = BatchTextImport.decode(await file.readAsBytes());
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
              onPressed: busy ? null : _importTxt,
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
          SwitchListTile(title:Text(t('batchLater')),value:later,
            onChanged:busy?null:(v)=>setState(()=>later=v)),
          const SizedBox(height:10),FilledButton.icon(
            icon:const Icon(Icons.playlist_add_rounded),
            label:Text(t('batchAdd')),
            onPressed:busy||unique.isEmpty?null:() async {
              setState(()=>busy=true);
              try {
                var count=0;
                for(final url in unique){
                  final type=SmartLink.kind(url, preferred:mode);
                  await widget.repo.enqueue(url:url,name:'',
                    kind:type=='playlist'?'video':type,
                    playlist:type=='playlist',priority:8,startNow:!later);
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
