import 'package:flutter/material.dart';
import 'screens/battery_alarm_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BatteryFullAlarmApp());
}

class BatteryFullAlarmApp extends StatelessWidget {
  const BatteryFullAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battery Full Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: BatteryAlarmScreen(),
    );
  }
}
