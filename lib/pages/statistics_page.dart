import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class Statistics extends StatelessWidget {
  const Statistics({
    super.key,
    required this.totalScreenTime,
    required this.totalBadPostureTime,
    required this.score,
  });

  final int totalScreenTime;
  final int totalBadPostureTime;
  final double score;

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return '${remainingSeconds}s';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final goodPostureTime = max(0, totalScreenTime - totalBadPostureTime);
    final scorePercent = score.round();

    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 35, left: 20, right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text(
                            'Statistics',
                            style: TextStyle(fontSize: 50),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: FloatingActionButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Icon(Icons.arrow_back),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today', style: TextStyle(fontSize: 25)),
                        const SizedBox(height: 20),
                        Text(
                          'Daily Usage: ${formatTime(totalScreenTime)}',
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Good posture: ${formatTime(goodPostureTime)}',
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Bad posture: ${formatTime(totalBadPostureTime)}',
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Score: $scorePercent',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        const Text('This week', style: TextStyle(fontSize: 25)),
                        const SizedBox(height: 20),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('S'),
                                SizedBox(height: 5),
                                Text('73'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('M'),
                                SizedBox(height: 5),
                                Text('95'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('T'),
                                SizedBox(height: 5),
                                Text('62'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('W'),
                                SizedBox(height: 5),
                                Text('72'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('TH'),
                                SizedBox(height: 5),
                                Text('69'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('F'),
                                SizedBox(height: 5),
                                Text('70'),
                              ],
                            ),
                            Column(
                              children: [
                                Text('SA'),
                                SizedBox(height: 5),
                                Text('87'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          height: 200,
                          width: 360,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 20,
                                    interval: 1,
                                    getTitlesWidget:
                                        (double value, TitleMeta meta) {
                                      switch (value.toInt()) {
                                        case 0:
                                          return const Text('S');
                                        case 1:
                                          return const Text('M');
                                        case 2:
                                          return const Text('T');
                                        case 3:
                                          return const Text('W');
                                        case 4:
                                          return const Text('TH');
                                        case 5:
                                          return const Text('F');
                                        case 6:
                                          return const Text('SA');
                                        default:
                                          return const Text('');
                                      }
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: const [
                                    FlSpot(0, 30),
                                    FlSpot(1, 60),
                                    FlSpot(2, 50),
                                    FlSpot(3, 30),
                                    FlSpot(4, 60),
                                    FlSpot(5, 50),
                                    FlSpot(6, 30),
                                  ],
                                  isCurved: false,
                                  color: Colors.black,
                                  barWidth: 4,
                                  dotData: const FlDotData(show: true),
                                ),
                              ],
                              gridData: const FlGridData(show: true),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
