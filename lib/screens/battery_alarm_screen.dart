import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/foreground_service.dart';
import '../utils/preferences.dart';

class BatteryAlarmScreen extends StatefulWidget {
  const BatteryAlarmScreen({super.key});

  @override
  State<BatteryAlarmScreen> createState() => _BatteryAlarmScreenState();
}

class _BatteryAlarmScreenState extends State<BatteryAlarmScreen>
    with SingleTickerProviderStateMixin {
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  BatteryState? _batteryState;
  String? _selectedAudioPath;
  bool _monitoring = false;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _activateTaskHandler();
    _loadPreferences();
    _initBatteryListener();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'battery_full_alarm_channel',
        channelName: 'Battery Full Alarm',
        channelDescription: 'Monitoring battery in background',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        buttons: [NotificationButton(id: 'stop', text: 'Stop')],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 2000,
        allowWakeLock: true,
        isOnceEvent: false,
      ),
    );
  }

  void _activateTaskHandler() {
    FlutterForegroundTask.setTaskHandler(BatteryAlarmTaskHandler());
  }

  Future<void> _loadPreferences() async {
    final path = await Preferences.loadRingtonePath();
    setState(() => _selectedAudioPath = path);
  }

  void _initBatteryListener() {
    _battery.batteryLevel.then((lvl) {
      setState(() => _batteryLevel = lvl);
    });

    _battery.onBatteryStateChanged.listen((BatteryState state) async {
      final lvl = await _battery.batteryLevel;
      setState(() {
        _batteryState = state;
        _batteryLevel = lvl;
      });
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );

    if (result != null && result.files.single.path != null) {
      final sourcePath = result.files.single.path!;
      final fileName = sourcePath.split('/').last;

      final dir = await getApplicationDocumentsDirectory();
      final ringtoneDir = Directory('${dir.path}/ringtones');
      if (!(await ringtoneDir.exists())) {
        await ringtoneDir.create(recursive: true);
      }

      final newPath = '${ringtoneDir.path}/$fileName';
      await File(sourcePath).copy(newPath);

      await Preferences.saveRingtonePath(newPath);

      setState(() => _selectedAudioPath = newPath);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alarm sound saved")),
      );
    }
  }

  Future<void> _startMonitoring() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Battery Full Alarm active',
      notificationText: 'Monitoring battery in background',
      callback: startCallback,
    );
    setState(() => _monitoring = true);
  }

  Future<void> _stopMonitoring() async {
    await FlutterForegroundTask.stopService();
    setState(() => _monitoring = false);
  }

  Color _batteryColor() {
    if (_batteryState == BatteryState.charging) return Colors.teal;
    if (_batteryLevel >= 90) return Colors.green;
    if (_batteryLevel >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _batteryIcon() {
    if (_batteryState == BatteryState.charging)
      return Icons.battery_charging_full;
    if (_batteryLevel >= 90) return Icons.battery_full;
    if (_batteryLevel >= 50) return Icons.battery_std;
    return Icons.battery_alert;
  }

  String get _batteryStatusText {
    switch (_batteryState) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.full:
        return 'Full';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _selectedAudioPath != null
        ? _selectedAudioPath!.split('/').last
        : "Default Alarm";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Full Alarm'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (_, __) {
                        final scale = (_batteryState == BatteryState.charging)
                            ? 1.0 + _animController.value * 0.08
                            : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: _batteryColor().withOpacity(0.12),
                            child: Icon(
                              _batteryIcon(),
                              color: _batteryColor(),
                              size: 44,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Battery Level",
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("$_batteryLevel%",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Text(_batteryStatusText),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _batteryLevel / 100,
                            minHeight: 8,
                            color: _batteryColor(),
                            backgroundColor: Colors.grey[200],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text("Alarm Sound"),
                subtitle: Text(label),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text("Choose"),
                  onPressed: _pickAudioFile,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: Icon(
                        _monitoring ? Icons.pause_circle : Icons.play_circle),
                    label: Text(
                        _monitoring ? "Monitoring..." : "Start Monitoring"),
                    onPressed: _monitoring ? null : _startMonitoring,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.stop_circle),
                    label: const Text("Stop"),
                    onPressed: _monitoring ? _stopMonitoring : null,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              "Alarm rings when charging reaches 95%.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
