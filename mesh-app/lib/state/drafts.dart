import 'package:flutter/foundation.dart';

import '../models/help.dart';

/// Notes travel over LoRa, so they share the message length limit.
const maxNoteLength = 200;
const maxPeople = 50;

enum DraftProblem {
  missingKind,
  peopleOutOfRange,
  noteTooLong,
  missingLocation,
  missingSupplies,
  missingTransport,
}

/// The help request being filled in, shared by the steps of the flow.
/// Checked here first; the network checks again before accepting it.
class RequestDraft extends ChangeNotifier {
  HelpKind? _kind;
  Urgency _urgency = Urgency.now;
  int _people = 1;
  String locationNote = '';
  String note = '';

  /// The step the person last reached, so undo can bring them back.
  int lastStep = 1;

  /// The screen the flow was opened from, where closing it returns.
  String returnTo = '/map';

  HelpKind? get kind => _kind;
  set kind(HelpKind? value) => _set(() => _kind = value);

  Urgency get urgency => _urgency;
  set urgency(Urgency value) => _set(() => _urgency = value);

  int get people => _people;
  set people(int value) => _set(() => _people = value.clamp(1, maxPeople));

  bool get isEmpty =>
      _kind == null && locationNote.isEmpty && note.isEmpty && _people == 1;

  List<DraftProblem> problems({required bool hasLocation}) => [
        if (_kind == null) DraftProblem.missingKind,
        if (_people < 1 || _people > maxPeople) DraftProblem.peopleOutOfRange,
        if (note.length > maxNoteLength || locationNote.length > maxNoteLength)
          DraftProblem.noteTooLong,
        if (!hasLocation && locationNote.trim().isEmpty)
          DraftProblem.missingLocation,
      ];

  RequestDraft copy() => RequestDraft()
    .._kind = _kind
    .._urgency = _urgency
    .._people = _people
    ..locationNote = locationNote
    ..note = note
    ..lastStep = lastStep
    ..returnTo = returnTo;

  void restoreFrom(RequestDraft other) => _set(() {
        _kind = other._kind;
        _urgency = other._urgency;
        _people = other._people;
        locationNote = other.locationNote;
        note = other.note;
        lastStep = other.lastStep;
        returnTo = other.returnTo;
      });

  void reset() => restoreFrom(RequestDraft());

  /// Lets the text field update the note and refresh the suggestion.
  void setNote(String value) => _set(() => note = value);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}

class OfferDraft extends ChangeNotifier {
  final Set<SupplyKind> kinds = {};
  Amount amount = Amount.some;
  Availability availability = Availability.now;
  String availabilityNote = '';
  String note = '';
  TransportMode? transport;
  Capacity capacity = Capacity.medium;

  /// The screen the flow was opened from, where closing it returns.
  String returnTo = '/map';

  bool get offersTransport => kinds.contains(SupplyKind.transportation);

  List<DraftProblem> get problems => [
        if (kinds.isEmpty) DraftProblem.missingSupplies,
        if (offersTransport && transport == null) DraftProblem.missingTransport,
        if (note.length > maxNoteLength) DraftProblem.noteTooLong,
      ];

  void toggle(SupplyKind kind) => update(
        () => kinds.contains(kind) ? kinds.remove(kind) : kinds.add(kind),
      );

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  void reset() => loadFrom(null);

  /// Starts from an existing offer when editing it.
  void loadFrom(HelpOffer? offer) => update(() {
        kinds
          ..clear()
          ..addAll(offer?.kinds ?? const {});
        amount = offer?.amount ?? Amount.some;
        availability = offer?.availability ?? Availability.now;
        availabilityNote = offer?.availabilityNote ?? '';
        note = offer?.note ?? '';
        transport = offer?.transport;
        capacity = offer?.capacity ?? Capacity.medium;
      });

  HelpOffer build() => HelpOffer(
        kinds: {...kinds},
        since: DateTime.now(),
        amount: amount,
        availability: availability,
        availabilityNote: availability == Availability.custom
            ? availabilityNote.trim()
            : '',
        note: note.trim(),
        transport: offersTransport ? transport : null,
        capacity: offersTransport ? capacity : null,
      );
}

/// Offline rules that guess a category from free text, in English and
/// Spanish. When the internet is up, Bedrock can do this better; the app
/// never depends on it (Spec section 67).
HelpKind? suggestKind(String text) {
  final t = text.toLowerCase();
  const rules = <HelpKind, List<String>>{
    HelpKind.medical: [
      'bleed', 'injur', 'hurt', 'broken', 'pain', 'breath', 'unconscious',
      'faint', 'wound', 'heart', 'cardiac', 'chest', 'herid', 'sangr',
      'dolor', 'respir',
    ],
    HelpKind.medicine: [
      'insulin', 'medicine', 'medication', 'pill', 'prescription', 'inhaler',
      'insulina', 'medicina', 'medicamento', 'receta',
    ],
    HelpKind.water: ['water', 'thirst', 'drink', 'agua', 'sed'],
    HelpKind.food: ['food', 'hungry', 'eat', 'formula', 'comida', 'hambre'],
    HelpKind.shelter: ['shelter', 'roof', 'sleep', 'cold', 'refugio', 'dormir', 'frío'],
    HelpKind.power: [
      'charge', 'charging', 'battery', 'power', 'electric', 'generator',
      'cargar', 'batería', 'luz',
    ],
    HelpKind.transportation: [
      'ride', 'car', 'transport', 'evacuat', 'drive', 'wheelchair', 'transporte',
    ],
    HelpKind.communication: [
      'call', 'phone', 'contact my', 'family', 'message', 'llamar', 'familia',
    ],
  };
  // Words match at their start, so "eat" finds "eating" but not "heat".
  bool has(String word) => RegExp('\\b${RegExp.escape(word)}').hasMatch(t);
  for (final MapEntry(key: kind, value: words) in rules.entries) {
    if (words.any(has)) return kind;
  }
  return null;
}
