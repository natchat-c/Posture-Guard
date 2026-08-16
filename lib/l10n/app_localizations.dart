import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard'**
  String get appTitle;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @chooseLanguageThai.
  ///
  /// In en, this message translates to:
  /// **'เลือกภาษา'**
  String get chooseLanguageThai;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @thai.
  ///
  /// In en, this message translates to:
  /// **'ไทย'**
  String get thai;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get allow;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get completed;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Posture Guard'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard helps you notice when your phone position may be uncomfortable.'**
  String get welcomeBody;

  /// No description provided for @calibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your normal position'**
  String get calibrationTitle;

  /// No description provided for @calibrationBody.
  ///
  /// In en, this message translates to:
  /// **'Sit comfortably and hold your phone where you normally use it.'**
  String get calibrationBody;

  /// No description provided for @calibrationButton.
  ///
  /// In en, this message translates to:
  /// **'Set this position'**
  String get calibrationButton;

  /// No description provided for @calibrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Position saved'**
  String get calibrationSuccess;

  /// No description provided for @calibrationError.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone a little more upright and try again.'**
  String get calibrationError;

  /// No description provided for @knowPostureTitle.
  ///
  /// In en, this message translates to:
  /// **'Know your posture'**
  String get knowPostureTitle;

  /// No description provided for @goodPostureExplanation.
  ///
  /// In en, this message translates to:
  /// **'Good — your phone position looks comfortable.'**
  String get goodPostureExplanation;

  /// No description provided for @warningPostureExplanation.
  ///
  /// In en, this message translates to:
  /// **'Warning — your phone is starting to tilt too low.'**
  String get warningPostureExplanation;

  /// No description provided for @badPostureExplanation.
  ///
  /// In en, this message translates to:
  /// **'Bad — raise your phone or adjust your position.'**
  String get badPostureExplanation;

  /// No description provided for @notificationSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Get helpful reminders'**
  String get notificationSetupTitle;

  /// No description provided for @notificationSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard can remind you when your phone position may be uncomfortable.'**
  String get notificationSetupBody;

  /// No description provided for @allowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get allowNotifications;

  /// No description provided for @notificationsGranted.
  ///
  /// In en, this message translates to:
  /// **'Notifications are ready. You can change them later in Settings.'**
  String get notificationsGranted;

  /// No description provided for @notificationsNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for now. You can enable them later in Settings.'**
  String get notificationsNotGranted;

  /// No description provided for @screenTimeSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Show your phone screen time'**
  String get screenTimeSetupTitle;

  /// No description provided for @screenTimeSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Allow access to show how long your phone screen has been in use today. Posture Guard only uses the total time.'**
  String get screenTimeSetupBody;

  /// No description provided for @screenTimeGranted.
  ///
  /// In en, this message translates to:
  /// **'Screen-time access is ready.'**
  String get screenTimeGranted;

  /// No description provided for @screenTimeSkipped.
  ///
  /// In en, this message translates to:
  /// **'You can allow screen-time access later in Settings.'**
  String get screenTimeSkipped;

  /// No description provided for @guidePostureTitle.
  ///
  /// In en, this message translates to:
  /// **'Know your posture'**
  String get guidePostureTitle;

  /// No description provided for @guidePostureBody.
  ///
  /// In en, this message translates to:
  /// **'Good, Warning, and Bad show when to adjust your phone.'**
  String get guidePostureBody;

  /// No description provided for @guideSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get guideSettingsTitle;

  /// No description provided for @guideSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap here to choose how Posture Guard works.'**
  String get guideSettingsBody;

  /// No description provided for @guideCoinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Earn coins'**
  String get guideCoinsTitle;

  /// No description provided for @guideCoinsBody.
  ///
  /// In en, this message translates to:
  /// **'Your daily posture score earns coins. Use them to customize your character.'**
  String get guideCoinsBody;

  /// No description provided for @guideCosmeticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect cosmetics'**
  String get guideCosmeticsTitle;

  /// No description provided for @guideCosmeticsBody.
  ///
  /// In en, this message translates to:
  /// **'Use your coins to collect cosmetics for your slime. Tap Customize to see what you own.'**
  String get guideCosmeticsBody;

  /// No description provided for @guideHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Need help again?'**
  String get guideHelpTitle;

  /// No description provided for @guideHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the ? button anytime to view this guide again.'**
  String get guideHelpBody;

  /// No description provided for @guideFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready'**
  String get guideFinishTitle;

  /// No description provided for @guideFinishBody.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard is ready to help.'**
  String get guideFinishBody;

  /// No description provided for @settingsTourEnabledBody.
  ///
  /// In en, this message translates to:
  /// **'Turn posture tracking on or off.'**
  String get settingsTourEnabledBody;

  /// No description provided for @settingsTourNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Choose whether you want posture reminders.'**
  String get settingsTourNotificationsBody;

  /// No description provided for @settingsTourDelayBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how long Posture Guard waits before reminding you.'**
  String get settingsTourDelayBody;

  /// No description provided for @settingsTourFrequencyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how often reminders repeat.'**
  String get settingsTourFrequencyBody;

  /// No description provided for @settingsTourPostureSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Set the phone position you normally use.'**
  String get settingsTourPostureSetupBody;

  /// No description provided for @settingsTourLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'Change between English and Thai.'**
  String get settingsTourLanguageBody;

  /// No description provided for @screenTimeTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Show your screen time'**
  String get screenTimeTourTitle;

  /// No description provided for @screenTimeTourBody.
  ///
  /// In en, this message translates to:
  /// **'Screen-time access is optional. Allow it to show today\'s total phone screen time, or skip and use Posture Guard\'s monitored-time fallback.'**
  String get screenTimeTourBody;

  /// No description provided for @settingsTourPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Camera assistance is optional. Before enabling it, read Privacy & PDPA to see how the camera and your data are handled.'**
  String get settingsTourPrivacyBody;

  /// No description provided for @settingsTourCameraBody.
  ///
  /// In en, this message translates to:
  /// **'You can turn on camera assistance for extra posture detection, or skip this step and continue using phone sensors only.'**
  String get settingsTourCameraBody;

  /// No description provided for @turnOnCameraAssistance.
  ///
  /// In en, this message translates to:
  /// **'Turn on camera assistance'**
  String get turnOnCameraAssistance;

  /// No description provided for @helpTooltip.
  ///
  /// In en, this message translates to:
  /// **'How to use Posture Guard'**
  String get helpTooltip;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @buyMore.
  ///
  /// In en, this message translates to:
  /// **'Buy more'**
  String get buyMore;

  /// No description provided for @hats.
  ///
  /// In en, this message translates to:
  /// **'Hats'**
  String get hats;

  /// No description provided for @eyewear.
  ///
  /// In en, this message translates to:
  /// **'Eyewear'**
  String get eyewear;

  /// No description provided for @holding.
  ///
  /// In en, this message translates to:
  /// **'Holding'**
  String get holding;

  /// No description provided for @backAccessories.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backAccessories;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @customizeTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Equip your cosmetics'**
  String get customizeTourTitle;

  /// No description provided for @customizeTourBody.
  ///
  /// In en, this message translates to:
  /// **'Equip the cosmetics you\'ve collected here. Choose from Hats, Eyewear, Holding, and Back.'**
  String get customizeTourBody;

  /// No description provided for @customizeShopTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect more cosmetics'**
  String get customizeShopTourTitle;

  /// No description provided for @customizeShopTourBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Buy more to open the Shop.'**
  String get customizeShopTourBody;

  /// No description provided for @shopTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock cosmetics'**
  String get shopTourTitle;

  /// No description provided for @shopTourBody.
  ///
  /// In en, this message translates to:
  /// **'Spend coins on boxes to unlock new cosmetics. Higher-cost boxes have better odds for rare items. Tap ? to see each box\'s drop rates.'**
  String get shopTourBody;

  /// No description provided for @standardBox.
  ///
  /// In en, this message translates to:
  /// **'Standard Box'**
  String get standardBox;

  /// No description provided for @premiumBox.
  ///
  /// In en, this message translates to:
  /// **'Premium Box'**
  String get premiumBox;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @odds.
  ///
  /// In en, this message translates to:
  /// **'Odds'**
  String get odds;

  /// No description provided for @boxCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: {count} coins'**
  String boxCost(int count);

  /// No description provided for @dropRates.
  ///
  /// In en, this message translates to:
  /// **'Drop rates'**
  String get dropRates;

  /// No description provided for @duplicatesConvertedInfo.
  ///
  /// In en, this message translates to:
  /// **'Duplicates are converted into coins.'**
  String get duplicatesConvertedInfo;

  /// No description provided for @duplicateRewards.
  ///
  /// In en, this message translates to:
  /// **'Duplicate rewards'**
  String get duplicateRewards;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @starter.
  ///
  /// In en, this message translates to:
  /// **'Starter'**
  String get starter;

  /// No description provided for @newCosmetic.
  ///
  /// In en, this message translates to:
  /// **'New cosmetic!'**
  String get newCosmetic;

  /// No description provided for @gachaRewardNew.
  ///
  /// In en, this message translates to:
  /// **'NEW!'**
  String get gachaRewardNew;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @notEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get notEnoughCoins;

  /// No description provided for @convertedToCoins.
  ///
  /// In en, this message translates to:
  /// **'Converted to +{coins} coins'**
  String convertedToCoins(int coins);

  /// No description provided for @coinCount.
  ///
  /// In en, this message translates to:
  /// **'{count} coins'**
  String coinCount(int count);

  /// No description provided for @coinsBalance.
  ///
  /// In en, this message translates to:
  /// **'Coins: {coins}'**
  String coinsBalance(int coins);

  /// No description provided for @gachaOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this box. Please try again.'**
  String get gachaOpenFailed;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String score(int score);

  /// No description provided for @goodPosture.
  ///
  /// In en, this message translates to:
  /// **'Good posture'**
  String get goodPosture;

  /// No description provided for @warningPosture.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warningPosture;

  /// No description provided for @badPostureStatus.
  ///
  /// In en, this message translates to:
  /// **'Bad posture'**
  String get badPostureStatus;

  /// No description provided for @goodPostureHint.
  ///
  /// In en, this message translates to:
  /// **'Keep it up'**
  String get goodPostureHint;

  /// No description provided for @warningPostureHint.
  ///
  /// In en, this message translates to:
  /// **'Raise your phone a little'**
  String get warningPostureHint;

  /// No description provided for @badPostureHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust your position'**
  String get badPostureHint;

  /// No description provided for @checkYourPosture.
  ///
  /// In en, this message translates to:
  /// **'Check your posture'**
  String get checkYourPosture;

  /// No description provided for @monitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get monitoring;

  /// No description provided for @monitoringOn.
  ///
  /// In en, this message translates to:
  /// **'Monitoring is on'**
  String get monitoringOn;

  /// No description provided for @monitoringOff.
  ///
  /// In en, this message translates to:
  /// **'Monitoring is off'**
  String get monitoringOff;

  /// No description provided for @deviceScreenTime.
  ///
  /// In en, this message translates to:
  /// **'Screen time'**
  String get deviceScreenTime;

  /// No description provided for @monitoredTime.
  ///
  /// In en, this message translates to:
  /// **'Monitored time'**
  String get monitoredTime;

  /// No description provided for @badPosture.
  ///
  /// In en, this message translates to:
  /// **'Bad-posture time'**
  String get badPosture;

  /// No description provided for @cameraNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Posture monitoring will continue.'**
  String get cameraNotGranted;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable. Posture monitoring will continue.'**
  String get cameraUnavailable;

  /// No description provided for @postureSetupNeeded.
  ///
  /// In en, this message translates to:
  /// **'Set your normal phone position before starting Posture Guard.'**
  String get postureSetupNeeded;

  /// No description provided for @statisticsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Statistics are temporarily unavailable. Posture Guard will keep trying.'**
  String get statisticsUnavailable;

  /// No description provided for @monitoringStoppedUnexpectedly.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard stopped. Open Settings to start it again.'**
  String get monitoringStoppedUnexpectedly;

  /// No description provided for @actionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the current action to finish.'**
  String get actionInProgress;

  /// No description provided for @monitoringStarted.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard started.'**
  String get monitoringStarted;

  /// No description provided for @monitoringStopped.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard stopped.'**
  String get monitoringStopped;

  /// No description provided for @monitoringStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard could not start. Please try again.'**
  String get monitoringStartFailed;

  /// No description provided for @monitoringStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard could not stop. Please try again.'**
  String get monitoringStopFailed;

  /// No description provided for @notificationPermissionOff.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard is working, but notifications are off. You can enable them in Settings.'**
  String get notificationPermissionOff;

  /// No description provided for @calibrationCloudWarning.
  ///
  /// In en, this message translates to:
  /// **'Your position was saved on this device. Cloud backup will try again later.'**
  String get calibrationCloudWarning;

  /// No description provided for @calibrationSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Your position could not be saved. Please try again.'**
  String get calibrationSaveFailed;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get settingsSaved;

  /// No description provided for @settingsSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Settings were saved on this device. Cloud backup will try again later.'**
  String get settingsSavedLocally;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be saved. Please try again.'**
  String get settingsSaveFailed;

  /// No description provided for @monitoringEnabledSetting.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard enabled'**
  String get monitoringEnabledSetting;

  /// No description provided for @monitoringDisabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard is off.'**
  String get monitoringDisabledDescription;

  /// No description provided for @monitoringActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard is working.'**
  String get monitoringActiveDescription;

  /// No description provided for @monitoringWaitingDescription.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard is waiting to start.'**
  String get monitoringWaitingDescription;

  /// No description provided for @sendNotifications.
  ///
  /// In en, this message translates to:
  /// **'Send posture notifications'**
  String get sendNotifications;

  /// No description provided for @notificationsDisabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Posture monitoring continues when reminders are off.'**
  String get notificationsDisabledDescription;

  /// No description provided for @alertsMutedUntil.
  ///
  /// In en, this message translates to:
  /// **'Reminders are muted until {time}'**
  String alertsMutedUntil(String time);

  /// No description provided for @unmuteNow.
  ///
  /// In en, this message translates to:
  /// **'Unmute now'**
  String get unmuteNow;

  /// No description provided for @unmutedMessage.
  ///
  /// In en, this message translates to:
  /// **'Reminders are on again.'**
  String get unmutedMessage;

  /// No description provided for @useDeviceScreenTime.
  ///
  /// In en, this message translates to:
  /// **'Use device screen time'**
  String get useDeviceScreenTime;

  /// No description provided for @deviceScreenTimePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Allow access to show your total screen time. Posture Guard does not show or upload which apps you use.'**
  String get deviceScreenTimePrivacy;

  /// No description provided for @accessGranted.
  ///
  /// In en, this message translates to:
  /// **'Access granted'**
  String get accessGranted;

  /// No description provided for @accessNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Access not granted'**
  String get accessNotGranted;

  /// No description provided for @allowScreenTimeAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow screen-time access'**
  String get allowScreenTimeAccess;

  /// No description provided for @screenTimeSettingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Screen-time settings are unavailable on this device.'**
  String get screenTimeSettingsUnavailable;

  /// No description provided for @alertDelay.
  ///
  /// In en, this message translates to:
  /// **'Alert delay'**
  String get alertDelay;

  /// No description provided for @alertDelayHelp.
  ///
  /// In en, this message translates to:
  /// **'How long to wait before the first reminder.'**
  String get alertDelayHelp;

  /// No description provided for @alertRepeatFrequency.
  ///
  /// In en, this message translates to:
  /// **'Alert repeat frequency'**
  String get alertRepeatFrequency;

  /// No description provided for @alertFrequencyHelp.
  ///
  /// In en, this message translates to:
  /// **'How often to remind you while your position stays uncomfortable.'**
  String get alertFrequencyHelp;

  /// No description provided for @secondsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds'**
  String secondsCount(int count);

  /// No description provided for @minuteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String minuteCount(int count);

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customDelaySeconds.
  ///
  /// In en, this message translates to:
  /// **'Custom delay (seconds)'**
  String get customDelaySeconds;

  /// No description provided for @customFrequencySeconds.
  ///
  /// In en, this message translates to:
  /// **'Custom frequency (seconds)'**
  String get customFrequencySeconds;

  /// No description provided for @enterWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number.'**
  String get enterWholeNumber;

  /// No description provided for @secondsRange.
  ///
  /// In en, this message translates to:
  /// **'Use {minimum}–{maximum} seconds.'**
  String secondsRange(int minimum, int maximum);

  /// No description provided for @postureSetup.
  ///
  /// In en, this message translates to:
  /// **'Posture setup'**
  String get postureSetup;

  /// No description provided for @postureSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Set the phone position you normally use while sitting comfortably.'**
  String get postureSetupDescription;

  /// No description provided for @setPositionAgain.
  ///
  /// In en, this message translates to:
  /// **'Set position again'**
  String get setPositionAgain;

  /// No description provided for @setPosition.
  ///
  /// In en, this message translates to:
  /// **'Set position'**
  String get setPosition;

  /// No description provided for @positionSet.
  ///
  /// In en, this message translates to:
  /// **'Position saved'**
  String get positionSet;

  /// No description provided for @positionNotSet.
  ///
  /// In en, this message translates to:
  /// **'Position not set'**
  String get positionNotSet;

  /// No description provided for @monitoringStateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard\'s current state could not be checked.'**
  String get monitoringStateUnavailable;

  /// No description provided for @cloudBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'Your choice was saved on this device. Cloud backup will try again later.'**
  String get cloudBackupWarning;

  /// No description provided for @settingUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be changed. Please try again.'**
  String get settingUpdateFailed;

  /// No description provided for @statisticsRefreshWarning.
  ///
  /// In en, this message translates to:
  /// **'Some statistics could not be refreshed. Showing available data.'**
  String get statisticsRefreshWarning;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @pastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Past 7 Days'**
  String get pastSevenDays;

  /// No description provided for @sevenDaySummary.
  ///
  /// In en, this message translates to:
  /// **'7-Day Summary'**
  String get sevenDaySummary;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @goodPostureTime.
  ///
  /// In en, this message translates to:
  /// **'Good-posture time'**
  String get goodPostureTime;

  /// No description provided for @averageScore.
  ///
  /// In en, this message translates to:
  /// **'Average score'**
  String get averageScore;

  /// No description provided for @postureScore.
  ///
  /// In en, this message translates to:
  /// **'Posture score'**
  String get postureScore;

  /// No description provided for @scoreExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get scoreExcellent;

  /// No description provided for @scoreGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get scoreGood;

  /// No description provided for @scoreFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get scoreFair;

  /// No description provided for @scoreNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get scoreNeedsAttention;

  /// No description provided for @todayNoPostureData.
  ///
  /// In en, this message translates to:
  /// **'No posture data yet today'**
  String get todayNoPostureData;

  /// No description provided for @alertsSent.
  ///
  /// In en, this message translates to:
  /// **'Reminders sent'**
  String get alertsSent;

  /// No description provided for @averageMonitoredTime.
  ///
  /// In en, this message translates to:
  /// **'Average monitored time'**
  String get averageMonitoredTime;

  /// No description provided for @totalGoodPosture.
  ///
  /// In en, this message translates to:
  /// **'Total good-posture time'**
  String get totalGoodPosture;

  /// No description provided for @totalBadPosture.
  ///
  /// In en, this message translates to:
  /// **'Total bad-posture time'**
  String get totalBadPosture;

  /// No description provided for @daysTracked.
  ///
  /// In en, this message translates to:
  /// **'Days tracked'**
  String get daysTracked;

  /// No description provided for @pastVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'Past 7 days vs previous 7 days'**
  String get pastVsPrevious;

  /// No description provided for @sinceStarted.
  ///
  /// In en, this message translates to:
  /// **'Since you started using Posture Guard'**
  String get sinceStarted;

  /// No description provided for @totalMonitoredTime.
  ///
  /// In en, this message translates to:
  /// **'Total monitored time'**
  String get totalMonitoredTime;

  /// No description provided for @weightedScore.
  ///
  /// In en, this message translates to:
  /// **'Average score'**
  String get weightedScore;

  /// No description provided for @bestDay.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get bestDay;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noData;

  /// No description provided for @notEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data'**
  String get notEnoughData;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No posture history yet. Your statistics will appear after monitoring begins.'**
  String get noHistory;

  /// No description provided for @statisticsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posture data yet'**
  String get statisticsEmptyTitle;

  /// No description provided for @statisticsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Use Posture Guard and your statistics will appear here.'**
  String get statisticsEmptyBody;

  /// No description provided for @trendImprovement.
  ///
  /// In en, this message translates to:
  /// **'{points} percentage points higher than previous 7 days'**
  String trendImprovement(String points);

  /// No description provided for @trendDecline.
  ///
  /// In en, this message translates to:
  /// **'{points} percentage points lower than previous 7 days'**
  String trendDecline(String points);

  /// No description provided for @trendUnchanged.
  ///
  /// In en, this message translates to:
  /// **'No meaningful change from previous 7 days'**
  String get trendUnchanged;

  /// No description provided for @notEnoughPreviousData.
  ///
  /// In en, this message translates to:
  /// **'Not enough previous data for comparison'**
  String get notEnoughPreviousData;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String durationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationSeconds(int seconds);

  /// No description provided for @postureNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your posture'**
  String get postureNotificationTitle;

  /// No description provided for @postureNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Adjust your position.'**
  String get postureNotificationBody;

  /// No description provided for @mute15Minutes.
  ///
  /// In en, this message translates to:
  /// **'Mute 15 min'**
  String get mute15Minutes;

  /// No description provided for @mute1Hour.
  ///
  /// In en, this message translates to:
  /// **'Mute 1 hour'**
  String get mute1Hour;

  /// No description provided for @foregroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard is active'**
  String get foregroundTitle;

  /// No description provided for @foregroundMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring posture'**
  String get foregroundMonitoring;

  /// No description provided for @foregroundPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused while screen is off'**
  String get foregroundPaused;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Posture reminders'**
  String get notificationChannelDescription;

  /// No description provided for @dataLoadWarning.
  ///
  /// In en, this message translates to:
  /// **'Some saved information could not be refreshed. Using data on this device.'**
  String get dataLoadWarning;

  /// No description provided for @monitoringProblem.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard needs attention. Open Settings and try again.'**
  String get monitoringProblem;

  /// No description provided for @privacyNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera privacy'**
  String get privacyNoticeTitle;

  /// No description provided for @privacyNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard can use your front camera to help check your posture while you use your phone.'**
  String get privacyNoticeBody;

  /// No description provided for @privacyNoticeDetail.
  ///
  /// In en, this message translates to:
  /// **'Camera images are processed on your device only. They are not saved or uploaded. You can turn camera assistance off at any time and continue monitoring with your phone\'s angle sensors.'**
  String get privacyNoticeDetail;

  /// No description provided for @useSensorsOnly.
  ///
  /// In en, this message translates to:
  /// **'Use sensors only'**
  String get useSensorsOnly;

  /// No description provided for @cameraAssistTitle.
  ///
  /// In en, this message translates to:
  /// **'Use camera to help detect posture'**
  String get cameraAssistTitle;

  /// No description provided for @cameraAssistSettingDescription.
  ///
  /// In en, this message translates to:
  /// **'Optional front-camera assistance while this app is visible. Sensor monitoring works without it.'**
  String get cameraAssistSettingDescription;

  /// No description provided for @cameraExplanationTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera assistance'**
  String get cameraExplanationTitle;

  /// No description provided for @cameraExplanationBody.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard can use your front camera to help improve posture detection while the app is open.\n\nCamera images are processed on your device, are not saved, and are not uploaded.\n\nCamera access is optional. If you choose not to allow it, posture monitoring will continue using your phone\'s motion sensors.'**
  String get cameraExplanationBody;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @cameraActiveIndicator.
  ///
  /// In en, this message translates to:
  /// **'Front camera active • Images are not saved'**
  String get cameraActiveIndicator;

  /// No description provided for @cameraAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & PDPA'**
  String get cameraAndPrivacy;

  /// No description provided for @privacyInformationBody.
  ///
  /// In en, this message translates to:
  /// **'The front camera may be used only as an optional posture signal while this app is visible and posture monitoring needs extra help. Images are processed on this device, discarded after analysis, and are never saved or uploaded. You can always use sensor-only monitoring.'**
  String get privacyInformationBody;

  /// No description provided for @privacyPageIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard is designed to monitor posture while giving you control over how your device data and camera are used.\n\nThe app primarily uses your phone\'s motion sensors to estimate posture. You may also choose to enable the front camera to help improve posture detection while the app is open.'**
  String get privacyPageIntroduction;

  /// No description provided for @privacyPageCameraUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera use'**
  String get privacyPageCameraUseTitle;

  /// No description provided for @privacyPageCameraUseIntroduction.
  ///
  /// In en, this message translates to:
  /// **'The front camera is optional.\n\nIf camera assistance is enabled:'**
  String get privacyPageCameraUseIntroduction;

  /// No description provided for @privacyPageCameraUseItems.
  ///
  /// In en, this message translates to:
  /// **'The front camera is used only to help estimate your posture.\nCamera images are processed directly on your device.\nCamera images are not saved.\nCamera images are not uploaded to Firebase or any external server.\nCamera images are discarded after processing.\nCamera assistance is used only while the app is active and the feature is needed.'**
  String get privacyPageCameraUseItems;

  /// No description provided for @privacyPageCameraUseClosing.
  ///
  /// In en, this message translates to:
  /// **'You can turn camera assistance off at any time. Posture Guard will continue monitoring posture using your phone\'s motion sensors.'**
  String get privacyPageCameraUseClosing;

  /// No description provided for @privacyPageCameraPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera permission'**
  String get privacyPageCameraPermissionTitle;

  /// No description provided for @privacyPageCameraPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard will explain why camera access is needed before Android asks for camera permission.\n\nCamera access is optional.\n\nIf you deny camera permission, posture monitoring will continue using motion sensors.\n\nYou can also revoke camera permission later through your device settings.'**
  String get privacyPageCameraPermissionBody;

  /// No description provided for @privacyPageDataStoredTitle.
  ///
  /// In en, this message translates to:
  /// **'Data we store'**
  String get privacyPageDataStoredTitle;

  /// No description provided for @privacyPageDataStoredIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard may store information needed for the app to work, including:'**
  String get privacyPageDataStoredIntroduction;

  /// No description provided for @privacyPageDataStoredItems.
  ///
  /// In en, this message translates to:
  /// **'App settings\nPosture calibration\nPosture statistics\nMonitoring history\nCoins\nOwned and equipped cosmetics\nApp progress\nCamera-assistance preferences'**
  String get privacyPageDataStoredItems;

  /// No description provided for @privacyPageDataStoredClosing.
  ///
  /// In en, this message translates to:
  /// **'Cloud data is stored under your anonymous Firebase account so that your data is separated from other users.\n\nPosture Guard does not require your name, email address, or password to create this anonymous account.'**
  String get privacyPageDataStoredClosing;

  /// No description provided for @privacyPageFirebaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Firebase and cloud data'**
  String get privacyPageFirebaseTitle;

  /// No description provided for @privacyPageFirebaseBody.
  ///
  /// In en, this message translates to:
  /// **'Posture Guard uses Firebase to store and synchronize selected app data.\n\nEach installation is assigned an anonymous Firebase user ID.\n\nYour Firebase user ID is used to keep your cloud data separate from other users.\n\nPosture Guard does not use this anonymous account to identify you by name.'**
  String get privacyPageFirebaseBody;

  /// No description provided for @privacyPageChoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your choices'**
  String get privacyPageChoicesTitle;

  /// No description provided for @privacyPageChoicesItems.
  ///
  /// In en, this message translates to:
  /// **'Use Posture Guard without the camera.\nTurn camera assistance on or off.\nDeny or revoke camera permission.\nContinue using sensor-based posture monitoring if camera access is unavailable.\nReview this privacy information at any time.\nDelete your Posture Guard data from Settings.'**
  String get privacyPageChoicesItems;

  /// No description provided for @privacyPageDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your data'**
  String get privacyPageDeleteTitle;

  /// No description provided for @privacyPageDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'You can use \"Delete my data\" in Settings to remove your Posture Guard cloud data and anonymous Firebase account.\n\nThe app will ask you to confirm before deletion.\n\nIf deletion cannot be completed, Posture Guard will not falsely report that your data has been deleted.'**
  String get privacyPageDeleteBody;

  /// No description provided for @privacyPageCameraIndicatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera indicator'**
  String get privacyPageCameraIndicatorTitle;

  /// No description provided for @privacyPageCameraIndicatorBody.
  ///
  /// In en, this message translates to:
  /// **'Whenever the front camera is actually active for posture assistance, Posture Guard displays an in-app camera activity indicator.\n\nThis lets you know when the camera is being used.'**
  String get privacyPageCameraIndicatorBody;

  /// No description provided for @privacyPageConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Consent and control'**
  String get privacyPageConsentTitle;

  /// No description provided for @privacyPageConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Camera assistance is optional and requires your permission.\n\nChoosing not to use the camera does not prevent you from using Posture Guard\'s main sensor-based posture monitoring.\n\nYou can change your choice at any time in Settings.'**
  String get privacyPageConsentBody;

  /// No description provided for @privacyPagePolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPagePolicyTitle;

  /// No description provided for @privacyPagePolicyBody.
  ///
  /// In en, this message translates to:
  /// **'This in-app page provides a summary of Posture Guard\'s privacy practices.\n\nA hosted Privacy Policy URL will also be provided for the Google Play Store before public release.'**
  String get privacyPagePolicyBody;

  /// No description provided for @turnOffCameraAssistance.
  ///
  /// In en, this message translates to:
  /// **'Turn off camera assistance'**
  String get turnOffCameraAssistance;

  /// No description provided for @cameraAssistanceTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Camera assistance is off. Sensor monitoring continues.'**
  String get cameraAssistanceTurnedOff;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openAppSettings;

  /// No description provided for @cameraPermissionNeedsSettings.
  ///
  /// In en, this message translates to:
  /// **'Camera access is blocked. Sensor monitoring continues. You can allow access in Android Settings.'**
  String get cameraPermissionNeedsSettings;

  /// No description provided for @deleteMyData.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get deleteMyData;

  /// No description provided for @deleteMyDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete your Posture Guard cloud data, anonymous identity, and user history stored on this device.'**
  String get deleteMyDataDescription;

  /// No description provided for @deleteDataConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your data?'**
  String get deleteDataConfirmTitle;

  /// No description provided for @deleteDataConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your cloud user data and anonymous Firebase identity, then clears your settings, calibration, posture history, coins, and cosmetics from this device. Language and Android permission choices are preserved.'**
  String get deleteDataConfirmBody;

  /// No description provided for @deleteDataAction.
  ///
  /// In en, this message translates to:
  /// **'Delete data'**
  String get deleteDataAction;

  /// No description provided for @deletingData.
  ///
  /// In en, this message translates to:
  /// **'Deleting data…'**
  String get deletingData;

  /// No description provided for @deleteDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your Posture Guard data was deleted.'**
  String get deleteDataSuccess;

  /// No description provided for @deleteDataCloudFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud data could not be deleted. Nothing was reported as complete. Check your connection and retry.'**
  String get deleteDataCloudFailed;

  /// No description provided for @deleteDataAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud data was deleted, but the anonymous identity could not be removed. Retry to finish deletion.'**
  String get deleteDataAuthFailed;

  /// No description provided for @deleteDataLocalFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud data and identity were deleted, but local cleanup did not finish. Retry to complete it.'**
  String get deleteDataLocalFailed;

  /// No description provided for @deleteDataNoUser.
  ///
  /// In en, this message translates to:
  /// **'A secure user session could not be found. Check your connection and retry.'**
  String get deleteDataNoUser;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
