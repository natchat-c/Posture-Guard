// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Posture Guard';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseLanguageThai => 'เลือกภาษา';

  @override
  String get english => 'English';

  @override
  String get thai => 'ไทย';

  @override
  String get continueButton => 'Continue';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get done => 'Done';

  @override
  String get allow => 'Allow access';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get completed => 'Done';

  @override
  String get welcomeTitle => 'Welcome to Posture Guard';

  @override
  String get welcomeBody =>
      'Posture Guard helps you notice when your phone position may be uncomfortable.';

  @override
  String get calibrationTitle => 'Set your normal position';

  @override
  String get calibrationBody =>
      'Sit comfortably and hold your phone where you normally use it.';

  @override
  String get calibrationButton => 'Set this position';

  @override
  String get calibrationSuccess => 'Position saved';

  @override
  String get calibrationError =>
      'Hold your phone a little more upright and try again.';

  @override
  String get knowPostureTitle => 'Know your posture';

  @override
  String get goodPostureExplanation =>
      'Good — your phone position looks comfortable.';

  @override
  String get warningPostureExplanation =>
      'Warning — your phone is starting to tilt too low.';

  @override
  String get badPostureExplanation =>
      'Bad — raise your phone or adjust your position.';

  @override
  String get notificationSetupTitle => 'Get helpful reminders';

  @override
  String get notificationSetupBody =>
      'Posture Guard can remind you when your phone position may be uncomfortable.';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get notificationsGranted =>
      'Notifications are ready. You can change them later in Settings.';

  @override
  String get notificationsNotGranted =>
      'Notifications are off for now. You can enable them later in Settings.';

  @override
  String get screenTimeSetupTitle => 'Show your phone screen time';

  @override
  String get screenTimeSetupBody =>
      'Allow access to show how long your phone screen has been in use today. Posture Guard only uses the total time.';

  @override
  String get screenTimeGranted => 'Screen-time access is ready.';

  @override
  String get screenTimeSkipped =>
      'You can allow screen-time access later in Settings.';

  @override
  String get guidePostureTitle => 'Know your posture';

  @override
  String get guidePostureBody =>
      'Good, Warning, and Bad show when to adjust your phone.';

  @override
  String get guideSettingsTitle => 'Open Settings';

  @override
  String get guideSettingsBody => 'Tap here to choose how Posture Guard works.';

  @override
  String get guideCoinsTitle => 'Earn coins';

  @override
  String get guideCoinsBody =>
      'Your daily posture score earns coins. Use them to customize your character.';

  @override
  String get guideHelpTitle => 'Need help again?';

  @override
  String get guideHelpBody =>
      'Tap the ? button anytime to view this guide again.';

  @override
  String get guideFinishTitle => 'You\'re ready';

  @override
  String get guideFinishBody => 'Posture Guard is ready to help.';

  @override
  String get settingsTourEnabledBody => 'Turn posture tracking on or off.';

  @override
  String get settingsTourNotificationsBody =>
      'Choose whether you want posture reminders.';

  @override
  String get settingsTourDelayBody =>
      'Choose how long Posture Guard waits before reminding you.';

  @override
  String get settingsTourFrequencyBody => 'Choose how often reminders repeat.';

  @override
  String get settingsTourPostureSetupBody =>
      'Set the phone position you normally use.';

  @override
  String get settingsTourLanguageBody => 'Change between English and Thai.';

  @override
  String get screenTimeTourTitle => 'Show your screen time';

  @override
  String get screenTimeTourBody =>
      'Allow access to show today\'s total phone screen time.';

  @override
  String get helpTooltip => 'How to use Posture Guard';

  @override
  String get settings => 'Settings';

  @override
  String get statistics => 'Statistics';

  @override
  String get customize => 'Customize';

  @override
  String get shop => 'Shop';

  @override
  String get buy => 'Buy';

  @override
  String get buyMore => 'Buy more';

  @override
  String get status => 'Status';

  @override
  String score(int score) {
    return 'Score: $score';
  }

  @override
  String get goodPosture => 'Good posture';

  @override
  String get warningPosture => 'Warning';

  @override
  String get badPostureStatus => 'Bad posture';

  @override
  String get goodPostureHint => 'Keep it up';

  @override
  String get warningPostureHint => 'Raise your phone a little';

  @override
  String get badPostureHint => 'Adjust your position';

  @override
  String get checkYourPosture => 'Check your posture';

  @override
  String get monitoring => 'Monitoring';

  @override
  String get monitoringOn => 'Monitoring is on';

  @override
  String get monitoringOff => 'Monitoring is off';

  @override
  String get deviceScreenTime => 'Screen time';

  @override
  String get monitoredTime => 'Monitored time';

  @override
  String get badPosture => 'Bad-posture time';

  @override
  String get cameraNotGranted =>
      'Camera access is off. Posture monitoring will continue.';

  @override
  String get cameraUnavailable =>
      'The camera is unavailable. Posture monitoring will continue.';

  @override
  String get cameraChecking => 'Checking your position…';

  @override
  String get cameraFaceNotFound =>
      'Move into view if you want camera help. Posture monitoring is still working.';

  @override
  String get postureSetupNeeded =>
      'Set your normal phone position before starting Posture Guard.';

  @override
  String get statisticsUnavailable =>
      'Statistics are temporarily unavailable. Posture Guard will keep trying.';

  @override
  String get monitoringStoppedUnexpectedly =>
      'Posture Guard stopped. Open Settings to start it again.';

  @override
  String get actionInProgress =>
      'Please wait for the current action to finish.';

  @override
  String get monitoringStarted => 'Posture Guard started.';

  @override
  String get monitoringStopped => 'Posture Guard stopped.';

  @override
  String get monitoringStartFailed =>
      'Posture Guard could not start. Please try again.';

  @override
  String get monitoringStopFailed =>
      'Posture Guard could not stop. Please try again.';

  @override
  String get notificationPermissionOff =>
      'Posture Guard is working, but notifications are off. You can enable them in Settings.';

  @override
  String get calibrationCloudWarning =>
      'Your position was saved on this device. Cloud backup will try again later.';

  @override
  String get calibrationSaveFailed =>
      'Your position could not be saved. Please try again.';

  @override
  String get language => 'Language';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get saving => 'Saving…';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get settingsSavedLocally =>
      'Settings were saved on this device. Cloud backup will try again later.';

  @override
  String get settingsSaveFailed =>
      'Settings could not be saved. Please try again.';

  @override
  String get monitoringEnabledSetting => 'Posture Guard enabled';

  @override
  String get monitoringDisabledDescription => 'Posture Guard is off.';

  @override
  String get monitoringActiveDescription => 'Posture Guard is working.';

  @override
  String get monitoringWaitingDescription =>
      'Posture Guard is waiting to start.';

  @override
  String get sendNotifications => 'Send posture notifications';

  @override
  String get notificationsDisabledDescription =>
      'Posture monitoring continues when reminders are off.';

  @override
  String alertsMutedUntil(String time) {
    return 'Reminders are muted until $time';
  }

  @override
  String get unmuteNow => 'Unmute now';

  @override
  String get unmutedMessage => 'Reminders are on again.';

  @override
  String get useDeviceScreenTime => 'Use device screen time';

  @override
  String get deviceScreenTimePrivacy =>
      'Allow access to show your total screen time. Posture Guard does not show or upload which apps you use.';

  @override
  String get accessGranted => 'Access granted';

  @override
  String get accessNotGranted => 'Access not granted';

  @override
  String get allowScreenTimeAccess => 'Allow screen-time access';

  @override
  String get screenTimeSettingsUnavailable =>
      'Screen-time settings are unavailable on this device.';

  @override
  String get alertDelay => 'Alert delay';

  @override
  String get alertDelayHelp => 'How long to wait before the first reminder.';

  @override
  String get alertRepeatFrequency => 'Alert repeat frequency';

  @override
  String get alertFrequencyHelp =>
      'How often to remind you while your position stays uncomfortable.';

  @override
  String secondsCount(int count) {
    return '$count seconds';
  }

  @override
  String minuteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get custom => 'Custom';

  @override
  String get customDelaySeconds => 'Custom delay (seconds)';

  @override
  String get customFrequencySeconds => 'Custom frequency (seconds)';

  @override
  String get enterWholeNumber => 'Enter a whole number.';

  @override
  String secondsRange(int minimum, int maximum) {
    return 'Use $minimum–$maximum seconds.';
  }

  @override
  String get postureSetup => 'Posture setup';

  @override
  String get postureSetupDescription =>
      'Set the phone position you normally use while sitting comfortably.';

  @override
  String get setPositionAgain => 'Set position again';

  @override
  String get setPosition => 'Set position';

  @override
  String get positionSet => 'Position saved';

  @override
  String get positionNotSet => 'Position not set';

  @override
  String get monitoringStateUnavailable =>
      'Posture Guard\'s current state could not be checked.';

  @override
  String get cloudBackupWarning =>
      'Your choice was saved on this device. Cloud backup will try again later.';

  @override
  String get settingUpdateFailed =>
      'This setting could not be changed. Please try again.';

  @override
  String get statisticsRefreshWarning =>
      'Some statistics could not be refreshed. Showing available data.';

  @override
  String get today => 'Today';

  @override
  String get pastSevenDays => 'Past 7 Days';

  @override
  String get allTime => 'All Time';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get goodPostureTime => 'Good-posture time';

  @override
  String get averageScore => 'Average score';

  @override
  String get postureScore => 'Posture score';

  @override
  String get alertsSent => 'Reminders sent';

  @override
  String get averageMonitoredTime => 'Average monitored time';

  @override
  String get totalGoodPosture => 'Total good-posture time';

  @override
  String get totalBadPosture => 'Total bad-posture time';

  @override
  String get daysTracked => 'Days tracked';

  @override
  String get pastVsPrevious => 'Past 7 days vs previous 7 days';

  @override
  String get sinceStarted => 'Since you started using Posture Guard';

  @override
  String get totalMonitoredTime => 'Total monitored time';

  @override
  String get weightedScore => 'Average score';

  @override
  String get bestDay => 'Best day';

  @override
  String get noData => 'No data yet';

  @override
  String get notEnoughData => 'Not enough data';

  @override
  String get noHistory =>
      'No posture history yet. Your statistics will appear after monitoring begins.';

  @override
  String trendImprovement(String points) {
    return 'Your score improved by $points points';
  }

  @override
  String trendDecline(String points) {
    return 'Your score went down by $points points';
  }

  @override
  String get trendUnchanged => 'Your score is about the same';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String durationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get postureNotificationTitle => 'Check your posture';

  @override
  String get postureNotificationBody => 'Adjust your position.';

  @override
  String get mute15Minutes => 'Mute 15 min';

  @override
  String get mute1Hour => 'Mute 1 hour';

  @override
  String get foregroundTitle => 'Posture Guard is active';

  @override
  String get foregroundMonitoring => 'Monitoring posture';

  @override
  String get foregroundPaused => 'Paused while screen is off';

  @override
  String get notificationChannelDescription => 'Posture reminders';

  @override
  String get dataLoadWarning =>
      'Some saved information could not be refreshed. Using data on this device.';

  @override
  String get monitoringProblem =>
      'Posture Guard needs attention. Open Settings and try again.';
}
