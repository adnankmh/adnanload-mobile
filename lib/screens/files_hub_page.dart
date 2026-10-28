import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../services/download_repository.dart';
import '../screens/media_page.dart';
import '../widgets/premium_download_card.dart';
import '../widgets/convert_media_sheet.dart';

/// Files and the existing media/playlist actions are both retained.
class FilesHubPage extends StatefulWidget {
  final DownloadRepository repo;
  final AppStrings strings;
  final void Function(String url, String kind) onAdd;
  const FilesHubPage({super.key, required this.repo, required this.strings,
      required this.onAdd});

  @override
  State<FilesHubPage> createState() => _FilesHubPageState();
}

class _FilesHubPageState extends State<FilesHubPage> {
  String selected='all';
  String fileQuery='';
  bool newestFirst=true;
  bool matches(String name) {
    final lower=name.toLowerCase();
    const videos=['.mp4','.mkv','.webm','.avi','.mov'];
    const audio=['.mp3','.m4a','.flac','.wav','.ogg','.opus'];
    const docs=['.pdf','.doc','.docx','.txt','.csv','.xls','.xlsx','.ppt','.pptx','.epub'];
    if(selected=='videoFiles')return videos.any(lower.endsWith);
    if(selected=='audioFiles')return audio.any(lower.endsWith);
    if(selected=='documentFiles')return docs.any(lower.endsWith);
    if(selected=='otherFiles')return ![...videos,...audio,...docs].any(lower.endsWith);
    return true;
  }
  @override
  Widget build(BuildContext context) {
    final s = widget.strings.t;
    final finished = widget.repo.items.where((x) => x.status == 'complete' &&
      matches(x.name) && x.name.toLowerCase().contains(fileQuery.trim().toLowerCase())).toList()
      ..sort((a,b) => newestFirst ? b.addedAt.compareTo(a.addedAt)
                             : a.addedAt.compareTo(b.addedAt));
    return DefaultTabController(length: 2, child: Column(children: [
      TabBar(tabs: [Tab(text: s('files')), Tab(text: s('media'))]),
      Expanded(child: TabBarView(children: [
        Column(children:[
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 4), child:Row(children:[
            Expanded(child:TextField(
              onChanged:(value)=>setState(()=>fileQuery=value),
              decoration:InputDecoration(prefixIcon:const Icon(Icons.search_rounded),
                hintText:s('searchFiles'), isDense:true))),
            IconButton(tooltip:s('sortFiles'),
              onPressed:()=>setState(()=>newestFirst=!newestFirst),
              icon:Icon(newestFirst?Icons.arrow_downward_rounded:Icons.arrow_upward_rounded)),
          ])),
          SizedBox(height:50,child:ListView(scrollDirection:Axis.horizontal,children:[
            for(final key in ['all','videoFiles','audioFiles','documentFiles','otherFiles'])
              Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:ChoiceChip(
                label:Text(s(key)),selected:selected==key,
                onSelected:(_)=>setState(()=>selected=key))),
          ])),
          Expanded(child:
        finished.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_open_rounded, size: 58,
                  color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12), Text(s('empty')),
              ])))
          : ListView.builder(padding: const EdgeInsets.all(14), itemCount: finished.length,
              itemBuilder: (_, i) => Column(children:[
                PremiumDownloadCard(item: finished[i], repo:widget.repo,
                  strings:widget.strings),
                if(!finished[i].isPlaylist && finished[i].path.isNotEmpty)
                  Align(alignment:AlignmentDirectional.centerEnd,child:TextButton.icon(
                    icon:const Icon(Icons.transform_rounded),
                    label:Text(s('convertMedia')),
                    onPressed:()=>showModalBottomSheet<void>(context:context,
                      isScrollControlled:true,useSafeArea:true,showDragHandle:true,
                      builder:(_)=>ConvertMediaSheet(item:finished[i],strings:widget.strings,repo:widget.repo)))),
              ])),
        ),
        ]),
        MediaPage(repo: widget.repo, strings: widget.strings, onAdd: widget.onAdd),
      ])),
    ]));
  }
}
