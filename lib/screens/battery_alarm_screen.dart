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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final Battery _battery = Battery();

  int _batteryLevel = 0;
  BatteryState? _batteryState;
  String? _selectedAudioPath;
  int _threshold = Preferences.defaultThreshold;
  bool _monitoring = false;
  bool _savingThreshold = false;
  StreamSubscription<BatteryState>? _batterySubscription;

  static const List<int> _thresholdOptions = [
    50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100,
  ];

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initForegroundTask();
    _loadPreferences();
    _initBatteryListener();
    _refreshMonitoringState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _batterySubscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMonitoringState();
    }
  }

  Future<void> _refreshMonitoringState() async {
    final isRunning = await FlutterForegroundTask.isRunningService;

    if (!mounted) return;

    setState(() {
      _monitoring = isRunning;
    });
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

  Future<void> _loadPreferences() async {
    try {
      final results = await Future.wait<Object?>([
        Preferences.loadRingtonePath(),
        Preferences.loadThreshold(),
      ]);

      if (!mounted) return;

      setState(() {
        _selectedAudioPath = results[0] as String?;
        _threshold = results[1] as int;
      });
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _saveThreshold(int? value) async {
    if (value == null || _monitoring || _savingThreshold) return;

    setState(() => _savingThreshold = true);

    try {
      await Preferences.saveThreshold(value);

      if (!mounted) return;

      setState(() => _threshold = value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm threshold saved: $value%')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save threshold: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingThreshold = false);
      }
    }
  }

  void _initBatteryListener() {
    _battery.batteryLevel.then((level) {
      if (!mounted) return;
      setState(() => _batteryLevel = level);
    });

    _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
      final level = await _battery.batteryLevel;

      if (!mounted) return;

      setState(() {
        _batteryState = state;
        _batteryLevel = level;
      });
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
    );

    if (!mounted || result == null || result.files.single.path == null) {
      return;
    }

    final sourcePath = result.files.single.path!;
    final fileName = sourcePath.split(Platform.pathSeparator).last;

    final dir = await getApplicationDocumentsDirectory();
    final ringtoneDir = Directory('${dir.path}/ringtones');

    if (!await ringtoneDir.exists()) {
      await ringtoneDir.create(recursive: true);
    }

    final newPath = '${ringtoneDir.path}/$fileName';
    await File(sourcePath).copy(newPath);
    await Preferences.saveRingtonePath(newPath);

    if (!mounted) return;

    setState(() => _selectedAudioPath = newPath);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarm sound saved')),
    );
  }

  Future<void> _startMonitoring() async {
    await _refreshMonitoringState();
    if (_monitoring) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'Battery Full Alarm',
      notificationText: 'Monitoring battery. Alarm threshold: $_threshold%.',
      callback: startCallback,
    );

    if (!mounted) return;

    setState(() => _monitoring = true);
  }

  Future<void> _stopMonitoring() async {
    await FlutterForegroundTask.stopService();

    if (!mounted) return;

    setState(() => _monitoring = false);
  }

  Color _batteryColor() {
    if (_batteryState == BatteryState.charging) return Colors.teal;
    if (_batteryLevel >= 90) return Colors.green;
    if (_batteryLevel >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _batteryIcon() {
    if (_batteryState == BatteryState.charging) {
      return Icons.battery_charging_full;
    }
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
        : 'Default Alarm';

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
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 18,
                ),
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
                            backgroundColor:
                                _batteryColor().withValues(alpha: 0.12),
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
                          Text(
                            'Battery Level',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_batteryLevel%',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(_batteryStatusText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarm Threshold',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _threshold,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixText: '%',
                        helperText:
                            'The alarm rings when charging reaches this level.',
                      ),
                      items: _thresholdOptions.map((value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value%'),
                        );
                      }).toList(),
                      onChanged: (_monitoring || _savingThreshold)
                          ? null
                          : _saveThreshold,
                    ),
                    if (_monitoring)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Stop monitoring to change the threshold.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('Alarm Sound'),
                subtitle: Text(label),
                trailing: IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Choose alarm sound',
                  onPressed: _monitoring ? null : _pickAudioFile,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _monitoring ? null : _startMonitoring,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Monitoring'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _monitoring ? _stopMonitoring : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Monitoring'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
