import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../services/playlist_explorer.dart';

class PlaylistExplorerSheet extends StatefulWidget {
  final String url;
  final AppStrings strings;
  const PlaylistExplorerSheet({super.key,required this.url,required this.strings});
  @override State<PlaylistExplorerSheet> createState()=>_PlaylistExplorerSheetState();
}
class _PlaylistExplorerSheetState extends State<PlaylistExplorerSheet> {
  late final Future<PlaylistPreview> future=PlaylistExplorer.inspect(widget.url);
  final Set<int> selected={};
  @override Widget build(BuildContext context){
    final t=widget.strings.t;
    return SafeArea(child:Padding(padding:const EdgeInsets.all(15),child:FutureBuilder<PlaylistPreview>(
      future:future,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done){return const SizedBox(height:180,
          child:Center(child:CircularProgressIndicator()));}
        if(snapshot.hasError || snapshot.data==null){return Column(mainAxisSize:MainAxisSize.min,children:[
          Text(t('playlistPreviewUnavailable')),const SizedBox(height:10),TextButton(
            onPressed:()=>Navigator.pop(context),child:Text(t('close')))]);}
        final preview=snapshot.data!;
        return Column(mainAxisSize:MainAxisSize.min,children:[
          Text(preview.title,style:Theme.of(context).textTheme.titleLarge,maxLines:2),
          Text(t('playlistPreviewLimit')),const SizedBox(height:10),
          SizedBox(height:MediaQuery.sizeOf(context).height*.55,child:ListView.builder(
            itemCount:preview.entries.length,itemBuilder:(context,index){
              final entry=preview.entries[index];
              return CheckboxListTile(value:selected.contains(entry.index),
                onChanged:(flag)=>setState((){if(flag==true){selected.add(entry.index);}else{selected.remove(entry.index);}}),
                secondary:entry.imageUrl.isEmpty?const Icon(Icons.play_circle_outline):
                  Image.network(entry.imageUrl,width:58,height:48,fit:BoxFit.cover,
                    errorBuilder:(_,__,___)=>const Icon(Icons.play_circle_outline)),
                title:Text('${entry.index}. ${entry.title}',maxLines:2),
                dense:true);
            })),
          const SizedBox(height:8),FilledButton(
            onPressed:selected.isEmpty?null:()=>Navigator.pop(context,(
              selected.toList()..sort()).join(',')),
            child:Text(t('playlistUseSelected'))),
        ]);
      }))); 
  }
}
