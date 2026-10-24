import 'dart:convert';

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

/// How many people an SOS can text when no network is reached.
const maxEmergencyContacts = 5;

/// Someone to text when an SOS reaches no network. Typed in by the person;
/// stays on this phone.
@immutable
class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});

  final String name;

  /// As typed, e.g. "+1 (408) 555-0100". See [dialable].
  final String phone;

  /// The number as Messages and the dialer expect it: digits, with a
  /// leading + kept.
  String get dialable => dialableNumber(phone);

  Map<String, String> toJson() => {'name': name, 'phone': phone};

  static EmergencyContact? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final phone = json['phone'];
    if (name is! String || phone is! String) return null;
    return EmergencyContact(name: name, phone: phone);
  }

  @override
  bool operator ==(Object other) =>
      other is EmergencyContact && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);
}

/// Strips spaces, dashes, dots and brackets, keeping a leading +.
String dialableNumber(String typed) {
  final t = typed.trim();
  final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
  return t.startsWith('+') ? '+$digits' : digits;
}

/// A number someone could text: 3 to 15 digits, written with the usual
/// separators. Short numbers are allowed for local emergency lines.
bool isValidPhone(String typed) {
  final t = typed.trim();
  if (!RegExp(r'^\+?[0-9 ()\-.]+$').hasMatch(t)) return false;
  final digits = dialableNumber(t).replaceAll('+', '');
  return digits.length >= 3 && digits.length <= 15;
}

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsStore? store})
      : _store = store ?? PrefsSettingsStore();

  final SettingsStore _store;

  ThemeMode _themeMode = ThemeMode.system;
  String? _language;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _lockOnOpen = false;
  List<EmergencyContact> _emergencyContacts = const [];

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

  /// People to text when an SOS reaches no network, at most
  /// [maxEmergencyContacts].
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  set emergencyContacts(List<EmergencyContact> v) {
    final kept = List<EmergencyContact>.unmodifiable(v.take(maxEmergencyContacts));
    _update(
      'emergencyContacts',
      kept.isEmpty ? null : jsonEncode([for (final c in kept) c.toJson()]),
      () => _emergencyContacts = kept,
    );
  }

  /// Adds [contact], or replaces the one at [index]. Returns false when the
  /// list is already full.
  bool saveEmergencyContact(EmergencyContact contact, {int? index}) {
    final list = [..._emergencyContacts];
    if (index != null && index >= 0 && index < list.length) {
      list[index] = contact;
    } else if (list.length >= maxEmergencyContacts) {
      return false;
    } else {
      list.add(contact);
    }
    emergencyContacts = list;
    return true;
  }

  /// Puts [contact] back at [index], for undo.
  void insertEmergencyContact(int index, EmergencyContact contact) {
    final list = [..._emergencyContacts];
    list.insert(index.clamp(0, list.length), contact);
    emergencyContacts = list;
  }

  void removeEmergencyContactAt(int index) {
    if (index < 0 || index >= _emergencyContacts.length) return;
    emergencyContacts = [..._emergencyContacts]..removeAt(index);
  }

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
      _emergencyContacts = _readContacts(v['emergencyContacts']);
      notifyListeners();
    } catch (_) {}
  }

  static List<EmergencyContact> _readContacts(Object? saved) {
    if (saved is! String) return const [];
    try {
      final list = jsonDecode(saved);
      if (list is! List) return const [];
      return List.unmodifiable([
        for (final item in list.take(maxEmergencyContacts))
          if (EmergencyContact.fromJson(item) case final contact?) contact,
      ]);
    } on FormatException {
      return const [];
    }
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
    _emergencyContacts = const [];
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
