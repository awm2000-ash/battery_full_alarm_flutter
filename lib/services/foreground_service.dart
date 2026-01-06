import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/preferences.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BatteryAlarmTaskHandler());
}

class BatteryAlarmTaskHandler extends TaskHandler {
  final Battery _battery = Battery();
  final _player = AudioPlayer();
  bool _isAlarmRinging = false;
  static const threshold = 95;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    print("Foreground task started");
    FlutterForegroundTask.updateService(
      notificationTitle: 'Battery Full Alarm',
      notificationText: 'Monitoring battery...',
    );
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    await _checkBattery();
  }

  Future<void> _checkBattery() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;

    final charging =
        state == BatteryState.charging || state == BatteryState.full;

    print(
        "Battery check => level=$level, state=$state, ringing=$_isAlarmRinging");

    if (charging && level >= threshold && !_isAlarmRinging) {
      _isAlarmRinging = true;
      await _startAlarm();
    } else if ((!charging || level < threshold) && _isAlarmRinging) {
      await _stopAlarm();
    }
  }

  Future<void> _startAlarm() async {
    print("Starting alarm...");
    final path = await Preferences.loadRingtonePath();

    try {
      if (path != null && path.isNotEmpty) {
        await _player.setFilePath(path);
      } else {
        await _player.setAsset('lib/assets/alarm.mp3');
      }

      await _player.setLoopMode(LoopMode.one);
      await _player.play();

      print("Alarm is PLAYING successfully");
    } catch (e) {
      print("Error playing alarm: $e");
    }

    FlutterForegroundTask.updateService(
      notificationTitle: 'Battery Full!',
      notificationText: 'Reached $threshold%. Unplug to stop.',
    );
  }

  Future<void> _stopAlarm() async {
    print("Stopping alarm...");
    try {
      await _player.stop();
    } catch (_) {}
    _isAlarmRinging = false;

    FlutterForegroundTask.updateService(
      notificationTitle: 'Battery Full Alarm',
      notificationText: 'Monitoring battery...',
    );
  }

  @override
  void onButtonPressed(String id) {
    if (id == 'stop') {
      _stopAlarm();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print("Service destroyed");
    await _player.dispose();
  }
}
