import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/home_live_times.dart';
import '../models/statistics_live_presentation.dart';
import '../models/statistics_summary.dart';
import '../services/device_screen_time_service.dart';
import '../services/monitoring_service.dart';
import '../services/statistics_repository.dart';

class Statistics extends StatefulWidget {
  const Statistics({
    super.key,
    this.repository,
    this.recordsStream,
    this.screenTimeProvider,
    this.clock,
    this.presentationTicker,
  });

  final StatisticsRepository? repository;
  final Stream<Map<String, DailyStats>>? recordsStream;
  final DeviceScreenTimeProvider? screenTimeProvider;
  final DateTime Function()? clock;
  final PresentationTicker? presentationTicker;

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> with WidgetsBindingObserver {
  StatisticsRepository? _repository;
  late final DeviceScreenTimeProvider _screenTimeProvider;
  late final DateTime Function() _clock;
  late final PresentationTicker _presentationTicker;
  late final StatisticsLivePresentation _livePresentation;
  Timer? _authoritativeRefreshTimer;
  String _dateKey = '';
  int? _todayDeviceScreenTimeSeconds;
  bool _deviceScreenTimeAvailable = false;
  bool _monitoringActive = false;
  bool _screenInteractive = true;
  String _postureStatus = 'GOOD';
  int? _lastAlertEventSequence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository =
        widget.repository ??
        (widget.recordsStream == null ? StatisticsRepository() : null);
    _screenTimeProvider =
        widget.screenTimeProvider ?? const AndroidDeviceScreenTimeProvider();
    _clock = widget.clock ?? DateTime.now;
    _dateKey = postureDateKey(_clock());
    _livePresentation = StatisticsLivePresentation(dateKey: _dateKey);
    _presentationTicker = widget.presentationTicker ?? PresentationTicker();
    _presentationTicker.start(_onPresentationTick);
    FlutterForegroundTask.addTaskDataCallback(_onServiceData);
    unawaited(_refreshMonitoringState());
    unawaited(_refreshDeviceScreenTime());
    _authoritativeRefreshTimer = Timer.periodic(const Duration(minutes: 1), (
      _,
    ) {
      _refreshDateIfNeeded();
      unawaited(_refreshDeviceScreenTime());
      MonitoringService.requestState();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshDateIfNeeded();
    unawaited(_refreshMonitoringState());
    MonitoringService.requestState();
    unawaited(_refreshDeviceScreenTime());
  }

  Future<void> _refreshMonitoringState() async {
    final active = await MonitoringService.isRunning();
    if (!mounted) return;
    setState(() => _monitoringActive = active);
    if (active) MonitoringService.requestState();
  }

  void _onServiceData(Object data) {
    if (!mounted || data is! Map || data['type'] != 'monitoringState') return;
    final nextAlertSequence =
        (data['alertEventSequence'] as num?)?.toInt() ?? 0;
    final previousAlertSequence = _lastAlertEventSequence;
    if (previousAlertSequence != null &&
        nextAlertSequence > previousAlertSequence) {
      for (
        var index = previousAlertSequence;
        index < nextAlertSequence;
        index++
      ) {
        _livePresentation.recordAlertSent();
      }
    }
    _lastAlertEventSequence = nextAlertSequence;
    setState(() {
      _monitoringActive = data['active'] == true;
      _screenInteractive = data['screenInteractive'] != false;
      _postureStatus = _monitoringActive
          ? data['postureStatus']?.toString() ?? 'GOOD'
          : 'GOOD';
    });
  }

  void _onPresentationTick() {
    if (!mounted) return;
    final pageVisible =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final crossedMidnight = _livePresentation.advance(
      now: _clock(),
      trackingActive: _monitoringActive && pageVisible,
      screenInteractive: _screenInteractive,
      postureStatus: _postureStatus,
      incrementDeviceScreenTime: _deviceScreenTimeAvailable && pageVisible,
    );
    setState(() {
      _todayDeviceScreenTimeSeconds = _livePresentation.deviceScreenTimeSeconds;
      if (crossedMidnight) _dateKey = _livePresentation.dateKey;
    });
    if (crossedMidnight) {
      unawaited(_refreshDeviceScreenTime());
      MonitoringService.requestState();
    }
  }

  void _refreshDateIfNeeded() {
    final nextDateKey = postureDateKey(_clock());
    if (nextDateKey == _dateKey || !mounted) return;
    setState(() {
      _dateKey = nextDateKey;
      _todayDeviceScreenTimeSeconds = null;
      _livePresentation
        ..dateKey = nextDateKey
        ..monitoredSeconds = 0
        ..badPostureSeconds = 0
        ..deviceScreenTimeSeconds = null;
    });
    unawaited(_refreshDeviceScreenTime());
  }

  Future<void> _refreshDeviceScreenTime() async {
    if (!await _screenTimeProvider.isSupported() ||
        !await _screenTimeProvider.hasUsageAccess()) {
      if (mounted) {
        setState(() {
          _deviceScreenTimeAvailable = false;
          _todayDeviceScreenTimeSeconds = null;
        });
      }
      return;
    }
    final seconds = await _screenTimeProvider.getTodayScreenTimeSeconds(
      now: _clock(),
    );
    if (!mounted || seconds == null) return;
    setState(() {
      _deviceScreenTimeAvailable = true;
      _livePresentation.reconcileDeviceScreenTime(seconds);
      _todayDeviceScreenTimeSeconds = _livePresentation.deviceScreenTimeSeconds;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onServiceData);
    _presentationTicker.dispose();
    _authoritativeRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Map<String, DailyStats>>(
        stream: widget.recordsStream ?? _repository!.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <String, DailyStats>{};
          _livePresentation.reconcile(records);
          final liveRecords = _livePresentation.records;
          final summary = StatisticsSummary.calculate(
            records: liveRecords,
            now: _clock(),
            todayDeviceScreenTimeOverride: _todayDeviceScreenTimeSeconds,
          );
          return _buildPage(
            context,
            summary,
            liveRecords,
            hasError: snapshot.hasError,
          );
        },
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    StatisticsSummary summary,
    Map<String, DailyStats> records, {
    required bool hasError,
  }) {
    final scores = summary.scoresForPastSevenDays(records);
    return SingleChildScrollView(
      key: const Key('statisticsScrollView'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 35, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text('Statistics', style: TextStyle(fontSize: 45)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      heroTag: 'statisticsBackButton',
                      onPressed: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasError)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Some statistics could not be refreshed. Showing available data.',
                ),
              ),
            ),
          const SizedBox(height: 16),
          _sectionTitle('Today'),
          _summaryCard([
            _Metric(
              'Device screen time',
              summary.todayDeviceScreenTimeSeconds == null
                  ? 'Unavailable'
                  : formatCompactDuration(
                      summary.todayDeviceScreenTimeSeconds!,
                    ),
            ),
            _Metric(
              'Monitored posture time',
              formatCompactDuration(summary.today.monitoredTimeSeconds),
            ),
            _Metric(
              'Good posture',
              formatCompactDuration(summary.today.goodPostureSeconds),
            ),
            _Metric(
              'Bad posture',
              formatCompactDuration(summary.today.badPostureSeconds),
            ),
            _Metric(
              'Posture score',
              summary.today.hasTrackedPosture
                  ? '${summary.today.dailyScore.round()}%'
                  : 'No data',
            ),
            _Metric(
              'Posture alerts sent',
              summary.today.alertsSentCount.toString(),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionTitle('Past 7 Days'),
          const SizedBox(height: 8),
          _dateLabels(summary.pastSevenDays),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _scoreChart(scores)),
          const SizedBox(height: 16),
          _summaryCard([
            _Metric(
              'Average posture score',
              _formatScore(summary.pastSeven.averageDailyScore),
            ),
            _Metric(
              'Average monitored time',
              summary.pastSeven.averageMonitoredSecondsPerTrackedDay == null
                  ? 'No data'
                  : formatCompactDuration(
                      summary.pastSeven.averageMonitoredSecondsPerTrackedDay!
                          .round(),
                    ),
            ),
            _Metric(
              'Total good posture',
              formatCompactDuration(summary.pastSeven.totalGoodSeconds),
            ),
            _Metric(
              'Total bad posture',
              formatCompactDuration(summary.pastSeven.totalBadSeconds),
            ),
            _Metric('Days tracked', summary.pastSeven.trackedDays.toString()),
            _Metric(
              'Posture alerts sent',
              summary.pastSeven.alertsSent.toString(),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionTitle('Past 7 days vs previous 7 days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _trendText(summary),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('All Time'),
          Text(
            'Since you started using Posture Guard',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          _summaryCard([
            _Metric('Days tracked', summary.allTime.daysTracked.toString()),
            _Metric(
              'Total monitored time',
              formatCompactDuration(summary.allTime.totalMonitoredSeconds),
            ),
            _Metric(
              'Total good posture',
              formatCompactDuration(summary.allTime.totalGoodSeconds),
            ),
            _Metric(
              'Total bad posture',
              formatCompactDuration(summary.allTime.totalBadSeconds),
            ),
            _Metric(
              'Weighted posture score',
              _formatScore(summary.allTime.weightedScore),
            ),
            _Metric('Best recorded day', _bestDayText(summary.allTime.bestDay)),
          ]),
          if (records.values.every((stats) => !stats.hasTrackedPosture)) ...[
            const SizedBox(height: 16),
            const Text(
              'No posture history yet. Statistics will appear after monitoring begins.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 25));
  }

  Widget _summaryCard(List<_Metric> metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: metrics
              .map(
                (metric) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(child: Text(metric.label)),
                      const SizedBox(width: 12),
                      Text(
                        metric.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _dateLabels(List<DateTime> dates) {
    return Row(
      children: dates
          .map(
            (date) => Expanded(
              child: Text(
                '${_weekday(date.weekday)}\n${date.day}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _scoreChart(List<double> scores) {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index > 6) return const SizedBox.shrink();
                return Text(
                  _weekday(rollingLocalDates(_clock())[index].weekday),
                  style: const TextStyle(fontSize: 10),
                );
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
              (index) => FlSpot(index.toDouble(), scores[index]),
            ),
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

  String _formatScore(double? score) {
    return score == null ? 'No data' : '${score.round()}%';
  }

  String _trendText(StatisticsSummary summary) {
    final points = summary.trendPoints?.abs().toStringAsFixed(1);
    return switch (summary.trend) {
      ScoreTrend.improvement => 'Improvement of $points percentage points',
      ScoreTrend.decline => 'Decline of $points percentage points',
      ScoreTrend.unchanged => 'No meaningful change',
      ScoreTrend.insufficientData => 'Not enough data',
    };
  }

  String _bestDayText(BestRecordedDay? bestDay) {
    if (bestDay == null) return 'Not enough data';
    return '${_weekday(bestDay.date.weekday)} '
        '${bestDay.date.day}/${bestDay.date.month}/${bestDay.date.year} '
        '(${bestDay.score.round()}%)';
  }

  String _weekday(int weekday) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}
