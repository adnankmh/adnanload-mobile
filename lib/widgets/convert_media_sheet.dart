import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../models/download_entry.dart';
import '../services/media_converter.dart';
import '../services/download_repository.dart';

class ConvertMediaSheet extends StatefulWidget {
  const ConvertMediaSheet({super.key,required this.item,required this.strings,required this.repo});
  final DownloadEntry item;
  final AppStrings strings;
  final DownloadRepository repo;
  @override State<ConvertMediaSheet> createState()=>_ConvertMediaSheetState();
}
class _ConvertMediaSheetState extends State<ConvertMediaSheet> {
  String target='mp3';
  bool busy=false;
  @override Widget build(BuildContext context){
    final t=widget.strings.t;
    return SafeArea(child:Padding(padding:const EdgeInsets.all(20),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(t('convertMedia'),style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),Text(widget.item.name,maxLines:2),
        const SizedBox(height:14),DropdownButtonFormField<String>(initialValue:target,
          decoration:InputDecoration(labelText:t('convertFormat')),
          items:MediaConverter.formats.map((f)=>DropdownMenuItem(value:f,child:Text(f.toUpperCase()))).toList(),
          onChanged:busy?null:(v)=>setState(()=>target=v??'mp3')),
        const SizedBox(height:10),Text(t('convertHint')),
        const SizedBox(height:14),FilledButton(
          onPressed:busy?null:() async {
            setState(()=>busy=true);
            try {
              final path=await MediaConverter.convert(widget.item.path,target);
              await widget.repo.addConvertedFile(widget.item,path);
              if(context.mounted){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content:Text('${t('convertDone')}: $path')));}
            } catch (_) {if(mounted)ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content:Text(t('convertFailed'))));}
            finally {if(mounted)setState(()=>busy=false);}
          },child:Text(busy?t('working'):t('convertStart'))),
      ])));
  }
}
