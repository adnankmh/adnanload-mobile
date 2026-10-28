import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../core/batch_links.dart';
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
