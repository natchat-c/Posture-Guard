// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

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
  String get continueButton => 'ต่อไป';

  @override
  String get next => 'ต่อไป';

  @override
  String get back => 'ย้อนกลับ';

  @override
  String get skip => 'ข้าม';

  @override
  String get skipForNow => 'ไว้ทีหลัง';

  @override
  String get done => 'เสร็จสิ้น';

  @override
  String get allow => 'อนุญาต';

  @override
  String get tryAgain => 'ลองอีกครั้ง';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get close => 'ปิด';

  @override
  String get completed => 'เรียบร้อยแล้ว';

  @override
  String get welcomeTitle => 'ยินดีต้อนรับสู่ Posture Guard';

  @override
  String get welcomeBody =>
      'Posture Guard ช่วยเตือนเมื่อคุณถือโทรศัพท์ในท่าที่อาจไม่สบายตัว';

  @override
  String get calibrationTitle => 'ตั้งท่าทางปกติ';

  @override
  String get calibrationBody =>
      'นั่งให้สบาย แล้วถือโทรศัพท์ในตำแหน่งที่คุณใช้ตามปกติ';

  @override
  String get calibrationButton => 'ใช้ตำแหน่งนี้';

  @override
  String get calibrationSuccess => 'บันทึกท่าทางแล้ว';

  @override
  String get calibrationError =>
      'ลองถือโทรศัพท์ให้ตั้งขึ้นอีกเล็กน้อย แล้วลองใหม่';

  @override
  String get knowPostureTitle => 'ดูสถานะท่าทาง';

  @override
  String get goodPostureExplanation => 'ดี — ตำแหน่งโทรศัพท์กำลังสบาย';

  @override
  String get warningPostureExplanation => 'ระวัง — โทรศัพท์เริ่มอยู่ต่ำเกินไป';

  @override
  String get badPostureExplanation => 'ไม่ดี — ยกโทรศัพท์ขึ้นหรือปรับท่าทาง';

  @override
  String get notificationSetupTitle => 'รับการแจ้งเตือน';

  @override
  String get notificationSetupBody =>
      'Posture Guard จะแจ้งเตือนเมื่อท่าทางการใช้โทรศัพท์อาจไม่สบาย';

  @override
  String get allowNotifications => 'อนุญาตการแจ้งเตือน';

  @override
  String get notificationsGranted =>
      'พร้อมแจ้งเตือนแล้ว คุณเปลี่ยนได้ภายหลังในการตั้งค่า';

  @override
  String get notificationsNotGranted =>
      'ยังไม่ได้เปิดการแจ้งเตือน คุณเปิดภายหลังได้ในการตั้งค่า';

  @override
  String get screenTimeSetupTitle => 'แสดงเวลาหน้าจอ';

  @override
  String get screenTimeSetupBody =>
      'อนุญาตเพื่อดูว่าวันนี้คุณใช้หน้าจอโทรศัพท์นานเท่าไร Posture Guard ใช้เฉพาะเวลารวมเท่านั้น';

  @override
  String get screenTimeGranted => 'พร้อมแสดงเวลาหน้าจอแล้ว';

  @override
  String get screenTimeSkipped =>
      'คุณอนุญาตการเข้าถึงเวลาหน้าจอภายหลังได้ในการตั้งค่า';

  @override
  String get guidePostureTitle => 'ดูสถานะท่าทาง';

  @override
  String get guidePostureBody =>
      'สถานะดี ระวัง และไม่ดี จะบอกว่าควรปรับโทรศัพท์เมื่อใด';

  @override
  String get guideSettingsTitle => 'เปิดการตั้งค่า';

  @override
  String get guideSettingsBody => 'แตะตรงนี้เพื่อปรับการทำงานของ Posture Guard';

  @override
  String get guideCoinsTitle => 'รับเหรียญ';

  @override
  String get guideCoinsBody =>
      'คะแนนท่าทางประจำวันช่วยให้คุณได้รับเหรียญ เพื่อนำไปปรับแต่งตัวละคร';

  @override
  String get guideHelpTitle => 'ต้องการดูวิธีใช้อีกครั้ง?';

  @override
  String get guideHelpBody =>
      'แตะปุ่ม ? ได้ทุกเมื่อเพื่อเปิดคำแนะนำนี้อีกครั้ง';

  @override
  String get guideFinishTitle => 'พร้อมแล้ว';

  @override
  String get guideFinishBody => 'Posture Guard พร้อมช่วยดูแลท่าทางของคุณ';

  @override
  String get settingsTourEnabledBody => 'เปิดหรือปิดการตรวจท่าทาง';

  @override
  String get settingsTourNotificationsBody =>
      'เลือกว่าจะรับการแจ้งเตือนท่าทางหรือไม่';

  @override
  String get settingsTourDelayBody => 'เลือกเวลาที่รอก่อนแจ้งเตือน';

  @override
  String get settingsTourFrequencyBody => 'เลือกความถี่ของการแจ้งเตือนซ้ำ';

  @override
  String get settingsTourPostureSetupBody =>
      'ตั้งตำแหน่งโทรศัพท์ที่คุณใช้ตามปกติ';

  @override
  String get settingsTourLanguageBody => 'เปลี่ยนภาษาอังกฤษหรือภาษาไทย';

  @override
  String get screenTimeTourTitle => 'แสดงเวลาหน้าจอ';

  @override
  String get screenTimeTourBody =>
      'อนุญาตเพื่อแสดงเวลาที่ใช้หน้าจอโทรศัพท์วันนี้';

  @override
  String get helpTooltip => 'วิธีใช้งาน Posture Guard';

  @override
  String get settings => 'การตั้งค่า';

  @override
  String get statistics => 'สถิติ';

  @override
  String get customize => 'ปรับแต่ง';

  @override
  String get shop => 'ร้านค้า';

  @override
  String get buy => 'ซื้อ';

  @override
  String get buyMore => 'เลือกซื้อเพิ่ม';

  @override
  String get status => 'สถานะ';

  @override
  String score(int score) {
    return 'คะแนน: $score';
  }

  @override
  String get goodPosture => 'ท่าทางดี';

  @override
  String get warningPosture => 'ระวัง';

  @override
  String get badPostureStatus => 'ท่าทางไม่ดี';

  @override
  String get goodPostureHint => 'ทำได้ดีมาก';

  @override
  String get warningPostureHint => 'ยกโทรศัพท์ขึ้นอีกนิด';

  @override
  String get badPostureHint => 'ลองปรับท่าทาง';

  @override
  String get checkYourPosture => 'เช็กท่าทางของคุณ';

  @override
  String get monitoring => 'กำลังตรวจท่าทาง';

  @override
  String get monitoringOn => 'เปิดการตรวจท่าทางแล้ว';

  @override
  String get monitoringOff => 'ปิดการตรวจท่าทางแล้ว';

  @override
  String get deviceScreenTime => 'เวลาหน้าจอ';

  @override
  String get monitoredTime => 'เวลาที่ตรวจท่าทาง';

  @override
  String get badPosture => 'เวลาท่าทางไม่ดี';

  @override
  String get cameraNotGranted =>
      'ยังไม่ได้เปิดกล้อง การตรวจท่าทางยังทำงานตามปกติ';

  @override
  String get cameraUnavailable => 'ใช้กล้องไม่ได้ การตรวจท่าทางยังทำงานตามปกติ';

  @override
  String get cameraChecking => 'กำลังตรวจท่าทาง…';

  @override
  String get cameraFaceNotFound =>
      'ขยับให้อยู่ในภาพหากต้องการใช้กล้องช่วย การตรวจท่าทางยังทำงานอยู่';

  @override
  String get postureSetupNeeded =>
      'ตั้งตำแหน่งโทรศัพท์ปกติก่อนเริ่ม Posture Guard';

  @override
  String get statisticsUnavailable =>
      'ยังอัปเดตสถิติไม่ได้ Posture Guard จะลองใหม่ต่อไป';

  @override
  String get monitoringStoppedUnexpectedly =>
      'Posture Guard หยุดทำงาน เปิดการตั้งค่าเพื่อเริ่มอีกครั้ง';

  @override
  String get actionInProgress => 'รอให้การทำงานปัจจุบันเสร็จก่อน';

  @override
  String get monitoringStarted => 'เริ่ม Posture Guard แล้ว';

  @override
  String get monitoringStopped => 'หยุด Posture Guard แล้ว';

  @override
  String get monitoringStartFailed =>
      'ไม่สามารถเริ่ม Posture Guard ได้ กรุณาลองอีกครั้ง';

  @override
  String get monitoringStopFailed =>
      'ไม่สามารถหยุด Posture Guard ได้ กรุณาลองอีกครั้ง';

  @override
  String get notificationPermissionOff =>
      'Posture Guard กำลังทำงาน แต่ยังไม่ได้เปิดการแจ้งเตือน คุณเปิดได้ในการตั้งค่า';

  @override
  String get calibrationCloudWarning =>
      'บันทึกตำแหน่งไว้ในเครื่องแล้ว ระบบจะลองสำรองข้อมูลอีกครั้งภายหลัง';

  @override
  String get calibrationSaveFailed => 'บันทึกตำแหน่งไม่ได้ กรุณาลองอีกครั้ง';

  @override
  String get language => 'ภาษา';

  @override
  String get saveSettings => 'บันทึกการตั้งค่า';

  @override
  String get saving => 'กำลังบันทึก…';

  @override
  String get settingsSaved => 'บันทึกการตั้งค่าแล้ว';

  @override
  String get settingsSavedLocally =>
      'บันทึกการตั้งค่าไว้ในเครื่องแล้ว ระบบจะลองสำรองข้อมูลอีกครั้งภายหลัง';

  @override
  String get settingsSaveFailed => 'บันทึกการตั้งค่าไม่ได้ กรุณาลองอีกครั้ง';

  @override
  String get monitoringEnabledSetting => 'เปิดใช้ Posture Guard';

  @override
  String get monitoringDisabledDescription => 'ปิด Posture Guard แล้ว';

  @override
  String get monitoringActiveDescription => 'Posture Guard กำลังทำงาน';

  @override
  String get monitoringWaitingDescription => 'Posture Guard กำลังรอเริ่มทำงาน';

  @override
  String get sendNotifications => 'แจ้งเตือนเมื่อท่าทางไม่ดี';

  @override
  String get notificationsDisabledDescription =>
      'การตรวจท่าทางยังทำงานเมื่อปิดการแจ้งเตือน';

  @override
  String alertsMutedUntil(String time) {
    return 'ปิดการแจ้งเตือนถึง $time';
  }

  @override
  String get unmuteNow => 'เปิดเสียงแจ้งเตือนตอนนี้';

  @override
  String get unmutedMessage => 'เปิดการแจ้งเตือนอีกครั้งแล้ว';

  @override
  String get useDeviceScreenTime => 'ใช้เวลาหน้าจอจากโทรศัพท์';

  @override
  String get deviceScreenTimePrivacy =>
      'อนุญาตเพื่อดูเวลาหน้าจอรวม Posture Guard จะไม่แสดงหรืออัปโหลดว่าคุณใช้แอปใด';

  @override
  String get accessGranted => 'อนุญาตแล้ว';

  @override
  String get accessNotGranted => 'ยังไม่ได้อนุญาต';

  @override
  String get allowScreenTimeAccess => 'อนุญาตการเข้าถึงเวลาหน้าจอ';

  @override
  String get screenTimeSettingsUnavailable =>
      'อุปกรณ์นี้เปิดการตั้งค่าเวลาหน้าจอไม่ได้';

  @override
  String get alertDelay => 'รอก่อนแจ้งเตือน';

  @override
  String get alertDelayHelp => 'ระยะเวลาที่รอก่อนแจ้งเตือนครั้งแรก';

  @override
  String get alertRepeatFrequency => 'แจ้งเตือนซ้ำทุก';

  @override
  String get alertFrequencyHelp => 'ความถี่ในการเตือนเมื่อท่าทางยังไม่สบาย';

  @override
  String secondsCount(int count) {
    return '$count วินาที';
  }

  @override
  String minuteCount(int count) {
    return '$count นาที';
  }

  @override
  String get custom => 'กำหนดเอง';

  @override
  String get customDelaySeconds => 'เวลารอ (วินาที)';

  @override
  String get customFrequencySeconds => 'ความถี่ (วินาที)';

  @override
  String get enterWholeNumber => 'กรอกจำนวนเต็ม';

  @override
  String secondsRange(int minimum, int maximum) {
    return 'ใช้ค่า $minimum–$maximum วินาที';
  }

  @override
  String get postureSetup => 'ตั้งค่าท่าทาง';

  @override
  String get postureSetupDescription =>
      'ตั้งตำแหน่งโทรศัพท์ที่คุณใช้ตามปกติขณะนั่งสบาย ๆ';

  @override
  String get setPositionAgain => 'ตั้งตำแหน่งใหม่';

  @override
  String get setPosition => 'ตั้งตำแหน่ง';

  @override
  String get positionSet => 'บันทึกท่าทางแล้ว';

  @override
  String get positionNotSet => 'ยังไม่ได้ตั้งท่าทาง';

  @override
  String get monitoringStateUnavailable => 'ตรวจสถานะของ Posture Guard ไม่ได้';

  @override
  String get cloudBackupWarning =>
      'บันทึกตัวเลือกไว้ในเครื่องแล้ว ระบบจะลองสำรองข้อมูลอีกครั้งภายหลัง';

  @override
  String get settingUpdateFailed =>
      'เปลี่ยนการตั้งค่านี้ไม่ได้ กรุณาลองอีกครั้ง';

  @override
  String get statisticsRefreshWarning =>
      'อัปเดตสถิติบางส่วนไม่ได้ กำลังแสดงข้อมูลที่มี';

  @override
  String get today => 'วันนี้';

  @override
  String get pastSevenDays => '7 วันที่ผ่านมา';

  @override
  String get allTime => 'ตั้งแต่เริ่มใช้งาน';

  @override
  String get unavailable => 'ยังใช้ไม่ได้';

  @override
  String get goodPostureTime => 'เวลาท่าทางดี';

  @override
  String get averageScore => 'คะแนนเฉลี่ย';

  @override
  String get postureScore => 'คะแนนท่าทาง';

  @override
  String get alertsSent => 'จำนวนการแจ้งเตือน';

  @override
  String get averageMonitoredTime => 'เวลาเฉลี่ยที่ตรวจท่าทาง';

  @override
  String get totalGoodPosture => 'เวลาท่าทางดีทั้งหมด';

  @override
  String get totalBadPosture => 'เวลาท่าทางไม่ดีทั้งหมด';

  @override
  String get daysTracked => 'จำนวนวันที่บันทึก';

  @override
  String get pastVsPrevious => '7 วันที่ผ่านมาเทียบกับ 7 วันก่อนหน้า';

  @override
  String get sinceStarted => 'ตั้งแต่คุณเริ่มใช้ Posture Guard';

  @override
  String get totalMonitoredTime => 'เวลาที่ตรวจท่าทางทั้งหมด';

  @override
  String get weightedScore => 'คะแนนเฉลี่ย';

  @override
  String get bestDay => 'วันที่ดีที่สุด';

  @override
  String get noData => 'ยังไม่มีข้อมูล';

  @override
  String get notEnoughData => 'ข้อมูลยังไม่เพียงพอ';

  @override
  String get noHistory =>
      'ยังไม่มีประวัติท่าทาง สถิติจะแสดงหลังเริ่มตรวจท่าทาง';

  @override
  String trendImprovement(String points) {
    return 'คะแนนดีขึ้น $points คะแนน';
  }

  @override
  String trendDecline(String points) {
    return 'คะแนนลดลง $points คะแนน';
  }

  @override
  String get trendUnchanged => 'คะแนนใกล้เคียงเดิม';

  @override
  String get weekdayMon => 'จ.';

  @override
  String get weekdayTue => 'อ.';

  @override
  String get weekdayWed => 'พ.';

  @override
  String get weekdayThu => 'พฤ.';

  @override
  String get weekdayFri => 'ศ.';

  @override
  String get weekdaySat => 'ส.';

  @override
  String get weekdaySun => 'อา.';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ชม. $minutes นาที';
  }

  @override
  String durationMinutesSeconds(int minutes, int seconds) {
    return '$minutes นาที $seconds วิ.';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds วิ.';
  }

  @override
  String get postureNotificationTitle => 'เช็กท่าทาง';

  @override
  String get postureNotificationBody => 'ลองปรับท่าทาง';

  @override
  String get mute15Minutes => 'ปิด 15 นาที';

  @override
  String get mute1Hour => 'ปิด 1 ชั่วโมง';

  @override
  String get foregroundTitle => 'Posture Guard กำลังทำงาน';

  @override
  String get foregroundMonitoring => 'กำลังตรวจท่าทาง';

  @override
  String get foregroundPaused => 'หยุดชั่วคราวขณะปิดหน้าจอ';

  @override
  String get notificationChannelDescription => 'การแจ้งเตือนท่าทาง';

  @override
  String get dataLoadWarning =>
      'อัปเดตข้อมูลบางส่วนไม่ได้ กำลังใช้ข้อมูลที่บันทึกไว้ในเครื่อง';

  @override
  String get monitoringProblem =>
      'Posture Guard ต้องการให้คุณตรวจสอบ เปิดการตั้งค่าแล้วลองอีกครั้ง';
}
