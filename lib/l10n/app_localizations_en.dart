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
  String get guideCosmeticsTitle => 'Collect cosmetics';

  @override
  String get guideCosmeticsBody =>
      'Use your coins to collect cosmetics for your slime. Tap Customize to see what you own.';

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
      'Screen-time access is optional. Allow it to show today\'s total phone screen time, or skip and use Posture Guard\'s monitored-time fallback.';

  @override
  String get settingsTourPrivacyBody =>
      'Camera assistance is optional. Before enabling it, read Privacy & PDPA to see how the camera and your data are handled.';

  @override
  String get settingsTourCameraBody =>
      'You can turn on camera assistance for extra posture detection, or skip this step and continue using phone sensors only.';

  @override
  String get turnOnCameraAssistance => 'Turn on camera assistance';

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
  String get buyMore => 'Buy more';

  @override
  String get hats => 'Hats';

  @override
  String get eyewear => 'Eyewear';

  @override
  String get holding => 'Holding';

  @override
  String get backAccessories => 'Back';

  @override
  String get none => 'None';

  @override
  String get customizeTourTitle => 'Equip your cosmetics';

  @override
  String get customizeTourBody =>
      'Equip the cosmetics you\'ve collected here. Choose from Hats, Eyewear, Holding, and Back.';

  @override
  String get customizeShopTourTitle => 'Collect more cosmetics';

  @override
  String get customizeShopTourBody => 'Tap Buy more to open the Shop.';

  @override
  String get shopTourTitle => 'Unlock cosmetics';

  @override
  String get shopTourBody =>
      'Spend coins on boxes to unlock new cosmetics. Higher-cost boxes have better odds for rare items. Tap ? to see each box\'s drop rates.';

  @override
  String get standardBox => 'Standard Box';

  @override
  String get premiumBox => 'Premium Box';

  @override
  String get open => 'Open';

  @override
  String get odds => 'Odds';

  @override
  String boxCost(int count) {
    return 'Cost: $count coins';
  }

  @override
  String get dropRates => 'Drop rates';

  @override
  String get duplicatesConvertedInfo => 'Duplicates are converted into coins.';

  @override
  String get duplicateRewards => 'Duplicate rewards';

  @override
  String get collection => 'Collection';

  @override
  String get owned => 'Owned';

  @override
  String get locked => 'Locked';

  @override
  String get starter => 'Starter';

  @override
  String get newCosmetic => 'New cosmetic!';

  @override
  String get gachaRewardNew => 'NEW!';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get notEnoughCoins => 'Not enough coins';

  @override
  String convertedToCoins(int coins) {
    return 'Converted to +$coins coins';
  }

  @override
  String coinCount(int count) {
    return '$count coins';
  }

  @override
  String coinsBalance(int coins) {
    return 'Coins: $coins';
  }

  @override
  String get gachaOpenFailed => 'Could not open this box. Please try again.';

  @override
  String get ok => 'OK';

  @override
  String get continueLabel => 'Continue';

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
  String get motionSensorsUnavailable =>
      'Motion sensors are unavailable on this device.';

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
  String get sevenDaySummary => '7-Day Summary';

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
  String get scoreExcellent => 'Excellent';

  @override
  String get scoreGood => 'Good';

  @override
  String get scoreFair => 'Fair';

  @override
  String get scoreNeedsAttention => 'Needs attention';

  @override
  String get todayNoPostureData => 'No posture data yet today';

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
  String get statisticsEmptyTitle => 'No posture data yet';

  @override
  String get statisticsEmptyBody =>
      'Use Posture Guard and your statistics will appear here.';

  @override
  String trendImprovement(String points) {
    return '$points percentage points higher than previous 7 days';
  }

  @override
  String trendDecline(String points) {
    return '$points percentage points lower than previous 7 days';
  }

  @override
  String get trendUnchanged => 'No meaningful change from previous 7 days';

  @override
  String get notEnoughPreviousData => 'Not enough previous data for comparison';

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

  @override
  String get privacyNoticeTitle => 'Camera privacy';

  @override
  String get privacyNoticeBody =>
      'Posture Guard can use your front camera to help check your posture while you use your phone.';

  @override
  String get privacyNoticeDetail =>
      'Camera images are processed on your device only. They are not saved or uploaded. You can turn camera assistance off at any time and continue monitoring with your phone\'s angle sensors.';

  @override
  String get useSensorsOnly => 'Use sensors only';

  @override
  String get cameraAssistTitle => 'Use camera to help detect posture';

  @override
  String get cameraAssistSettingDescription =>
      'Optional front-camera assistance while this app is visible. Sensor monitoring works without it.';

  @override
  String get cameraExplanationTitle => 'Camera assistance';

  @override
  String get cameraExplanationBody =>
      'Posture Guard can use your front camera to help improve posture detection while the app is open.\n\nCamera images are processed on your device, are not saved, and are not uploaded.\n\nCamera access is optional. If you choose not to allow it, posture monitoring will continue using your phone\'s motion sensors.';

  @override
  String get notNow => 'Not now';

  @override
  String get cameraActiveIndicator => 'Front camera active';

  @override
  String get cameraAndPrivacy => 'Privacy & PDPA';

  @override
  String get privacyInformationBody =>
      'The front camera may be used only as an optional posture signal while this app is visible and posture monitoring needs extra help. Images are processed on this device, discarded after analysis, and are never saved or uploaded. You can always use sensor-only monitoring.';

  @override
  String get privacyPageIntroduction =>
      'Posture Guard is designed to monitor posture while giving you control over how your device data and camera are used.\n\nThe app primarily uses your phone\'s motion sensors to estimate posture. You may also choose to enable the front camera to help improve posture detection while the app is open.';

  @override
  String get privacyPageCameraUseTitle => 'Camera use';

  @override
  String get privacyPageCameraUseIntroduction =>
      'The front camera is optional.\n\nIf camera assistance is enabled:';

  @override
  String get privacyPageCameraUseItems =>
      'The front camera is used only to help estimate your posture.\nCamera images are processed directly on your device.\nCamera images are not saved.\nCamera images are not uploaded to Firebase or any external server.\nCamera images are discarded after processing.\nCamera assistance is used only while the app is active and the feature is needed.';

  @override
  String get privacyPageCameraUseClosing =>
      'You can turn camera assistance off at any time. Posture Guard will continue monitoring posture using your phone\'s motion sensors.';

  @override
  String get privacyPageCameraPermissionTitle => 'Camera permission';

  @override
  String get privacyPageCameraPermissionBody =>
      'Posture Guard will explain why camera access is needed before Android asks for camera permission.\n\nCamera access is optional.\n\nIf you deny camera permission, posture monitoring will continue using motion sensors.\n\nYou can also revoke camera permission later through your device settings.';

  @override
  String get privacyPageDataStoredTitle => 'Data we store';

  @override
  String get privacyPageDataStoredIntroduction =>
      'Posture Guard may store information needed for the app to work, including:';

  @override
  String get privacyPageDataStoredItems =>
      'App settings\nPosture calibration\nPosture statistics\nMonitoring history\nCoins\nOwned and equipped cosmetics\nApp progress\nCamera-assistance preferences';

  @override
  String get privacyPageDataStoredClosing =>
      'Cloud data is stored under your anonymous Firebase account so that your data is separated from other users.\n\nPosture Guard does not require your name, email address, or password to create this anonymous account.';

  @override
  String get privacyPageFirebaseTitle => 'Firebase and cloud data';

  @override
  String get privacyPageFirebaseBody =>
      'Posture Guard uses Firebase to store and synchronize selected app data.\n\nEach installation is assigned an anonymous Firebase user ID.\n\nYour Firebase user ID is used to keep your cloud data separate from other users.\n\nPosture Guard does not use this anonymous account to identify you by name.';

  @override
  String get privacyPageChoicesTitle => 'Your choices';

  @override
  String get privacyPageChoicesItems =>
      'Use Posture Guard without the camera.\nTurn camera assistance on or off.\nDeny or revoke camera permission.\nContinue using sensor-based posture monitoring if camera access is unavailable.\nReview this privacy information at any time.\nDelete your Posture Guard data from Settings.';

  @override
  String get privacyPageDeleteTitle => 'Delete your data';

  @override
  String get privacyPageDeleteBody =>
      'You can use \"Delete my data\" in Settings to remove your Posture Guard cloud data and anonymous Firebase account.\n\nThe app will ask you to confirm before deletion.\n\nIf deletion cannot be completed, Posture Guard will not falsely report that your data has been deleted.';

  @override
  String get privacyPageCameraIndicatorTitle => 'Camera indicator';

  @override
  String get privacyPageCameraIndicatorBody =>
      'Whenever the front camera is actually active for posture assistance, Posture Guard displays an in-app camera activity indicator.\n\nThis lets you know when the camera is being used.';

  @override
  String get privacyPageConsentTitle => 'Consent and control';

  @override
  String get privacyPageConsentBody =>
      'Camera assistance is optional and requires your permission.\n\nChoosing not to use the camera does not prevent you from using Posture Guard\'s main sensor-based posture monitoring.\n\nYou can change your choice at any time in Settings.';

  @override
  String get privacyPagePolicyTitle => 'Privacy policy';

  @override
  String get privacyPagePolicyBody =>
      'This in-app page provides a summary of Posture Guard\'s privacy practices.\n\nA hosted Privacy Policy URL will also be provided for the Google Play Store before public release.';

  @override
  String get turnOffCameraAssistance => 'Turn off camera assistance';

  @override
  String get cameraAssistanceTurnedOff =>
      'Camera assistance is off. Sensor monitoring continues.';

  @override
  String get openAppSettings => 'Open Settings';

  @override
  String get cameraPermissionNeedsSettings =>
      'Camera access is blocked. Sensor monitoring continues. You can allow access in Android Settings.';

  @override
  String get deleteMyData => 'Delete my data';

  @override
  String get deleteMyDataDescription =>
      'Delete your Posture Guard cloud data, anonymous identity, and user history stored on this device.';

  @override
  String get deleteDataConfirmTitle => 'Delete your data?';

  @override
  String get deleteDataConfirmBody =>
      'This permanently deletes your cloud user data and anonymous Firebase identity, then clears your settings, calibration, posture history, coins, and cosmetics from this device. Language and Android permission choices are preserved.';

  @override
  String get deleteDataAction => 'Delete data';

  @override
  String get deletingData => 'Deleting data…';

  @override
  String get deleteDataSuccess => 'Your Posture Guard data was deleted.';

  @override
  String get deleteDataCloudFailed =>
      'Cloud data could not be deleted. Nothing was reported as complete. Check your connection and retry.';

  @override
  String get deleteDataAuthFailed =>
      'Cloud data was deleted, but the anonymous identity could not be removed. Retry to finish deletion.';

  @override
  String get deleteDataLocalFailed =>
      'Cloud data and identity were deleted, but local cleanup did not finish. Retry to complete it.';

  @override
  String get deleteDataNoUser =>
      'A secure user session could not be found. Check your connection and retry.';
}
