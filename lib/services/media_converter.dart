import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import '../core/url_guard.dart';

/// Convert app-owned, completed files only. Never overwrites the input.
class MediaConverter {
  static const formats = ['mp3','m4a','flac','wav','opus','mp4','webm'];
  static bool validFormat(String format)=>formats.contains(format.toLowerCase());

  static Future<String> convert(String input, String target) async {
    target=target.toLowerCase();
    if (!validFormat(target)) throw const FormatException('Unsupported format');
    final source=File(input);
    if(!await source.exists()) throw const FileSystemException('Input missing');
    final fileName=source.uri.pathSegments.last;
    final base=fileName.contains('.')?fileName.substring(0,fileName.lastIndexOf('.')):fileName;
    final safeBase=UrlGuard.safeName(base);
    final folder=source.parent;
    var file=File('${folder.path}${Platform.pathSeparator}$safeBase.$target');
    var index=1;
    while(await file.exists() || file.path==source.path){
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
    final session=await FFmpegKit.executeWithArguments(args);
    final code=await session.getReturnCode();
    if(!ReturnCode.isSuccess(code) || !await file.exists()) {
      if(await file.exists()) await file.delete();
      throw StateError('FFmpeg conversion failed');
    }
    return file.path;
  }
}
