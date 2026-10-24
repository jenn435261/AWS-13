import '../db/json_store.dart';

/// Local, device-only user settings: feedback and privacy toggles plus the
/// optional identity profile fields. None of this is a signed event — these
/// are personal preferences that never leave the device unless the user
/// explicitly shares them (e.g. a name they opt to include in their QR card).
///
/// Honesty + privacy rules:
///  * Identity fields are FREE TEXT and never auto-verified. They grant no
///    badge and never touch provenance (which is derived only from certificate
///    chains in the trust engine).
///  * Anonymous is the default: [includeNameInQr] starts false so a shared QR
///    carries no name unless the user turns it on.
///  * The biometric unlock STATE is never persisted here — only the user's
///    preference to require an unlock. The unlock itself lives in memory and is
///    cleared on background/timeout (see RevealController).
class AppSettings {
  const AppSettings({
    this.hapticsEnabled = true,
    this.requireUnlock = false,
    this.displayName = '',
    this.orgRole = '',
    this.contactNote = '',
    this.includeNameInQr = false,
  });

  /// Haptic feedback on taps/confirm/success/error. Default ON.
  final bool hapticsEnabled;

  /// Require a local unlock (biometric/device credential on native, an explicit
  /// confirm on web) before revealing the Resilience ID / identity QR. Default
  /// OFF so the ID stays reachable unless the user opts in.
  final bool requireUnlock;

  /// Optional self-chosen display name (free text, never verified).
  final String displayName;

  /// Optional organisation / role note (free text, NEVER grants a badge).
  final String orgRole;

  /// Optional phone / contact note (free text), shown only to chosen contacts.
  final String contactNote;

  /// Whether to embed [displayName] in the shared identity QR. Default OFF
  /// (anonymous): the QR omits the name unless this is on.
  final bool includeNameInQr;

  AppSettings copyWith({
    bool? hapticsEnabled,
    bool? requireUnlock,
    String? displayName,
    String? orgRole,
    String? contactNote,
    bool? includeNameInQr,
  }) {
    return AppSettings(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      requireUnlock: requireUnlock ?? this.requireUnlock,
      displayName: displayName ?? this.displayName,
      orgRole: orgRole ?? this.orgRole,
      contactNote: contactNote ?? this.contactNote,
      includeNameInQr: includeNameInQr ?? this.includeNameInQr,
    );
  }

  Map<String, dynamic> toJson() => {
        'hapticsEnabled': hapticsEnabled,
        'requireUnlock': requireUnlock,
        'displayName': displayName,
        'orgRole': orgRole,
        'contactNote': contactNote,
        'includeNameInQr': includeNameInQr,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        hapticsEnabled: j['hapticsEnabled'] as bool? ?? true,
        requireUnlock: j['requireUnlock'] as bool? ?? false,
        displayName: j['displayName'] as String? ?? '',
        orgRole: j['orgRole'] as String? ?? '',
        contactNote: j['contactNote'] as String? ?? '',
        includeNameInQr: j['includeNameInQr'] as bool? ?? false,
      );
}

/// Persists [AppSettings] in the local KeyValue table under a single record.
class SettingsStore {
  SettingsStore(this._json);

  final JsonStore _json;
  static const _id = 'app';

  Future<AppSettings> load() async {
    final all = await _json.all();
    if (all.isEmpty) return const AppSettings();
    return AppSettings.fromJson(all.first);
  }

  Future<void> save(AppSettings settings) => _json.put(_id, settings.toJson());
}
