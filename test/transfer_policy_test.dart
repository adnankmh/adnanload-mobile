import 'package:flutter_test/flutter_test.dart';
import 'package:adnanload_mobile/core/transfer_policy.dart';
import 'package:adnanload_mobile/core/download_metrics.dart';
import 'package:adnanload_mobile/models/download_entry.dart';

void main() {
  test('Wi-Fi and offline gating applies to queued media', () {
    expect(TransferPolicy.mayStart(wifiOnly:true,hasWifi:false,hasNetwork:true,
      batteryPercent:100,charging:true,batteryFloor:25),isFalse);
    expect(TransferPolicy.mayStart(wifiOnly:true,hasWifi:true,hasNetwork:true,
      batteryPercent:100,charging:false,batteryFloor:25),isTrue);
    expect(TransferPolicy.mayStart(wifiOnly:false,hasWifi:false,hasNetwork:false,
      batteryPercent:100,charging:true,batteryFloor:0),isFalse);
  });
  test('Charging-only gates new jobs even above battery threshold', () {
    expect(TransferPolicy.mayStart(wifiOnly:false,hasWifi:false,hasNetwork:true,
      batteryPercent:100,charging:false,batteryFloor:0,chargingOnly:true),isFalse);
    expect(TransferPolicy.mayStart(wifiOnly:false,hasWifi:false,hasNetwork:true,
      batteryPercent:5,charging:true,batteryFloor:40,chargingOnly:true),isTrue);
    expect(TransferPolicy.mayStart(wifiOnly:true,hasWifi:false,hasNetwork:true,
      batteryPercent:100,charging:true,batteryFloor:0,chargingOnly:true),isFalse);
    expect(TransferPolicy.mayStart(wifiOnly:false,hasWifi:false,hasNetwork:false,
      batteryPercent:100,charging:true,batteryFloor:0,chargingOnly:true),isFalse);
    expect(TransferPolicy.mayStart(wifiOnly:false,hasWifi:false,hasNetwork:true,
      batteryPercent:100,charging:false,batteryFloor:0),isTrue);
  });
  test('Battery threshold is waived when charging', () {
    expect(TransferPolicy.mayStart(wifiOnly:false,hasWifi:false,hasNetwork:true,
      batteryPercent:10,charging:false,batteryFloor:25),isFalse);
    expect(TransferPolicy.mayStart(wifiOnly:false,hasWifi:false,hasNetwork:true,
      batteryPercent:10,charging:true,batteryFloor:25),isTrue);
  });
  test('Retry is bounded and restricted to transient errors', () {
    expect(TransferPolicy.shouldRetry('SocketException: connection reset',0),isTrue);
    expect(TransferPolicy.shouldRetry('HTTP 503',2),isTrue);
    expect(TransferPolicy.shouldRetry('HTTP 403 forbidden',0),isFalse);
    expect(TransferPolicy.shouldRetry('timeout',3),isFalse);
    expect(TransferPolicy.shouldRetry('timeout',0,enabled:false),isFalse);
    expect(TransferPolicy.retryDelay(1).inSeconds,10);
    expect(TransferPolicy.retryDelay(2).inSeconds,30);
    expect(TransferPolicy.retryDelay(3).inSeconds,90);
  });
  test('Retry metadata persists across app restarts', () {
    final item=DownloadEntry(id:'a',url:'https://example.com/a.pdf',name:'a.pdf',
      kind:'direct',status:'waiting',addedAt:100,retryAttempts:2,retryAt:200);
    final restored=DownloadEntry.fromJson(item.toJson());
    expect(restored.retryAttempts,2);
    expect(restored.retryAt,200);
  });
  test('Download metrics do not depend on stored URLs', () {
    final items=[
      DownloadEntry(id:'1',url:'https://example.org/a',name:'private-name',
        kind:'direct',status:'running',addedAt:1,speed:4096),
      DownloadEntry(id:'2',url:'https://example.org/b',name:'other',
        kind:'mp3',status:'complete',addedAt:2),
      DownloadEntry(id:'3',url:'https://example.org/c',name:'third',
        kind:'video',status:'waiting',addedAt:3,retryAt:10),
    ];
    final m=DownloadMetrics.fromEntries(items);
    expect(m.total,3);expect(m.running,1);expect(m.completed,1);
    expect(m.waiting,1);expect(m.retrying,1);
    expect(m.currentMbPerSecond,4096);
  });
}
