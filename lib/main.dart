import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'dart:math';

void main() {
  runApp(const MyApp());
}

double _angle(double x, double y, double z){
  double magnitude = sqrt(x * x + y * y + z * z);

  if (magnitude==0){
    return 0;
  }
  
  double ratio = z.abs()/magnitude;
  
  double angle = (acos(ratio)) * 180 / pi;

  return angle;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AccelerometerDemoPage(),
    );
  }
}

class AccelerometerDemoPage extends StatelessWidget {
  const AccelerometerDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accelerometer Demo'),
      ),
      body: Center(
        child: StreamBuilder<AccelerometerEvent>(
          stream: accelerometerEventStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Sensor error:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              );
            }

            if (!snapshot.hasData) {
              return const Text(
                'Waiting for sensor data...',
                style: TextStyle(fontSize: 22),
              );
            }

            final event = snapshot.data!;
            final double displayangle = 90 - _angle(event.x, event.y, event.z);

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'X: ${event.x.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Y: ${event.y.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Z: ${event.z.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Angle: ${displayangle.toStringAsFixed(1)}'
                )
              ],
            );
          },
        ),
      ),
    );
  }
}

