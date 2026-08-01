import 'package:flutter/material.dart';

import '../services/monitoring_service.dart';
import '../services/preferences_service.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

class LocaleController extends ChangeNotifier {
  LocaleController({LanguagePreferences? preferences, String? initialCode})
    : _preferences = preferences ?? LanguagePreferences(),
      _languageCode =
          LanguagePreferences.supportedLanguageCodes.contains(initialCode)
          ? initialCode
          : null,
      _loaded = initialCode != null;

  final LanguagePreferences _preferences;
  String? _languageCode;
  bool _loaded;

  bool get isLoaded => _loaded;
  String? get selectedLanguageCode => _languageCode;
  Locale get locale => Locale(_languageCode ?? 'en');

  Future<void> load() async {
    if (_loaded) return;
    try {
      _languageCode = await _preferences.load();
    } catch (_) {
      _languageCode = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> selectLanguage(String code) async {
    if (!LanguagePreferences.supportedLanguageCodes.contains(code)) return;
    await _preferences.save(code);
    final changed = _languageCode != code;
    _languageCode = code;
    _loaded = true;
    if (changed) notifyListeners();
    MonitoringService.updateLanguage(code);
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
  }
}

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n {
    final loaded = Localizations.of<AppLocalizations>(this, AppLocalizations);
    if (loaded != null) return loaded;
    final code = Localizations.maybeLocaleOf(this)?.languageCode ?? 'en';
    return code == 'th' ? AppLocalizationsTh() : AppLocalizationsEn();
  }

  LocaleController? get localeController => LocaleScope.maybeOf(this);
}

AppLocalizations localizationsForLanguage(String? languageCode) {
  return languageCode == 'th' ? AppLocalizationsTh() : AppLocalizationsEn();
}

String localizedDuration(AppLocalizations l10n, int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  if (hours > 0) return l10n.durationHoursMinutes(hours, minutes);
  if (minutes > 0) {
    return l10n.durationMinutesSeconds(minutes, remainingSeconds);
  }
  return l10n.durationSeconds(remainingSeconds);
}
