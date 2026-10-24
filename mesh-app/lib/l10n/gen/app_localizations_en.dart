// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mesh';

  @override
  String get navMap => 'Map';

  @override
  String get navMessages => 'Messages';

  @override
  String get navMore => 'More';

  @override
  String get helpButton => 'Help';

  @override
  String get helpButtonSemantics => 'Request help';

  @override
  String get helpButtonHint =>
      'Tap for options. Hold for 2 seconds to send an SOS.';

  @override
  String get helpMenuTitle => 'What do you want to do?';

  @override
  String get needHelp => 'I need help';

  @override
  String get needHelpSub => 'Tell helpers nearby what you need';

  @override
  String get canHelp => 'I can help';

  @override
  String get canHelpSub => 'Let people nearby know what you can offer';

  @override
  String get sosTip =>
      'In danger? Hold the red Help button to send an SOS right away.';

  @override
  String get holdForSos => 'Hold for SOS';

  @override
  String get holdForSosSub => 'Sends your location right away';

  @override
  String get keepHolding => 'Keep holding to send the SOS';

  @override
  String get sosSent => 'SOS sent with your location';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get next => 'Next';

  @override
  String get close => 'Close';

  @override
  String get edit => 'Edit';

  @override
  String get view => 'View';

  @override
  String get send => 'Send';

  @override
  String radiosNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count radios nearby',
      one: '1 radio nearby',
      zero: 'No radios nearby',
    );
    return '$_temp0';
  }

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get layers => 'Layers';

  @override
  String get layerRequests => 'Requests for help';

  @override
  String get layerRadios => 'Radios and coverage';

  @override
  String get myLocation => 'Show my location';

  @override
  String get language => 'Language';

  @override
  String get nothingNearby => 'Nothing nearby yet';

  @override
  String distanceMeters(int meters) {
    return '$meters m away';
  }

  @override
  String distanceKm(String km) {
    return '$km km away';
  }

  @override
  String get howItTravels => 'How your requests travel';

  @override
  String get travelPhone => 'This phone';

  @override
  String get travelPhoneSub => 'Saves everything first, even with no signal';

  @override
  String get travelMesh => 'Radio mesh';

  @override
  String get travelMeshSub => 'Passes it from radio to radio';

  @override
  String get travelCloud => 'AWS';

  @override
  String get travelCloudOnline => 'Checks it and keeps a copy';

  @override
  String get travelCloudOffline =>
      'Out of reach. Your request waits on the mesh.';

  @override
  String get travelHelpers => 'Helpers';

  @override
  String get travelHelpersSub => 'See your request and reply';

  @override
  String get showOnMap => 'Show on map';

  @override
  String get openDetails => 'Open details';

  @override
  String get kindMedical => 'Medical help';

  @override
  String get kindMedicalSub => 'Injured, sick or trapped';

  @override
  String get kindWater => 'Water';

  @override
  String get kindWaterSub => 'Drinking water';

  @override
  String get kindShelter => 'Shelter';

  @override
  String get kindShelterSub => 'A safe place to stay';

  @override
  String get kindPower => 'Power';

  @override
  String get kindPowerSub => 'Charge a phone or medical device';

  @override
  String get kindOther => 'Other';

  @override
  String get kindOtherSub => 'Describe it in the next step';

  @override
  String get kindSos => 'SOS';

  @override
  String get urgencyNow => 'Right now';

  @override
  String get urgencyNowSub => 'Life or safety at risk';

  @override
  String get urgencySoon => 'Within hours';

  @override
  String get urgencySoonSub => 'Getting worse';

  @override
  String get urgencyLater => 'Can wait';

  @override
  String get urgencyLaterSub => 'Stable for now';

  @override
  String get stageSaved => 'Saved on this phone';

  @override
  String get stageSavedSub => 'Sends as soon as a radio is in range';

  @override
  String get stageMesh => 'Sent over the mesh';

  @override
  String stageMeshSub(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'Passed through $hops radios',
      one: 'Passed through 1 radio',
      zero: 'Reached a radio directly',
    );
    return '$_temp0';
  }

  @override
  String get stageVerified => 'Checked by the server';

  @override
  String get stageVerifiedSub => 'AWS checked the request and saved a copy';

  @override
  String get stageAssigned => 'Helper found';

  @override
  String stageAssignedSub(String name) {
    return '$name accepted the request';
  }

  @override
  String get stageOnTheWay => 'Help is on the way';

  @override
  String stageOnTheWaySub(String name) {
    return '$name is heading there';
  }

  @override
  String get stageResolved => 'Resolved';

  @override
  String get stageResolvedSub => 'Marked as done';

  @override
  String get stageWaiting => 'Waiting';

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get helpStep1Title => 'What do you need?';

  @override
  String get helpStep2Title => 'Anything else?';

  @override
  String get urgencyQuestion => 'How urgent is it?';

  @override
  String get peopleQuestion => 'How many people need help?';

  @override
  String peopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get fewerPeople => 'Fewer people';

  @override
  String get morePeople => 'More people';

  @override
  String get locationTitle => 'Location';

  @override
  String locationAuto(int meters) {
    return 'Shared automatically, accurate to $meters m';
  }

  @override
  String get locationMissing =>
      'Your location isn\'t available. Describe where you are.';

  @override
  String get locationNoteLabel => 'Describe where you are';

  @override
  String get locationNoteHint => 'For example: 2nd floor, near the stairs';

  @override
  String get noteLabel => 'Anything else? (optional)';

  @override
  String get sendRequest => 'Send request';

  @override
  String get requestSent => 'Request sent';

  @override
  String get requestDiscarded => 'Request discarded';

  @override
  String get requestCancelled => 'Request cancelled';

  @override
  String get requestRestored => 'Request restored';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get problemMissingKind => 'Choose what you need.';

  @override
  String problemPeople(int max) {
    return 'Enter between 1 and $max people.';
  }

  @override
  String problemNoteTooLong(int max) {
    return 'Keep notes under $max characters.';
  }

  @override
  String get problemLocation =>
      'Describe where you are, since your location isn\'t available.';

  @override
  String get offerStep1Title => 'Supplies I can offer';

  @override
  String get offerStep2Title => 'A few details';

  @override
  String get offerNoteLabel => 'Note for people nearby (optional)';

  @override
  String get offerNoteHint => 'For example: I have a car with room for 4';

  @override
  String get startOffering => 'Start offering';

  @override
  String get offeringStarted => 'You\'re offering help';

  @override
  String offeringList(String list) {
    return 'You\'re offering: $list';
  }

  @override
  String get stopOffering => 'Stop';

  @override
  String get offerStopped => 'You stopped offering help';

  @override
  String get offerPrompt => 'Can you help? Let people nearby know.';

  @override
  String get tabNearMe => 'Near me';

  @override
  String get tabMine => 'Mine';

  @override
  String get iCanHelp => 'I can help';

  @override
  String get youAreHelping => 'You\'re helping';

  @override
  String get stopHelping => 'Stop helping';

  @override
  String get acceptedToast => 'You\'re helping. They can see you\'re coming.';

  @override
  String get releasedToast => 'You stopped helping';

  @override
  String get noNearby => 'No open requests nearby';

  @override
  String get noMine => 'You haven\'t asked for help';

  @override
  String fromName(String name) {
    return 'From $name';
  }

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String daysAgo(int n) {
    return '$n d ago';
  }

  @override
  String get progressTitle => 'Progress';

  @override
  String get detailsTitle => 'Details';

  @override
  String get showToResponder => 'Show to responder';

  @override
  String get requestNotFound => 'This request is no longer available.';

  @override
  String get cardNeedHelp => 'I need help';

  @override
  String get cardSwipeHint => 'Swipe left or right to change the language';

  @override
  String get cardTheirWords => 'Their own words, not translated:';

  @override
  String get urgencyTitle => 'Urgency';

  @override
  String get peopleTitle => 'People';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get messageHint => 'Message';

  @override
  String get languageSystem => 'Use phone setting';

  @override
  String get display => 'Display and accessibility';

  @override
  String displaySub(int percent) {
    return 'Text size $percent%';
  }

  @override
  String get theme => 'Theme';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get textSize => 'Text size';

  @override
  String get highContrast => 'High contrast';

  @override
  String get highContrastSub => 'Stronger colors and borders';

  @override
  String get textPreview => 'This is how text will look.';

  @override
  String get privacy => 'Privacy and security';

  @override
  String get phoneLockOn => 'Phone lock is on';

  @override
  String get phoneLockOff => 'Phone lock is off';

  @override
  String get phoneLock => 'Lock with Face ID or fingerprint';

  @override
  String get phoneLockSub => 'Uses your phone passcode if that fails';

  @override
  String get phoneLockWeb => 'Available in the iOS and Android app';

  @override
  String get phoneLockUnavailable =>
      'Set up a passcode or Face ID on this phone first';

  @override
  String get lockNow => 'Lock now';

  @override
  String get lockNowSub => 'SOS still works while locked';

  @override
  String get clearTemp => 'Clear temporary data';

  @override
  String get clearTempSub =>
      'Old messages and finished requests. AWS keeps its copies.';

  @override
  String cleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cleared $count items',
      one: 'Cleared 1 item',
      zero: 'Nothing to clear',
    );
    return '$_temp0';
  }

  @override
  String get eraseAll => 'Erase everything on this phone';

  @override
  String get eraseAllSub => 'Hold for 3 seconds. This can\'t be undone.';

  @override
  String get erased => 'Everything on this phone was erased';

  @override
  String get network => 'Radio network';

  @override
  String get manage => 'Manage network';

  @override
  String get manageSub => 'Turn radios on or off for everyone';

  @override
  String get admin => 'Users and roles';

  @override
  String get adminSub => 'Change who can manage the network';

  @override
  String get account => 'Account';

  @override
  String signedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get guestMode => 'Using Mesh as a guest';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInSub => 'Optional. Helpers and managers sign in.';

  @override
  String get signOut => 'Sign out';

  @override
  String get nameLabel => 'Name';

  @override
  String get roleLabel => 'Role';

  @override
  String get roleClient => 'Member';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get demoSignIn =>
      'Demo sign-in. In the real app, your role comes from the server.';

  @override
  String get nodeOnline => 'Online';

  @override
  String get nodeOffline => 'Offline';

  @override
  String get hopsDirect => 'Direct';

  @override
  String hopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hops',
      one: '1 hop',
    );
    return '$_temp0';
  }

  @override
  String get externalPower => 'External power';

  @override
  String get noNodes => 'No radios heard yet';

  @override
  String get nodeId => 'ID';

  @override
  String get lastHeard => 'Last heard';

  @override
  String get battery => 'Battery';

  @override
  String get signalStrength => 'Signal strength';

  @override
  String get signalNoise => 'Signal to noise';

  @override
  String get hopsTitle => 'Hops';

  @override
  String get manageHint => 'Radios you turn off are hidden from members.';

  @override
  String get loadFailed => 'Could not load this page.';

  @override
  String get lockedTitle => 'Mesh is locked';

  @override
  String get lockedSub => 'Unlock to see your requests and messages.';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockReason => 'Unlock Mesh';

  @override
  String get unlockWebNote =>
      'The web preview has no Face ID, so Unlock opens the app directly.';

  @override
  String get unlockFailed =>
      'Could not unlock. Try again or use your passcode.';

  @override
  String alertNearby(String kind) {
    return 'New request nearby: $kind';
  }

  @override
  String alertHelper(String name) {
    return '$name accepted your request';
  }

  @override
  String get navContacts => 'Contacts';

  @override
  String get kindFood => 'Food';

  @override
  String get kindFoodSub => 'Meals or baby formula';

  @override
  String get kindMedicine => 'Medicine';

  @override
  String get kindMedicineSub => 'Prescriptions, insulin, inhalers';

  @override
  String get kindTransportation => 'Transportation';

  @override
  String get kindTransportationSub => 'A ride, or help moving someone';

  @override
  String get kindCommunication => 'Communication';

  @override
  String get kindCommunicationSub => 'Reach family or call for help';

  @override
  String get noteExampleHint =>
      'For example: need somewhere cold to keep insulin for one person';

  @override
  String get structuredFirst =>
      'Your choice is sent first, so it gets through even on a weak network. Your note follows when there is room.';

  @override
  String suggestion(String kind) {
    return 'Sounds like: $kind';
  }

  @override
  String get useSuggestion => 'Use this';

  @override
  String get amountQuestion => 'How much do you have?';

  @override
  String get amountPlenty => 'Plenty';

  @override
  String get amountSome => 'Some';

  @override
  String get amountLow => 'Low';

  @override
  String get availabilityQuestion => 'When is it available?';

  @override
  String get availabilityNow => 'Now';

  @override
  String get availabilityToday => 'Today';

  @override
  String get availabilityCustom => 'Other time';

  @override
  String get availabilityNoteLabel => 'When?';

  @override
  String get availabilityNoteHint => 'For example: after 6 pm';

  @override
  String get transportQuestion => 'How can you transport?';

  @override
  String get transportWalking => 'Walking';

  @override
  String get transportBicycle => 'Bicycle';

  @override
  String get transportCar => 'Car';

  @override
  String get transportTruck => 'Truck';

  @override
  String get transportVan => 'Van';

  @override
  String get capacityQuestion => 'How much can you carry?';

  @override
  String get capacitySmall => 'Small';

  @override
  String get capacityMedium => 'Medium';

  @override
  String get capacityLarge => 'Large';

  @override
  String get supplyWater => 'Water';

  @override
  String get supplyFood => 'Food';

  @override
  String get supplyBlankets => 'Blankets';

  @override
  String get supplyBatteries => 'Batteries';

  @override
  String get supplyCharging => 'Charging';

  @override
  String get supplyMedicine => 'Medicine';

  @override
  String get supplyTransportation => 'Transportation';

  @override
  String get supplyShelter => 'Shelter';

  @override
  String get supplyTools => 'Tools';

  @override
  String get supplyOther => 'Other';

  @override
  String get problemSupplies => 'Choose at least one supply.';

  @override
  String get problemTransport => 'Choose how you can transport.';

  @override
  String get resHospital => 'Hospital';

  @override
  String get resPharmacy => 'Pharmacy';

  @override
  String get resPolice => 'Police';

  @override
  String get resFire => 'Fire station';

  @override
  String get resWater => 'Water';

  @override
  String get resFood => 'Food';

  @override
  String get resShelter => 'Shelter';

  @override
  String get resCharging => 'Charging';

  @override
  String get resTransportation => 'Transportation';

  @override
  String get resRoadProblem => 'Road problem';

  @override
  String get verifiedOrg => 'Verified organization';

  @override
  String get communityResource => 'Community resource';

  @override
  String get unconfirmed => 'Unconfirmed';

  @override
  String get confidenceHigh => 'High confidence';

  @override
  String get confidenceMedium => 'Medium confidence';

  @override
  String get confidenceLow => 'Low confidence';

  @override
  String get trustSource => 'Source';

  @override
  String get trustCorroboration => 'Confirmations';

  @override
  String get trustFreshness => 'Freshness';

  @override
  String confirmationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count confirmations',
      one: '1 confirmation',
      zero: 'No confirmations yet',
    );
    return '$_temp0';
  }

  @override
  String disputesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disputes',
      one: '1 dispute',
      zero: 'no disputes',
    );
    return '$_temp0';
  }

  @override
  String get oneReport => 'Only 1 report so far';

  @override
  String officialUpdate(String time) {
    return 'Official update $time';
  }

  @override
  String lastObservation(String time) {
    return 'Most recent observation $time';
  }

  @override
  String staleWarning(String time) {
    return 'Last observed $time. May be out of date.';
  }

  @override
  String get voteUseful => 'Useful';

  @override
  String get voteConfirm => 'Confirm';

  @override
  String get voteConfirmSub => 'I saw this myself';

  @override
  String get voteDispute => 'Dispute';

  @override
  String get voteDisputeSub => 'What I saw was different';

  @override
  String get voted => 'Thanks. Your report is signed and shared.';

  @override
  String get voteWithdrawnToast => 'Report withdrawn';

  @override
  String get approxLocation => 'Approximate location';

  @override
  String get inventoryTitle => 'Supply';

  @override
  String officialStock(int count, String time) {
    return 'Official count: $count at $time';
  }

  @override
  String reservedFor(int count, String id) {
    return '$count reserved for Mission $id';
  }

  @override
  String remainingCount(int count) {
    return '$count remaining';
  }

  @override
  String get communityReports => 'Community reports';

  @override
  String observationAt(String text, String time) {
    return '$text at $time';
  }

  @override
  String get addHereTitle => 'Add something here';

  @override
  String get addHereHint =>
      'Tap and hold the map to add water, food, shelter or a problem you see.';

  @override
  String get addNoteHint => 'Add a short note (optional)';

  @override
  String get addResource => 'Add';

  @override
  String get resourceAdded => 'Added. Others see an approximate location.';

  @override
  String get resourceRemoved => 'Removed';

  @override
  String get addedByYou => 'Added by you';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusReady => 'Ready';

  @override
  String lastSyncAgo(String time) {
    return 'Last sync $time';
  }

  @override
  String alertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alerts',
      one: '1 alert',
    );
    return '$_temp0';
  }

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get layerFacilities => 'Hospitals, pharmacies, police and fire';

  @override
  String get layerLive => 'Water, food, shelter and reports';

  @override
  String get networkTitle => 'Network status';

  @override
  String get netInternet => 'Internet';

  @override
  String get netPeers => 'Nearby phones';

  @override
  String get netNode => 'Resilience node';

  @override
  String get netLora => 'LoRa radio';

  @override
  String get netLastLocal => 'Last sync nearby';

  @override
  String get netLastGlobal => 'Last sync with the cloud';

  @override
  String get netConnected => 'Connected';

  @override
  String get netNotConnected => 'Not connected';

  @override
  String peersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phones',
      one: '1 phone',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String queuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items waiting to send',
      one: '1 item waiting to send',
      zero: 'Nothing waiting to send',
    );
    return '$_temp0';
  }

  @override
  String get demoInternet => 'Demo: pretend the internet is back';

  @override
  String get demoInternetSub =>
      'Shows what changes when this phone gets online';

  @override
  String get viewRadios => 'Radios on the mesh';

  @override
  String get downloadsTitle => 'Offline downloads';

  @override
  String packageTitle(String region) {
    return '$region readiness package';
  }

  @override
  String get packageContents =>
      'Offline map, emergency facilities, routing data, trusted organizations, revocations, emergency instructions and recent resource state.';

  @override
  String packageSize(int size, int version) {
    return '$size MB, version $version';
  }

  @override
  String packageUpToDate(String time) {
    return 'Up to date. Downloaded $time';
  }

  @override
  String packageUpdate(int version) {
    return 'Update available: version $version';
  }

  @override
  String get downloadNow => 'Download now';

  @override
  String downloadingPercent(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get downloadNeedsNet => 'Needs internet or a Resilience Node nearby.';

  @override
  String preparednessNotice(String region, int size) {
    return 'New offline package for $region: $size MB';
  }

  @override
  String get download => 'Download';

  @override
  String get orgsTitle => 'Trusted organizations';

  @override
  String certifiedBy(String name) {
    return 'Certified by $name';
  }

  @override
  String get rootOfTrust => 'Root of trust';

  @override
  String revocationsChecked(String time) {
    return 'Certificates and revocations checked $time. Offline, this is the newest list this phone has.';
  }

  @override
  String get tabPeople => 'People';

  @override
  String get tabOrganizations => 'Organizations';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get myQr => 'My QR';

  @override
  String get moreWaysToAdd => 'More ways to add';

  @override
  String get addByUsername => 'Add by username';

  @override
  String get addByPhone => 'Add by phone number';

  @override
  String get needsInternetToFind =>
      'Needs internet. Ask them to show their QR code instead.';

  @override
  String get metInPerson => 'Met in person';

  @override
  String get addedByUsername => 'Added by username';

  @override
  String get addedByPhone => 'Added by phone number';

  @override
  String get myQrTitle => 'My Resilience ID';

  @override
  String get myQrHint =>
      'Show this to someone you meet. It shares your public key, never your phone number.';

  @override
  String get resilienceId => 'Resilience ID';

  @override
  String get scanTitle => 'Scan a QR code';

  @override
  String get scanHint => 'Point the camera at the QR code.';

  @override
  String get scanUnavailable =>
      'The camera isn\'t available here. Type it in instead.';

  @override
  String get typeIdLabel => 'Their Resilience ID';

  @override
  String get typeIdHint => '16 letters and numbers';

  @override
  String get theirName => 'Their name';

  @override
  String get addContact => 'Add contact';

  @override
  String contactAdded(String name) {
    return '$name added';
  }

  @override
  String contactRemoved(String name) {
    return '$name removed';
  }

  @override
  String get invalidId => 'That doesn\'t look like a Resilience ID.';

  @override
  String get notFound => 'Nobody found with that.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get find => 'Find';

  @override
  String get messageAction => 'Message';

  @override
  String get removeContact => 'Remove';

  @override
  String get noContacts =>
      'No contacts yet. Scan someone\'s QR code to add them.';

  @override
  String get tabDirect => 'Direct';

  @override
  String get tabCommunity => 'Community';

  @override
  String get tabMission => 'Mission';

  @override
  String get channelPublic => 'Public. Anyone can read it.';

  @override
  String get channelCommunity => 'Community members';

  @override
  String get channelRestricted => 'Staff only, encrypted';

  @override
  String get channelMission => 'Mission team only';

  @override
  String get channelDirect => 'Private';

  @override
  String get readOnlyChannel => 'Only verified organizations post here.';

  @override
  String sendsOver(String route) {
    return 'Sends over: $route';
  }

  @override
  String get routeInternet => 'Internet';

  @override
  String get routeLocal => 'Resilience node';

  @override
  String get routeMesh => 'LoRa mesh';

  @override
  String get routeQueued => 'Waits on this phone until a route appears';

  @override
  String get deliveryQueued => 'Queued';

  @override
  String get deliveryPropagating => 'On its way';

  @override
  String get deliveryDelivered => 'Delivered';

  @override
  String get deliveryRead => 'Read';

  @override
  String get noChannels => 'No conversations here yet';

  @override
  String get deliveries => 'Deliveries';

  @override
  String get deliveriesSub => 'Missions you can carry';

  @override
  String get tabAvailable => 'Available';

  @override
  String get tabAssigned => 'Assigned';

  @override
  String get tabInTransit => 'In transit';

  @override
  String get tabHandoff => 'Handoff';

  @override
  String get tabCompleted => 'Completed';

  @override
  String missionTitle(String id) {
    return 'Mission $id';
  }

  @override
  String get priorityHigh => 'High priority';

  @override
  String get priorityNormal => 'Normal priority';

  @override
  String get priorityLow => 'Low priority';

  @override
  String get pickupLabel => 'Pickup';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get carrierLabel => 'Carrier';

  @override
  String packageLabel(String id) {
    return 'Package $id';
  }

  @override
  String get exactHidden => 'Exact address shown to the carrier only';

  @override
  String get acceptMission => 'Accept mission';

  @override
  String get missionAccepted =>
      'Mission accepted. You can now see the exact addresses.';

  @override
  String get missionReleased => 'Mission given back';

  @override
  String get confirmPickup => 'Confirm pickup';

  @override
  String get pickedUp => 'Pickup confirmed and signed';

  @override
  String get confirmDelivery => 'Confirm delivery';

  @override
  String get deliveredToast => 'Delivery confirmed and signed';

  @override
  String get handOff => 'Hand off';

  @override
  String get handoffWaiting =>
      'Waiting for the next driver to scan the package code';

  @override
  String handoffConfirmed(String name, String id) {
    return 'Handoff confirmed: $name has package $id';
  }

  @override
  String get packageCode => 'Package code';

  @override
  String get packageQrHint =>
      'The other person scans this. It holds the package number and a signature, nothing private.';

  @override
  String get scanPackage => 'Scan the package code';

  @override
  String get enterPackageId => 'Package number';

  @override
  String wrongPackage(String id) {
    return 'That isn\'t package $id.';
  }

  @override
  String get mStageAvailable => 'Available';

  @override
  String get mStageAssigned => 'Assigned to you';

  @override
  String get mStageInTransit => 'In transit';

  @override
  String get mStageHandoff => 'Awaiting handoff';

  @override
  String get mStageDelivered => 'Delivered';

  @override
  String handedOffTo(String name) {
    return 'Handed off to $name';
  }

  @override
  String get noMissions => 'Nothing here right now';

  @override
  String get deliveriesHint => 'Offer transportation to see missions near you.';

  @override
  String get sectionActivity => 'Your activity';

  @override
  String get sectionNetwork => 'Network and data';

  @override
  String get sectionSettings => 'Settings';

  @override
  String get sectionManage => 'Management';

  @override
  String get myRequests => 'My requests';

  @override
  String openCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open',
      one: '1 open',
      zero: 'None open',
    );
    return '$_temp0';
  }

  @override
  String get mySupplies => 'My supplies';

  @override
  String get notOffering => 'Not offering anything';

  @override
  String orgCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count organizations',
      one: '1 organization',
    );
    return '$_temp0';
  }

  @override
  String get historyTitle => 'Signed history';

  @override
  String get historyHint => 'Each step is signed on the phone that made it.';

  @override
  String signedBy(String id) {
    return 'Signed by $id';
  }

  @override
  String get evHelpRequested => 'Help requested';

  @override
  String get evHelpCancelled => 'Request cancelled';

  @override
  String get evHelpAccepted => 'Helper accepted';

  @override
  String get evHelpReleased => 'Helper stepped back';

  @override
  String get evHelpOffered => 'Offer published';

  @override
  String get evOfferWithdrawn => 'Offer withdrawn';

  @override
  String get evResourceCreated => 'Resource added';

  @override
  String get evResourceRemoved => 'Resource removed';

  @override
  String get evResourceConfirmed => 'Confirmed';

  @override
  String get evResourceDisputed => 'Disputed';

  @override
  String get evResourceUseful => 'Marked useful';

  @override
  String get evVoteWithdrawn => 'Report withdrawn';

  @override
  String get evContactAdded => 'Contact added';

  @override
  String get evContactRemoved => 'Contact removed';

  @override
  String get evMessageSent => 'Message sent';

  @override
  String get evMissionAccepted => 'Mission accepted';

  @override
  String get evMissionReleased => 'Mission given back';

  @override
  String get evPackagePickedUp => 'Package picked up';

  @override
  String get evPackageTransferred => 'Package handed off';

  @override
  String get evDeliveryCompleted => 'Delivery completed';

  @override
  String get stageSavedTheirs => 'Saved on their phone';

  @override
  String get stageSavedTheirsSub => 'Kept there until a radio was in range';

  @override
  String get mapSource => 'Street map from Amazon Location';

  @override
  String get mapSourceNote =>
      'Needs internet. Pins, radios and requests still show when the street map can\'t load.';

  @override
  String get mapNotSetUp => 'Street map not set up';

  @override
  String get mapOffline => 'Street map needs internet';

  @override
  String get mapLoading => 'Loading street map';

  @override
  String get missionNotFound => 'This delivery is no longer available.';

  @override
  String get resourceNotFound => 'This place is no longer on the map.';

  @override
  String get netStatusSending => 'Sending';

  @override
  String netStatusSendingSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items on their way',
      one: '1 item on its way',
    );
    return '$_temp0';
  }

  @override
  String netStatusWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Waiting for a connection: $count items held',
      one: 'Waiting for a connection: 1 item held',
    );
    return '$_temp0';
  }

  @override
  String get netStatusWaitingSub =>
      'Saved on this phone. It goes as soon as any link appears.';

  @override
  String get netStatusSent => 'Everything is sent';

  @override
  String get netStatusOffline => 'No connection right now';

  @override
  String get netStatusOfflineSub =>
      'New messages and requests wait safely on this phone.';

  @override
  String get netConnections => 'Connections';

  @override
  String get netAws => 'AWS';

  @override
  String get netAwsDirect => 'Reached over the internet';

  @override
  String get netAwsMesh => 'Reached through the mesh';

  @override
  String get netAwsNone => 'Out of reach for now';

  @override
  String get netAdvanced => 'Advanced';

  @override
  String get netAdvancedSub => 'Each link, sync times, and the demo switch';

  @override
  String get netLinkCloud => 'AWS over the internet';

  @override
  String get netLinkNode => 'Resilience node on Wi-Fi';

  @override
  String get netLinkLora => 'LoRa radio';

  @override
  String get netLinkWifi => 'Phones over Wi-Fi';

  @override
  String get netLinkBluetooth => 'Phones over Bluetooth';

  @override
  String get netLinkUp => 'Working';

  @override
  String get netLinkDown => 'Not in range';

  @override
  String get netLinkUnavailable => 'Not set up on this phone';

  @override
  String netLinkConfirmed(String time) {
    return 'Last confirmed $time';
  }

  @override
  String get privacyLocationTitle => 'Your location';

  @override
  String get privacyLocationBody =>
      'Your location stays on this phone. It is shared only while you carry a delivery, so the people waiting can see it coming, and it stops when the delivery ends. A help request or SOS carries only the place you chose to send with it.';
}
