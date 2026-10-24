import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where settings are saved. Swappable so tests run without a device.
abstract class SettingsStore {
  Future<Map<String, Object?>> readAll();
  Future<void> write(String key, Object? value);
  Future<void> clear();
}

class PrefsSettingsStore implements SettingsStore {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<Map<String, Object?>> readAll() => _prefs.getAll();

  @override
  Future<void> write(String key, Object? value) => switch (value) {
        null => _prefs.remove(key),
        bool v => _prefs.setBool(key, v),
        double v => _prefs.setDouble(key, v),
        String v => _prefs.setString(key, v),
        _ => throw ArgumentError.value(value, key),
      };

  @override
  Future<void> clear() => _prefs.clear();
}

class MemorySettingsStore implements SettingsStore {
  final values = <String, Object?>{};

  @override
  Future<Map<String, Object?>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, Object? value) async =>
      value == null ? values.remove(key) : values[key] = value;

  @override
  Future<void> clear() async => values.clear();
}

/// The languages the app is translated into, with their own names.
const supportedLanguages = <String, String>{
  'en': 'English',
  'es': 'Español',
  'vi': 'Tiếng Việt',
  'zh': '中文（简体）',
  'tl': 'Tagalog',
};

const textScales = [1.0, 1.25, 1.5];

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsStore? store})
      : _store = store ?? PrefsSettingsStore();

  final SettingsStore _store;

  ThemeMode _themeMode = ThemeMode.system;
  String? _language;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _lockOnOpen = false;

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode v) => _update('theme', v.name, () => _themeMode = v);

  /// Null follows the phone's language.
  String? get language => _language;
  set language(String? v) => _update('language', v, () => _language = v);

  Locale? get locale => _language == null ? null : Locale(_language!);

  /// On top of the phone's own text size.
  double get textScale => _textScale;
  set textScale(double v) => _update('textScale', v, () => _textScale = v);

  bool get highContrast => _highContrast;
  set highContrast(bool v) =>
      _update('highContrast', v, () => _highContrast = v);

  bool get lockOnOpen => _lockOnOpen;
  set lockOnOpen(bool v) => _update('lockOnOpen', v, () => _lockOnOpen = v);

  /// Loads saved settings. Storage can be missing (private browsing,
  /// previews); the app then runs on defaults.
  Future<void> load() async {
    try {
      final v = await _store.readAll();
      _themeMode = ThemeMode.values.asNameMap()[v['theme']] ?? _themeMode;
      final lang = v['language'];
      _language = supportedLanguages.containsKey(lang) ? lang as String : null;
      final scale = v['textScale'];
      _textScale = textScales.contains(scale) ? scale as double : 1.0;
      _highContrast = v['highContrast'] == true;
      _lockOnOpen = v['lockOnOpen'] == true;
      notifyListeners();
    } catch (_) {}
  }

  /// [load], for starting several things at once.
  Future<SettingsController> loadAndReturn() async {
    await load();
    return this;
  }

  Future<void> reset() async {
    _themeMode = ThemeMode.system;
    _language = null;
    _textScale = 1.0;
    _highContrast = false;
    _lockOnOpen = false;
    notifyListeners();
    try {
      await _store.clear();
    } catch (_) {}
  }

  void _update(String key, Object? value, VoidCallback apply) {
    apply();
    notifyListeners();
    _store.write(key, value).catchError((_) {});
  }
}
