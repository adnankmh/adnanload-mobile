import 'package:flutter/material.dart';
import '../core/app_strings.dart';
import '../services/download_repository.dart';

/// Manual stable-channel updates from Settings. Keeps error details private:
/// extractor exceptions may include signed URLs, tokens or local paths.
class SettingsMediaEngineTile extends StatefulWidget {
  const SettingsMediaEngineTile({
    super.key,
    required this.repo,
    required this.strings,
  });

  final DownloadRepository repo;
  final AppStrings strings;

  @override
  State<SettingsMediaEngineTile> createState() =>
      _SettingsMediaEngineTileState();
}

class _SettingsMediaEngineTileState extends State<SettingsMediaEngineTile> {
  bool _updating = false;

  Future<void> _updateEngine() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await widget.repo.updateMediaEngine();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.strings.t('engineUpdateSuccess')),
      ));
    } catch (_) {
      if (!mounted) return;
      // Do not expose extractor exceptions containing URLs or credentials.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.strings.t('engineUpdateFailed')),
      ));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.strings.t;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(children: [
          SwitchListTile(
            secondary: const Icon(Icons.autorenew_rounded),
            title: Text(t('autoEngineUpdates')),
            subtitle: Text(t('engineUpdatePolicy')),
            value: widget.repo.autoUpdateMediaEngine,
            onChanged: _updating
                ? null
                : (value) => widget.repo.updateSettings(
                    newAutoUpdateMediaEngine: value),
          ),
          ListTile(
            key: const Key('settings-media-engine-update'),
            leading: const Icon(Icons.system_update_alt_rounded),
            title: Text(_updating
                ? t('engineUpdateStarted')
                : t('updateEngine')),
            subtitle: Text(t('engineUpdateInfo')),
            trailing: _updating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: !_updating,
            onTap: _updating ? null : _updateEngine,
          ),
        ]),
      ),
    );
  }
}
