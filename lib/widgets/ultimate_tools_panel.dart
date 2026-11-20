import '../core/backup_import_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_strings.dart';
import '../services/backup_service.dart';
import '../services/download_repository.dart';
import '../services/storage_audit.dart';

/// Explicit opt-in actions. History backups are NEVER silently uploaded.
class UltimateToolsPanel extends StatefulWidget {
  final DownloadRepository repo;
  final AppStrings strings;
  const UltimateToolsPanel({super.key,required this.repo,required this.strings});
  @override State<UltimateToolsPanel> createState() => _UltimateToolsPanelState();
}

class _UltimateToolsPanelState extends State<UltimateToolsPanel> {
  bool busy=false;
  bool pinEnabled=false;
  @override void initState(){super.initState();_refreshPin();}
  Future<void> _refreshPin() async {
    final active=await widget.repo.privacyLock.enabled;
    if(mounted) setState(()=>pinEnabled=active);
  }
  void _showMessage(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<String?> _askPin({bool confirm = false}) async {
    final ctrl=TextEditingController();
    final t=widget.strings.t;
    try {return await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(t('pinLock')),
      content:TextField(controller:ctrl,autofocus:true,obscureText:true,
        keyboardType:TextInputType.number,
        maxLength:12,decoration:InputDecoration(hintText:t('pinPrompt'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,ctrl.text),child:Text(t('confirm')))]));
    } finally {ctrl.dispose();}
  }

  Future<void> _updatePin() async {
    try {
      final pin=await _askPin();if(pin==null)return;
      if(pinEnabled){
        final ok=await widget.repo.privacyLock.disable(pin);
        if(!ok){_showMessage(widget.strings.t('pinWrong'));return;}
      } else {
        if(!RegExp(r'^\d{6,12}$').hasMatch(pin)){
          _showMessage(widget.strings.t('pinPrompt'));return;
        }
        final again=await _askPin(confirm:true);
        if(again!=pin){_showMessage(widget.strings.t('pinWrong'));return;}
        await widget.repo.privacyLock.enable(pin);
      }
      await _refreshPin();_showMessage(widget.strings.t('pinSaved'));
    }catch(e){_showMessage(e.toString());}
  }

  Future<void> _export() async {
    if(busy)return;
    setState(()=>busy=true);
    try {
      final path=await BackupService.writeBackup(widget.repo.createBackup());
      if(!mounted)return;
      await SharePlus.instance.share(ShareParams(files:[XFile(path)],text:'ADNANLOAD backup'));
    }catch(e){_showMessage(e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _import() async {
    if(busy)return;
    final t=widget.strings.t;
    final approved=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(t('backupImport')),content:Text(t('backupWarning')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('confirm')))]));
    if(approved!=true||!mounted)return;
    setState(()=>busy=true);
    try {
      final file=await FilePicker.pickFile(type:FileType.custom,allowedExtensions:['json']);
      if(file==null)return;
      // Android SAF documents may not expose a size or local path. Enforce
      // the byte limit while reading, before decoding or parsing JSON.
      BackupImportReader.checkReportedLength(file.lengthSync());
      final text=await BackupImportReader.decodeStream(file.readAsByteStream());
      final count=await widget.repo.restoreBackup(BackupService.parse(text));
      _showMessage('${t('restoreSuccess')}: $count');
    }catch(e){_showMessage(e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _duplicates() async {
    setState(()=>busy=true);
    try {
      final groups=await StorageAudit.findDuplicates(widget.repo.items);
      if(!mounted)return;
      final t=widget.strings.t;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text(t('duplicates')),
        content:SizedBox(width:340,child:SingleChildScrollView(child:Text(groups.isEmpty
          ?t('noDuplicates')
          :groups.map((group)=>group.map((item)=>item.name).join('\n')).join('\n\n────────\n\n')))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('close')))]));
    }catch(e){_showMessage(e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _clean() async {
    setState(()=>busy=true);
    try{final count=await StorageAudit.clearOldTemporaryFiles();
      _showMessage('${widget.strings.t('cacheCleaned')}: $count');}
    catch(e){_showMessage(e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  @override Widget build(BuildContext context){
    final t=widget.strings.t;
    return Column(children:[
      Card(child:Column(children:[
        ListTile(leading:const Icon(Icons.lock_outline_rounded),
          title:Text(t('pinLock')),
          subtitle:Text(t('pinHint')),
          trailing:Text(pinEnabled?t('pinDisable'):t('pinEnable')),
          onTap:busy?null:_updatePin),
      ])),
      Card(child:Column(children:[
        ListTile(leading:const Icon(Icons.backup_outlined),title:Text(t('backupExport')),
          subtitle:Text(t('backupWarning')),onTap:busy?null:_export),
        ListTile(leading:const Icon(Icons.settings_backup_restore),title:Text(t('backupImport')),
          onTap:busy?null:_import),
      ])),
      Card(child:Column(children:[
        ListTile(leading:const Icon(Icons.filter_none_rounded),title:Text(t('duplicateScan')),
          onTap:busy?null:_duplicates),
        ListTile(leading:const Icon(Icons.cleaning_services_outlined),title:Text(t('cleanCache')),
          onTap:busy?null:_clean),
      ])),
    ]);
  }
}
