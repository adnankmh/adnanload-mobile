import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import '../core/url_guard.dart';
import '../core/media_conversion_guard.dart';

/// Convert app-owned, completed files only. Never overwrites the input.
class MediaConverter {
  static const formats = ['mp3','m4a','flac','wav','opus','mp4','webm'];
  static bool validFormat(String format)=>formats.contains(format.toLowerCase());

  static Future<String> convert(String input, String target) async {
    target=target.toLowerCase();
    if (!validFormat(target)) throw const FormatException('Unsupported format');
    final source=File(input);
    final sourceSnapshot = await MediaConversionGuard.captureSource(source);
    final fileName=source.uri.pathSegments.last;
    final base=fileName.contains('.')?fileName.substring(0,fileName.lastIndexOf('.')):fileName;
    final safeBase=UrlGuard.safeName(base);
    final folder=source.parent;
    var file=File('${folder.path}${Platform.pathSeparator}$safeBase.$target');
    var index=1;
    while(await MediaConversionGuard.destinationOccupied(file) || file.path==source.path){
      file=File('${folder.path}${Platform.pathSeparator}${safeBase}_converted_${index++}.$target');
    }
    final args=<String>['-nostdin','-hide_banner','-loglevel','error','-n',
      '-i',source.path];
    switch(target){
      case 'mp3': args.addAll(['-vn','-c:a','libmp3lame','-b:a','192k']);
      case 'm4a': args.addAll(['-vn','-c:a','aac','-b:a','192k']);
      case 'flac': args.addAll(['-vn','-c:a','flac']);
      case 'wav': args.addAll(['-vn','-c:a','pcm_s16le']);
      case 'opus': args.addAll(['-vn','-c:a','libopus','-b:a','160k']);
      case 'mp4': args.addAll(['-c:v','mpeg4','-q:v','5','-c:a','aac','-movflags','+faststart']);
      case 'webm': args.addAll(['-c:v','libvpx','-b:v','1M','-c:a','libopus']);
    }
    args.add(file.path);
    try {
      final session = await FFmpegKit.executeWithArguments(args);
      final code = await session.getReturnCode();
      // A successful FFmpeg exit alone does not prove a usable output.
      // The input must still be the same file and the output must be
      // nonempty, regular and distinct from the original input.
      if (!ReturnCode.isSuccess(code) ||
          !await MediaConversionGuard.sourceUnchanged(source, sourceSnapshot) ||
          !await MediaConversionGuard.outputIsUsable(file, sourceSnapshot)) {
        throw StateError('FFmpeg conversion failed or files changed');
      }
      return file.path;
    } catch (_) {
      await MediaConversionGuard.removePartialOutput(file);
      rethrow;
    }
  }
}
