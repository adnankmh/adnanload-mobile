import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../core/theme.dart';
import '../services/download_repository.dart';
import '../widgets/ultimate_tools_panel.dart';
import 'package:flutter/services.dart';


class SettingsPage extends StatelessWidget {
  final DownloadRepository repo;
  final AppStrings strings;
  const SettingsPage({super.key,required this.repo,required this.strings});
  @override Widget build(BuildContext context){
    final t=strings.t;
    return ListView(padding:const EdgeInsets.all(15),children:[
      const SizedBox(height:5),
      Text(t('settings'),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
      const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        ListTile(leading:const Icon(Icons.translate_rounded),title:Text(t('language')),
          trailing:DropdownButton<String>(value:repo.language,underline:const SizedBox.shrink(),
            items:['ar','en'].map((v)=>DropdownMenuItem(value:v,child:Text(t(v=='ar'?'arabic':'english')))).toList(),
            onChanged:(v)=>repo.updateSettings(newLanguage:v))),
        const Divider(),
        ListTile(leading:const Icon(Icons.palette_outlined),title:Text(t('theme')),
          trailing:DropdownButton<String>(value:repo.theme,underline:const SizedBox.shrink(),
            items:BrandThemes.names.map((v)=>DropdownMenuItem(value:v,child:Text(t(v)))).toList(),
            onChanged:(v)=>repo.updateSettings(newTheme:v))),
        const Divider(),
        ListTile(leading:const Icon(Icons.schedule_rounded),
          title:Text(t('androidScheduler')), subtitle:Text(t('androidSchedulerHint'))),
        SwitchListTile(secondary:const Icon(Icons.wifi_rounded),title:Text(t('wifiOnly')),
          value:repo.wifiOnly,onChanged:(v)=>repo.updateSettings(newWifiOnly:v)),
        SwitchListTile(secondary:const Icon(Icons.autorenew_rounded),
          title:Text(t('autoRetryNetwork')),
          subtitle:Text(t('autoRetryHint')),
          value:repo.automaticRetry,
          onChanged:(v)=>repo.updateSettings(newAutomaticRetry:v)),
        ListTile(leading:const Icon(Icons.battery_saver_rounded),
          title:Text(t('minimumBattery')),
          subtitle:Text(t('batteryQueuedOnly')),
          trailing:DropdownButton<int>(value:repo.batteryFloor,
            items:[0,15,25,40].map((v)=>DropdownMenuItem(value:v,
              child:Text(v==0?t('noLimit'):'$v%'))).toList(),
            onChanged:(v)=>repo.updateSettings(newBatteryFloor:v))),
        SwitchListTile(secondary:const Icon(Icons.notifications_outlined),title:Text(t('notification')),
          value:repo.notifications,onChanged:(v)=>repo.updateSettings(newNotifications:v)),
        ListTile(leading:const Icon(Icons.storage_rounded),title:Text(t('storageLimit')),
          subtitle:Text(t('storageLimitHint')),
          trailing:DropdownButton<int>(value:repo.storageLimitMb,
            items:[0,512,1024,2048,4096,8192,16384].map((v)=>
              DropdownMenuItem(value:v,child:Text(v==0?t('noLimit'):'$v MB'))).toList(),
            onChanged:(v)=>repo.updateSettings(newStorageLimitMb:v))),
        ListTile(leading:const Icon(Icons.layers_rounded),title:Text(t('maxConcurrent')),
          trailing:DropdownButton<int>(value:repo.maxConcurrent,items:[1,2,3,4,5,6].map((v)=>
            DropdownMenuItem(value:v,child:Text('$v'))).toList(),
            onChanged:(v)=>repo.updateSettings(newMaxConcurrent:v))),
        ListTile(leading:const Icon(Icons.segment_rounded),title:Text(t('parallelParts')),
          trailing:DropdownButton<int>(value:repo.parallelChunks,items:[1,2,4,6,8].map((v)=>
            DropdownMenuItem(value:v,child:Text('$v'))).toList(),
            onChanged:(v)=>repo.updateSettings(newParallelChunks:v))),
        ListTile(leading:const Icon(Icons.text_fields_rounded),title:Text(t('fontSize')),
          subtitle:Slider(min:.9,max:1.35,divisions:9,value:repo.fontScale,
            label:'${(repo.fontScale*100).round()}%',
            onChanged:(v)=>repo.updateSettings(newFontScale:v))),
        Padding(padding:const EdgeInsets.all(12),child:Text(t('directThreadsHint'),
          style:Theme.of(context).textTheme.bodySmall)),
      ]))),
      const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t('security'),style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:8),Text(t('copyright')),
        const SizedBox(height:12),Text(t('storage')),
        const SizedBox(height:12),Text(t('permission')),
        const SizedBox(height:12),Text(t('fileSafety')),
      ]))),
      const SizedBox(height:16),
      UltimateToolsPanel(repo:repo,strings:strings),
      const SizedBox(height:16),
      Card(child:Column(children:[
        ListTile(leading:const Icon(Icons.health_and_safety_outlined),
          title:Text(t('healthCenter')),
          subtitle:Text(t('healthPrivacy')),
          onTap:() async {
            final report=await repo.downloadHealthSummary();
            if(!context.mounted)return;
            showDialog<void>(context:context,builder:(c)=>AlertDialog(
              title:Text(t('healthCenter')),content:SelectableText(report),
              actions:[TextButton(onPressed:()=>Navigator.pop(c),child:Text(t('close')))]));
          }),
        ListTile(leading:const Icon(Icons.monitor_heart_outlined),
          title:Text(t('diagnostics')),
          subtitle:Text(t('diagnosticsPrivacy')),
          onTap:(){
            showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
              title:Text(t('diagnostics')),
              content:SingleChildScrollView(child:SelectableText(repo.diagnosticsSummary())),
              actions:[
                TextButton(onPressed:(){
                  Clipboard.setData(ClipboardData(text:repo.diagnosticsSummary()));
                  Navigator.pop(dialogContext);
                },child:Text(t('copy'))),
                FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:Text(t('close'))),
              ],
            ));
          }),
      ])),
      const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(13),child:Column(children:[
        SwitchListTile(secondary:const Icon(Icons.autorenew_rounded),
          title:Text(t('autoEngineUpdates')), subtitle:Text(t('engineUpdatePolicy')),
          value:repo.autoUpdateMediaEngine,
          onChanged:(v)=>repo.updateSettings(newAutoUpdateMediaEngine:v)),
        ListTile(leading:const Icon(Icons.system_update_alt_rounded),title:Text(t('updateEngine')),
          subtitle:Text(t('engineUpdateInfo')),
          onTap:() async {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('engineUpdateStarted'))));
            try {
              await repo.updateMediaEngine();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content:Text(t('engineUpdateSuccess'))));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content:Text('${t('engineUpdateFailed')}: $e')));
            }
          }),
      ]))),
      const SizedBox(height:16),
      Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
        Icon(Icons.workspace_premium_rounded,size:42,color:Theme.of(context).colorScheme.primary),
        const SizedBox(height:8),const Text('ADNANLOAD MOBILE',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
        Text('${t('version')} 2.2.2 · Flutter / Android'),
        const SizedBox(height:12),Text(t('author'),textAlign:TextAlign.center),
      ]))),
    ]);
  }
}
