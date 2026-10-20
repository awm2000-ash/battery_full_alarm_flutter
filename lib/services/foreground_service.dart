import 'dart:async';
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
  late final AudioPlayer _player;

  bool _isAlarmRinging = false;
  int _threshold = Preferences.defaultThreshold;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    print('Foreground task started');
    _player = AudioPlayer();

    try {
      _threshold = await Preferences.loadThreshold();
    } catch (e) {
      _threshold = Preferences.defaultThreshold;
      print('Error loading battery threshold; using $_threshold%: $e');
    }

    FlutterForegroundTask.updateService(
      notificationTitle: 'Battery Full Alarm',
      notificationText: 'Monitoring battery. Alarm threshold: $_threshold%.',
    );

    await _checkBattery();
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
      'Battery check => level=$level, state=$state, '
      'threshold=$_threshold, ringing=$_isAlarmRinging',
    );

    if (charging && level >= _threshold && !_isAlarmRinging) {
      _isAlarmRinging = true;
      await _startAlarm();
    } else if ((!charging || level < _threshold) && _isAlarmRinging) {
      // Stop playback if the charger is unplugged or the level drops below
      // the threshold. Monitoring itself continues.
      await _stopAlarm();
    }
  }

  Future<void> _startAlarm() async {
    print('Starting alarm...');

    try {
      final path = await Preferences.loadRingtonePath();

      if (path != null && path.isNotEmpty) {
        await _player.setFilePath(path);
      } else {
        await _player.setAsset('lib/assets/alarm.mp3');
      }

      await _player.setLoopMode(LoopMode.one);

      // Do not await playback: looping playback may remain active indefinitely.
      unawaited(_playAlarm());

      FlutterForegroundTask.updateService(
        notificationTitle: 'Battery Threshold Reached!',
        notificationText: 'Battery reached $_threshold%. Unplug to stop.',
      );
    } catch (e) {
      _isAlarmRinging = false;
      print('Error starting alarm: $e');
    }
  }

  Future<void> _playAlarm() async {
    try {
      await _player.play();
      print('Alarm playback completed');
    } catch (e) {
      _isAlarmRinging = false;
      print('Alarm playback error: $e');
    }
  }

  Future<void> _stopAlarm() async {
    print('Stopping alarm...');

    try {
      await _player.stop();
    } catch (e) {
      print('Error stopping alarm: $e');
    }

    _isAlarmRinging = false;

    FlutterForegroundTask.updateService(
      notificationTitle: 'Battery Full Alarm',
      notificationText: 'Monitoring battery. Alarm threshold: $_threshold%.',
    );
  }

  @override
  void onButtonPressed(String id) {
    if (id == 'stop') {
      unawaited(_stopMonitoringFromNotification());
    }
  }

  Future<void> _stopMonitoringFromNotification() async {
    print('Notification Stop pressed');

    await _stopAlarm();
    await FlutterForegroundTask.stopService();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print('Service destroyed');
    await _player.dispose();
  }
}
