import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../l10n/locale_controller.dart';
import '../models/home_live_times.dart';
import '../models/statistics_live_presentation.dart';
import '../models/statistics_summary.dart';
import '../services/device_screen_time_service.dart';
import '../services/monitoring_service.dart';
import '../services/statistics_repository.dart';
import '../widgets/responsive_layout.dart';

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
    unawaited(_repository?.synchronize());
    MonitoringService.requestStatisticsSync();
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
      appBar: AppBar(title: Text(context.l10n.statistics)),
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
    final l10n = context.l10n;
    final scorePoints = summary.scorePointsForPastSevenDays(records);
    final hasHistory = records.values.any((stats) => stats.hasTrackedPosture);
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.responsiveHorizontalPadding;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ResponsiveBreakpoints.maxContentWidth,
              ),
              child: SingleChildScrollView(
                key: const Key('statisticsScrollView'),
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          l10n.statisticsRefreshWarning,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    _sectionTitle(l10n.today),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            summary.today.hasTrackedPosture
                                ? '${summary.today.dailyScore.round()}%'
                                : '—',
                            key: const Key('statisticsTodayScore'),
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.postureScore,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (summary.today.hasTrackedPosture) ...[
                            const SizedBox(height: 4),
                            Text(
                              _scoreDescription(summary.today.dailyScore),
                              key: const Key('statisticsTodayDescription'),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _todayBalance(summary.today),
                    if (!hasHistory) ...[
                      const SizedBox(height: 40),
                      _emptyState(),
                    ] else ...[
                      const SizedBox(height: 28),
                      _metricRows([
                        if (summary.todayDeviceScreenTimeSeconds != null)
                          _Metric(
                            l10n.deviceScreenTime,
                            localizedDuration(
                              l10n,
                              summary.todayDeviceScreenTimeSeconds!,
                            ),
                          ),
                        _Metric(
                          l10n.monitoredTime,
                          localizedDuration(
                            l10n,
                            summary.today.monitoredTimeSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.goodPostureTime,
                          localizedDuration(
                            l10n,
                            summary.today.goodPostureSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.badPosture,
                          localizedDuration(
                            l10n,
                            summary.today.badPostureSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.alertsSent,
                          summary.today.alertsSentCount.toString(),
                        ),
                      ], key: const Key('statisticsTodaySummary')),
                      const Divider(height: 56),
                      _sectionTitle(l10n.pastSevenDays),
                      const SizedBox(height: 16),
                      _sevenDayAverage(summary.pastSeven.averageDailyScore),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        key: const Key('statisticsScoreChart'),
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: AspectRatio(
                          aspectRatio: 1.35,
                          child: _scoreChart(scorePoints),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _trendLabel(summary),
                      const SizedBox(height: 36),
                      _sectionTitle(l10n.sevenDaySummary),
                      const SizedBox(height: 18),
                      _metricRows([
                        _Metric(
                          l10n.goodPostureTime,
                          localizedDuration(
                            l10n,
                            summary.pastSeven.totalGoodSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.badPosture,
                          localizedDuration(
                            l10n,
                            summary.pastSeven.totalBadSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.monitoredTime,
                          localizedDuration(
                            l10n,
                            summary.pastSeven.totalMonitoredSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.alertsSent,
                          summary.pastSeven.alertsSent.toString(),
                        ),
                        _Metric(
                          l10n.daysTracked,
                          summary.pastSeven.trackedDays.toString(),
                        ),
                      ], key: const Key('statisticsSevenDaySummary')),
                      const Divider(height: 56),
                      _sectionTitle(l10n.allTime),
                      const SizedBox(height: 6),
                      Text(
                        l10n.sinceStarted,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _metricRows([
                        _Metric(
                          l10n.daysTracked,
                          summary.allTime.daysTracked.toString(),
                        ),
                        _Metric(
                          l10n.averageScore,
                          _formatScore(summary.allTime.weightedScore),
                        ),
                        _Metric(
                          l10n.monitoredTime,
                          localizedDuration(
                            l10n,
                            summary.allTime.totalMonitoredSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.goodPostureTime,
                          localizedDuration(
                            l10n,
                            summary.allTime.totalGoodSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.badPosture,
                          localizedDuration(
                            l10n,
                            summary.allTime.totalBadSeconds,
                          ),
                        ),
                        _Metric(
                          l10n.bestDay,
                          _bestDayText(summary.allTime.bestDay),
                        ),
                      ], key: const Key('statisticsAllTimeSummary')),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _emptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 36,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.statisticsEmptyTitle,
            key: const Key('statisticsEmptyTitle'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.statisticsEmptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayBalance(DailyStats today) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!today.hasTrackedPosture) {
      return Text(
        context.l10n.todayNoPostureData,
        key: const Key('statisticsTodayBalanceEmpty'),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    final monitoredSeconds = today.monitoredTimeSeconds;
    final goodFraction = (today.goodPostureSeconds / monitoredSeconds).clamp(
      0.0,
      1.0,
    );
    final badFraction = 1 - goodFraction;
    return Semantics(
      label:
          '${context.l10n.goodPostureTime} '
          '${(goodFraction * 100).round()}%, '
          '${context.l10n.badPosture} ${(badFraction * 100).round()}%',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.goodPostureTime,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.badPosture,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            key: const Key('statisticsTodayBalance'),
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (goodFraction > 0)
                    Expanded(
                      flex: (goodFraction * 1000).round(),
                      child: ColoredBox(color: colorScheme.primary),
                    ),
                  if (badFraction > 0)
                    Expanded(
                      flex: (badFraction * 1000).round(),
                      child: ColoredBox(color: colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${(goodFraction * 100).round()}%',
                  key: const Key('statisticsGoodPercent'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${(badFraction * 100).round()}%',
                  key: const Key('statisticsBadPercent'),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sevenDayAverage(double? score) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            context.l10n.averageScore,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          _formatScore(score),
          key: const Key('statisticsSevenDayAverage'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _trendLabel(StatisticsSummary summary) {
    final color = _trendColor(summary.trend);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_trendIcon(summary.trend), color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _trendText(summary),
            key: const Key('statisticsTrendComparison'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _metricRows(List<_Metric> metrics, {Key? key}) {
    return KeyedSubtree(
      key: key,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stacked = constraints.maxWidth < 300 || textScale >= 1.45;
          return Column(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                _metricRow(metrics[index], stacked: stacked),
                if (index != metrics.length - 1)
                  Divider(
                    height: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _metricRow(_Metric metric, {required bool stacked}) {
    final label = Text(
      metric.label,
      style: Theme.of(context).textTheme.bodyLarge,
    );
    final value = Text(
      metric.value,
      textAlign: stacked ? TextAlign.left : TextAlign.right,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [label, const SizedBox(height: 4), value],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: label),
        const SizedBox(width: 16),
        Flexible(child: value),
      ],
    );
  }

  Widget _scoreChart(List<DailyScorePoint> points) {
    final colorScheme = Theme.of(context).colorScheme;
    return BarChart(
      key: const Key('statisticsSevenDayBarChart'),
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: 10,
        barTouchData: const BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 64,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final point = points[index];
                final style = Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: point.isToday
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: point.isToday ? FontWeight.w700 : FontWeight.w400,
                );
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_weekday(point.date.weekday), style: style),
                      if (!point.hasData)
                        Text('—', style: style)
                      else if (point.score == 0)
                        Text('0', style: style),
                    ],
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > 100 || value % 25 != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    value.round().toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
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
        barGroups: List.generate(points.length, (index) {
          final point = points[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: point.score ?? 0,
                width: 18,
                color: point.hasData
                    ? point.isToday
                          ? colorScheme.primary
                          : colorScheme.primary.withValues(alpha: 0.46)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
              ),
            ],
          );
        }),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  String _scoreDescription(double score) {
    if (score >= 90) return context.l10n.scoreExcellent;
    if (score >= 75) return context.l10n.scoreGood;
    if (score >= 50) return context.l10n.scoreFair;
    return context.l10n.scoreNeedsAttention;
  }

  String _formatScore(double? score) {
    return score == null ? context.l10n.noData : '${score.round()}%';
  }

  String _trendText(StatisticsSummary summary) {
    final points = summary.trendPoints?.abs().toStringAsFixed(1);
    return switch (summary.trend) {
      ScoreTrend.improvement => context.l10n.trendImprovement(points ?? '0'),
      ScoreTrend.decline => context.l10n.trendDecline(points ?? '0'),
      ScoreTrend.unchanged => context.l10n.trendUnchanged,
      ScoreTrend.insufficientData => context.l10n.notEnoughPreviousData,
    };
  }

  IconData _trendIcon(ScoreTrend trend) {
    return switch (trend) {
      ScoreTrend.improvement => Icons.trending_up,
      ScoreTrend.decline => Icons.trending_down,
      ScoreTrend.unchanged => Icons.trending_flat,
      ScoreTrend.insufficientData => Icons.remove,
    };
  }

  Color _trendColor(ScoreTrend trend) {
    return switch (trend) {
      ScoreTrend.improvement => Theme.of(context).colorScheme.primary,
      ScoreTrend.decline => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  String _bestDayText(BestRecordedDay? bestDay) {
    if (bestDay == null) return '—';
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(bestDay.date);
    return '${bestDay.score.round()}% · $date';
  }

  String _weekday(int weekday) {
    final l10n = context.l10n;
    return [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ][weekday - 1];
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}
