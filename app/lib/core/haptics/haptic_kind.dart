/// The kinds of haptic feedback the app fires. Mapped to the right platform
/// primitive by the conditional-import backend ([PlatformHaptics]).
enum HapticKind {
  /// A light tap: selecting a chip, toggling, small confirmations.
  selection,

  /// A medium impact: confirming/sending something.
  confirm,

  /// A strong success pattern: SOS sent, a request matched.
  success,

  /// An error pattern: a failed save/send.
  error,
}
