class AppSettings {
  const AppSettings({
    required this.alertDelaySeconds,
    required this.alertFrequencySeconds,
    required this.alertsEnabled,
  });

  static const int defaultAlertDelaySeconds = 10;
  static const int defaultAlertFrequencySeconds = 30;
  static const int minimumAlertDelaySeconds = 5;
  static const int maximumAlertDelaySeconds = 300;
  static const int minimumAlertFrequencySeconds = 5;
  static const int maximumAlertFrequencySeconds = 3600;

  static const AppSettings defaults = AppSettings(
    alertDelaySeconds: defaultAlertDelaySeconds,
    alertFrequencySeconds: defaultAlertFrequencySeconds,
    alertsEnabled: true,
  );

  final int alertDelaySeconds;
  final int alertFrequencySeconds;
  final bool alertsEnabled;

  bool get isValid {
    return isValidAlertDelay(alertDelaySeconds) &&
        isValidAlertFrequency(alertFrequencySeconds);
  }

  static bool isValidAlertDelay(int value) {
    return value >= minimumAlertDelaySeconds &&
        value <= maximumAlertDelaySeconds;
  }

  static bool isValidAlertFrequency(int value) {
    return value >= minimumAlertFrequencySeconds &&
        value <= maximumAlertFrequencySeconds;
  }

  factory AppSettings.fromMap(
    Map<dynamic, dynamic> data, {
    AppSettings fallback = defaults,
  }) {
    final rawDelay = (data['alertDelaySeconds'] as num?)?.toInt();
    final rawFrequency = (data['alertFrequencySeconds'] as num?)?.toInt();
    final rawEnabled = data['alertsEnabled'];

    return AppSettings(
      alertDelaySeconds: rawDelay != null && isValidAlertDelay(rawDelay)
          ? rawDelay
          : fallback.alertDelaySeconds,
      alertFrequencySeconds:
          rawFrequency != null && isValidAlertFrequency(rawFrequency)
          ? rawFrequency
          : fallback.alertFrequencySeconds,
      alertsEnabled: rawEnabled is bool ? rawEnabled : fallback.alertsEnabled,
    );
  }

  Map<String, Object> toMap() {
    return {
      'alertDelaySeconds': alertDelaySeconds,
      'alertFrequencySeconds': alertFrequencySeconds,
      'alertsEnabled': alertsEnabled,
    };
  }

  AppSettings copyWith({
    int? alertDelaySeconds,
    int? alertFrequencySeconds,
    bool? alertsEnabled,
  }) {
    return AppSettings(
      alertDelaySeconds: alertDelaySeconds ?? this.alertDelaySeconds,
      alertFrequencySeconds:
          alertFrequencySeconds ?? this.alertFrequencySeconds,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.alertDelaySeconds == alertDelaySeconds &&
        other.alertFrequencySeconds == alertFrequencySeconds &&
        other.alertsEnabled == alertsEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(alertDelaySeconds, alertFrequencySeconds, alertsEnabled);
  }
}
