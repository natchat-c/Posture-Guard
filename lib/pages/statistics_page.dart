import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';

class Statistics extends StatelessWidget {
  const Statistics({super.key});

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return '${remainingSeconds}s';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();

    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
    }

    return 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  StatisticsData _calculateStats(DataSnapshot snapshot) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    // Sunday = 0, Monday = 1, Tuesday = 2, ..., Saturday = 6
    final startOfWeek = startOfToday.subtract(
      Duration(days: startOfToday.weekday % 7),
    );

    final screenTimeByDay = List<int>.filled(7, 0);
    final badPostureByDay = List<int>.filled(7, 0);
    final scoreByDay = List<double>.filled(7, 0);

    final data = snapshot.value;

    debugPrint('Firebase statistics data: $data');

    if (data is! Map) {
      return const StatisticsData(
        totalScreenTime: 0,
        totalBadPostureTime: 0,
        weeklyScores: [0, 0, 0, 0, 0, 0, 0],
      );
    }

    final firebaseMap = Map<dynamic, dynamic>.from(data);

    // Case 1:
    // Firebase stores one direct statistics record.
    //
    // Example:
    // {
    //   date: "2026-07-05",
    //   goodPostureSeconds: 145,
    //   score: 100,
    //   scorePercent: 100,
    //   totalBadPostureSeconds: 0,
    //   totalScreenTimeSeconds: 145,
    //   updatedAt: 1783220879164
    // }
    if (firebaseMap.containsKey('totalScreenTimeSeconds')) {
      final date = _parseDate(firebaseMap['date']) ?? startOfToday;
      final recordDay = DateTime(date.year, date.month, date.day);

      final isThisWeek =
          !recordDay.isBefore(startOfWeek) &&
          recordDay.isBefore(startOfWeek.add(const Duration(days: 7)));

      if (isThisWeek) {
        final dayIndex = recordDay.difference(startOfWeek).inDays;

        screenTimeByDay[dayIndex] = _toInt(
          firebaseMap['totalScreenTimeSeconds'],
        );

        badPostureByDay[dayIndex] = _toInt(
          firebaseMap['totalBadPostureSeconds'],
        );

        scoreByDay[dayIndex] = _toInt(
          firebaseMap['scorePercent'] ?? firebaseMap['score'],
        ).toDouble();
      }
    }
    // Case 2:
    // Firebase stores many daily records.
    //
    // Example:
    // {
    //   "2026-07-05": {
    //     date: "2026-07-05",
    //     goodPostureSeconds: 145,
    //     scorePercent: 100,
    //     totalBadPostureSeconds: 0,
    //     totalScreenTimeSeconds: 145
    //   }
    // }
    else {
      for (final entry in firebaseMap.entries) {
        final record = entry.value;

        if (record is! Map) continue;

        final map = Map<dynamic, dynamic>.from(record);

        final date = _parseDate(map['date'] ?? entry.key);

        if (date == null) continue;

        final recordDay = DateTime(date.year, date.month, date.day);

        final isThisWeek =
            !recordDay.isBefore(startOfWeek) &&
            recordDay.isBefore(startOfWeek.add(const Duration(days: 7)));

        if (!isThisWeek) continue;

        final dayIndex = recordDay.difference(startOfWeek).inDays;

        screenTimeByDay[dayIndex] = _toInt(map['totalScreenTimeSeconds']);

        badPostureByDay[dayIndex] = _toInt(map['totalBadPostureSeconds']);

        scoreByDay[dayIndex] = _toInt(
          map['scorePercent'] ?? map['score'],
        ).toDouble();
      }
    }

    final todayIndex = startOfToday.difference(startOfWeek).inDays;

    return StatisticsData(
      totalScreenTime: screenTimeByDay[todayIndex],
      totalBadPostureTime: badPostureByDay[todayIndex],
      weeklyScores: scoreByDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final databaseRef = FirebaseDatabase.instance.ref(
      'users/demo_user/daily_stats',
    );

    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: databaseRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading statistics',
                style: TextStyle(fontSize: 20),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = _calculateStats(snapshot.data!.snapshot);

          return _buildStatisticsPage(context, stats);
        },
      ),
    );
  }

  Widget _buildStatisticsPage(BuildContext context, StatisticsData stats) {
    final goodPostureTime = max(
      0,
      stats.totalScreenTime - stats.totalBadPostureTime,
    );

    final scorePercent = stats.score.round();

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 35, left: 20, right: 20),
          child: Column(
            children: [
              SizedBox(
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Center(
                      child: Text('Statistics', style: TextStyle(fontSize: 50)),
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
                      'Daily Usage: ${formatTime(stats.totalScreenTime)}',
                      style: const TextStyle(fontSize: 20),
                    ),

                    Text(
                      'Good posture: ${formatTime(goodPostureTime)}',
                      style: const TextStyle(fontSize: 20),
                    ),

                    Text(
                      'Bad posture: ${formatTime(stats.totalBadPostureTime)}',
                      style: const TextStyle(fontSize: 20),
                    ),

                    Text(
                      'Score: $scorePercent',
                      style: const TextStyle(fontSize: 20),
                    ),

                    const SizedBox(height: 20),

                    const Text('This week', style: TextStyle(fontSize: 25)),

                    const SizedBox(height: 20),

                    _buildWeeklyScores(stats.weeklyScores),

                    const SizedBox(height: 40),

                    SizedBox(
                      height: 200,
                      width: 360,
                      child: _buildLineChart(stats.weeklyScores),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyScores(List<double> weeklyScores) {
    const days = ['S', 'M', 'T', 'W', 'TH', 'F', 'SA'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        return Column(
          children: [
            Text(days[index]),
            const SizedBox(height: 5),
            Text(weeklyScores[index].round().toString()),
          ],
        );
      }),
    );
  }

  Widget _buildLineChart(List<double> weeklyScores) {
    const days = ['S', 'M', 'T', 'W', 'TH', 'F', 'SA'];

    return LineChart(
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
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();

                if (index < 0 || index >= days.length) {
                  return const Text('');
                }

                return Text(days[index]);
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
            spots: List.generate(
              7,
              (index) => FlSpot(index.toDouble(), weeklyScores[index]),
            ),
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
    );
  }
}

class StatisticsData {
  const StatisticsData({
    required this.totalScreenTime,
    required this.totalBadPostureTime,
    required this.weeklyScores,
  });

  final int totalScreenTime;
  final int totalBadPostureTime;
  final List<double> weeklyScores;

  int get goodPostureTime {
    return max(0, totalScreenTime - totalBadPostureTime);
  }

  double get score {
    if (totalScreenTime == 0) return 0;

    return ((goodPostureTime / totalScreenTime) * 100).clamp(0, 100).toDouble();
  }
}
