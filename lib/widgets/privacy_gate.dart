import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../services/download_repository.dart';

/// An in-app entry lock. Does not encrypt downloaded files or prevent access
/// through Android file managers. The OS remains responsible for device security.
class PrivacyGate extends StatefulWidget {
  final DownloadRepository repo;
  final Widget child;
  const PrivacyGate({super.key, required this.repo, required this.child});
  @override State<PrivacyGate> createState() => _PrivacyGateState();
}
class _PrivacyGateState extends State<PrivacyGate> with WidgetsBindingObserver {
  final input=TextEditingController();
  bool unlocked=false;
  bool checking=true;
  bool verifying=false;
  String error='';
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_load();}
  Future<void> _load() async {
    try {
      final enabled=await widget.repo.privacyLock.enabled;
      if(mounted)setState((){unlocked=!enabled;checking=false;error='';});
    } catch (_) {if(mounted)setState((){unlocked=false;checking=false;});}
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused || state==AppLifecycleState.hidden){
      if(mounted)setState((){checking=true;unlocked=false;input.clear();});
    } else if(state==AppLifecycleState.resumed) {
      _load();
    }
  }
  Future<void> _verify() async {
    if(verifying)return;
    setState(()=>verifying=true);
    try {
      final ok=await widget.repo.privacyLock.verify(input.text);
      if(mounted)setState((){unlocked=ok;error=ok?'':AppStrings(widget.repo.language).t('pinWrong');input.clear();});
    } catch (_) {if(mounted)setState(()=>error=AppStrings(widget.repo.language).t('pinWrong'));}
    finally{if(mounted)setState(()=>verifying=false);}
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);input.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    if(checking)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(unlocked)return widget.child;
    final t=AppStrings(widget.repo.language).t;
    return Scaffold(body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:430),
      child:Padding(padding:const EdgeInsets.all(28),child:Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Icon(Icons.lock_rounded,size:66,color:Theme.of(context).colorScheme.primary),
          const SizedBox(height:18),Text(t('pinLock'),textAlign:TextAlign.center,
            style:Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:16),TextField(controller:input,obscureText:true,
            keyboardType:TextInputType.number,maxLength:12,
            onSubmitted:(_)=>_verify(),decoration:InputDecoration(labelText:t('pinPrompt'))),
          if(error.isNotEmpty)Text(error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
          const SizedBox(height:10),FilledButton.icon(onPressed:verifying?null:_verify,
            icon:const Icon(Icons.lock_open_rounded),label:Text(t('verify'))),
        ]))))));
  }
}
