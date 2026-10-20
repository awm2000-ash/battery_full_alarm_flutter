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
        //colorSchemeSeed: const Color.fromARGB(255, 247, 1, 169),
        useMaterial3: true,
      ),
      home: const BatteryAlarmScreen(),
    );
  }
}
