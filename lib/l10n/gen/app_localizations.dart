import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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
    Locale('es'),
    Locale('fil'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get appTitle;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @helpButton.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpButton;

  /// No description provided for @helpButtonSemantics.
  ///
  /// In en, this message translates to:
  /// **'Request help'**
  String get helpButtonSemantics;

  /// No description provided for @helpButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Tap for options. Hold for 2 seconds to send an SOS.'**
  String get helpButtonHint;

  /// No description provided for @helpMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get helpMenuTitle;

  /// No description provided for @needHelp.
  ///
  /// In en, this message translates to:
  /// **'I need help'**
  String get needHelp;

  /// No description provided for @needHelpSub.
  ///
  /// In en, this message translates to:
  /// **'Tell helpers nearby what you need'**
  String get needHelpSub;

  /// No description provided for @canHelp.
  ///
  /// In en, this message translates to:
  /// **'I can help'**
  String get canHelp;

  /// No description provided for @canHelpSub.
  ///
  /// In en, this message translates to:
  /// **'Let people nearby know what you can offer'**
  String get canHelpSub;

  /// No description provided for @sosTip.
  ///
  /// In en, this message translates to:
  /// **'In danger? Hold the red Help button to send an SOS right away.'**
  String get sosTip;

  /// No description provided for @holdForSos.
  ///
  /// In en, this message translates to:
  /// **'Hold for SOS'**
  String get holdForSos;

  /// No description provided for @holdForSosSub.
  ///
  /// In en, this message translates to:
  /// **'Sends your location right away'**
  String get holdForSosSub;

  /// No description provided for @keepHolding.
  ///
  /// In en, this message translates to:
  /// **'Keep holding to send the SOS'**
  String get keepHolding;

  /// No description provided for @sosSent.
  ///
  /// In en, this message translates to:
  /// **'SOS sent with your location'**
  String get sosSent;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @radiosNearby.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No radios nearby} =1{1 radio nearby} other{{count} radios nearby}}'**
  String radiosNearby(int count);

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @demoMap.
  ///
  /// In en, this message translates to:
  /// **'Demo map'**
  String get demoMap;

  /// No description provided for @demoMapNote.
  ///
  /// In en, this message translates to:
  /// **'This demo map works with no internet. Its streets are made up. Real maps can be saved on the phone for offline use.'**
  String get demoMapNote;

  /// No description provided for @layers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get layers;

  /// No description provided for @layerRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests for help'**
  String get layerRequests;

  /// No description provided for @layerRadios.
  ///
  /// In en, this message translates to:
  /// **'Radios and coverage'**
  String get layerRadios;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'Show my location'**
  String get myLocation;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @nothingNearby.
  ///
  /// In en, this message translates to:
  /// **'Nothing nearby yet'**
  String get nothingNearby;

  /// No description provided for @distanceMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m away'**
  String distanceMeters(int meters);

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String distanceKm(String km);

  /// No description provided for @howItTravels.
  ///
  /// In en, this message translates to:
  /// **'How your requests travel'**
  String get howItTravels;

  /// No description provided for @travelPhone.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get travelPhone;

  /// No description provided for @travelPhoneSub.
  ///
  /// In en, this message translates to:
  /// **'Saves everything first, even with no signal'**
  String get travelPhoneSub;

  /// No description provided for @travelMesh.
  ///
  /// In en, this message translates to:
  /// **'Radio mesh'**
  String get travelMesh;

  /// No description provided for @travelMeshSub.
  ///
  /// In en, this message translates to:
  /// **'Passes it from radio to radio'**
  String get travelMeshSub;

  /// No description provided for @travelCloud.
  ///
  /// In en, this message translates to:
  /// **'AWS'**
  String get travelCloud;

  /// No description provided for @travelCloudOnline.
  ///
  /// In en, this message translates to:
  /// **'Checks it and keeps a copy'**
  String get travelCloudOnline;

  /// No description provided for @travelCloudOffline.
  ///
  /// In en, this message translates to:
  /// **'Out of reach. Your request waits on the mesh.'**
  String get travelCloudOffline;

  /// No description provided for @travelHelpers.
  ///
  /// In en, this message translates to:
  /// **'Helpers'**
  String get travelHelpers;

  /// No description provided for @travelHelpersSub.
  ///
  /// In en, this message translates to:
  /// **'See your request and reply'**
  String get travelHelpersSub;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @openDetails.
  ///
  /// In en, this message translates to:
  /// **'Open details'**
  String get openDetails;

  /// No description provided for @kindMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical help'**
  String get kindMedical;

  /// No description provided for @kindMedicalSub.
  ///
  /// In en, this message translates to:
  /// **'Injured, sick or trapped'**
  String get kindMedicalSub;

  /// No description provided for @kindWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get kindWater;

  /// No description provided for @kindWaterSub.
  ///
  /// In en, this message translates to:
  /// **'Drinking water'**
  String get kindWaterSub;

  /// No description provided for @kindShelter.
  ///
  /// In en, this message translates to:
  /// **'Shelter'**
  String get kindShelter;

  /// No description provided for @kindShelterSub.
  ///
  /// In en, this message translates to:
  /// **'A safe place to stay'**
  String get kindShelterSub;

  /// No description provided for @kindPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get kindPower;

  /// No description provided for @kindPowerSub.
  ///
  /// In en, this message translates to:
  /// **'Charge a phone or medical device'**
  String get kindPowerSub;

  /// No description provided for @kindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kindOther;

  /// No description provided for @kindOtherSub.
  ///
  /// In en, this message translates to:
  /// **'Describe it in the next step'**
  String get kindOtherSub;

  /// No description provided for @kindSos.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get kindSos;

  /// No description provided for @urgencyNow.
  ///
  /// In en, this message translates to:
  /// **'Right now'**
  String get urgencyNow;

  /// No description provided for @urgencyNowSub.
  ///
  /// In en, this message translates to:
  /// **'Life or safety at risk'**
  String get urgencyNowSub;

  /// No description provided for @urgencySoon.
  ///
  /// In en, this message translates to:
  /// **'Within hours'**
  String get urgencySoon;

  /// No description provided for @urgencySoonSub.
  ///
  /// In en, this message translates to:
  /// **'Getting worse'**
  String get urgencySoonSub;

  /// No description provided for @urgencyLater.
  ///
  /// In en, this message translates to:
  /// **'Can wait'**
  String get urgencyLater;

  /// No description provided for @urgencyLaterSub.
  ///
  /// In en, this message translates to:
  /// **'Stable for now'**
  String get urgencyLaterSub;

  /// No description provided for @stageSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get stageSaved;

  /// No description provided for @stageSavedSub.
  ///
  /// In en, this message translates to:
  /// **'Sends as soon as a radio is in range'**
  String get stageSavedSub;

  /// No description provided for @stageMesh.
  ///
  /// In en, this message translates to:
  /// **'Sent over the mesh'**
  String get stageMesh;

  /// No description provided for @stageMeshSub.
  ///
  /// In en, this message translates to:
  /// **'{hops, plural, =0{Reached a radio directly} =1{Passed through 1 radio} other{Passed through {hops} radios}}'**
  String stageMeshSub(int hops);

  /// No description provided for @stageVerified.
  ///
  /// In en, this message translates to:
  /// **'Checked by the server'**
  String get stageVerified;

  /// No description provided for @stageVerifiedSub.
  ///
  /// In en, this message translates to:
  /// **'AWS checked the request and saved a copy'**
  String get stageVerifiedSub;

  /// No description provided for @stageAssigned.
  ///
  /// In en, this message translates to:
  /// **'Helper found'**
  String get stageAssigned;

  /// No description provided for @stageAssignedSub.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted the request'**
  String stageAssignedSub(String name);

  /// No description provided for @stageOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Help is on the way'**
  String get stageOnTheWay;

  /// No description provided for @stageOnTheWaySub.
  ///
  /// In en, this message translates to:
  /// **'{name} is heading there'**
  String stageOnTheWaySub(String name);

  /// No description provided for @stageResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get stageResolved;

  /// No description provided for @stageResolvedSub.
  ///
  /// In en, this message translates to:
  /// **'Marked as done'**
  String get stageResolvedSub;

  /// No description provided for @stageWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get stageWaiting;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(int step, int total);

  /// No description provided for @helpStep1Title.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get helpStep1Title;

  /// No description provided for @helpStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Anything else?'**
  String get helpStep2Title;

  /// No description provided for @urgencyQuestion.
  ///
  /// In en, this message translates to:
  /// **'How urgent is it?'**
  String get urgencyQuestion;

  /// No description provided for @peopleQuestion.
  ///
  /// In en, this message translates to:
  /// **'How many people need help?'**
  String get peopleQuestion;

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String peopleCount(int count);

  /// No description provided for @fewerPeople.
  ///
  /// In en, this message translates to:
  /// **'Fewer people'**
  String get fewerPeople;

  /// No description provided for @morePeople.
  ///
  /// In en, this message translates to:
  /// **'More people'**
  String get morePeople;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationTitle;

  /// No description provided for @locationAuto.
  ///
  /// In en, this message translates to:
  /// **'Shared automatically, accurate to {meters} m'**
  String locationAuto(int meters);

  /// No description provided for @locationMissing.
  ///
  /// In en, this message translates to:
  /// **'Your location isn\'t available. Describe where you are.'**
  String get locationMissing;

  /// No description provided for @locationNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Describe where you are'**
  String get locationNoteLabel;

  /// No description provided for @locationNoteHint.
  ///
  /// In en, this message translates to:
  /// **'For example: 2nd floor, near the stairs'**
  String get locationNoteHint;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Anything else? (optional)'**
  String get noteLabel;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get requestSent;

  /// No description provided for @requestDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Request discarded'**
  String get requestDiscarded;

  /// No description provided for @requestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get requestCancelled;

  /// No description provided for @requestRestored.
  ///
  /// In en, this message translates to:
  /// **'Request restored'**
  String get requestRestored;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// No description provided for @problemMissingKind.
  ///
  /// In en, this message translates to:
  /// **'Choose what you need.'**
  String get problemMissingKind;

  /// No description provided for @problemPeople.
  ///
  /// In en, this message translates to:
  /// **'Enter between 1 and {max} people.'**
  String problemPeople(int max);

  /// No description provided for @problemNoteTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep notes under {max} characters.'**
  String problemNoteTooLong(int max);

  /// No description provided for @problemLocation.
  ///
  /// In en, this message translates to:
  /// **'Describe where you are, since your location isn\'t available.'**
  String get problemLocation;

  /// No description provided for @offerStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Supplies I can offer'**
  String get offerStep1Title;

  /// No description provided for @offerStep2Title.
  ///
  /// In en, this message translates to:
  /// **'A few details'**
  String get offerStep2Title;

  /// No description provided for @offerNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for people nearby (optional)'**
  String get offerNoteLabel;

  /// No description provided for @offerNoteHint.
  ///
  /// In en, this message translates to:
  /// **'For example: I have a car with room for 4'**
  String get offerNoteHint;

  /// No description provided for @startOffering.
  ///
  /// In en, this message translates to:
  /// **'Start offering'**
  String get startOffering;

  /// No description provided for @offeringStarted.
  ///
  /// In en, this message translates to:
  /// **'You\'re offering help'**
  String get offeringStarted;

  /// No description provided for @offeringList.
  ///
  /// In en, this message translates to:
  /// **'You\'re offering: {list}'**
  String offeringList(String list);

  /// No description provided for @stopOffering.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopOffering;

  /// No description provided for @offerStopped.
  ///
  /// In en, this message translates to:
  /// **'You stopped offering help'**
  String get offerStopped;

  /// No description provided for @offerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Can you help? Let people nearby know.'**
  String get offerPrompt;

  /// No description provided for @tabNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get tabNearMe;

  /// No description provided for @tabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get tabMine;

  /// No description provided for @iCanHelp.
  ///
  /// In en, this message translates to:
  /// **'I can help'**
  String get iCanHelp;

  /// No description provided for @youAreHelping.
  ///
  /// In en, this message translates to:
  /// **'You\'re helping'**
  String get youAreHelping;

  /// No description provided for @stopHelping.
  ///
  /// In en, this message translates to:
  /// **'Stop helping'**
  String get stopHelping;

  /// No description provided for @acceptedToast.
  ///
  /// In en, this message translates to:
  /// **'You\'re helping. They can see you\'re coming.'**
  String get acceptedToast;

  /// No description provided for @releasedToast.
  ///
  /// In en, this message translates to:
  /// **'You stopped helping'**
  String get releasedToast;

  /// No description provided for @noNearby.
  ///
  /// In en, this message translates to:
  /// **'No open requests nearby'**
  String get noNearby;

  /// No description provided for @noMine.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t asked for help'**
  String get noMine;

  /// No description provided for @fromName.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String fromName(String name);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String daysAgo(int n);

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// No description provided for @detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get detailsTitle;

  /// No description provided for @showToResponder.
  ///
  /// In en, this message translates to:
  /// **'Show to responder'**
  String get showToResponder;

  /// No description provided for @requestNotFound.
  ///
  /// In en, this message translates to:
  /// **'This request is no longer available.'**
  String get requestNotFound;

  /// No description provided for @cardNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'I need help'**
  String get cardNeedHelp;

  /// No description provided for @cardSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left or right to change the language'**
  String get cardSwipeHint;

  /// No description provided for @cardTheirWords.
  ///
  /// In en, this message translates to:
  /// **'Their own words, not translated:'**
  String get cardTheirWords;

  /// No description provided for @urgencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get urgencyTitle;

  /// No description provided for @peopleTitle.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get peopleTitle;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Use phone setting'**
  String get languageSystem;

  /// No description provided for @display.
  ///
  /// In en, this message translates to:
  /// **'Display and accessibility'**
  String get display;

  /// No description provided for @displaySub.
  ///
  /// In en, this message translates to:
  /// **'Text size {percent}%'**
  String displaySub(int percent);

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get highContrast;

  /// No description provided for @highContrastSub.
  ///
  /// In en, this message translates to:
  /// **'Stronger colors and borders'**
  String get highContrastSub;

  /// No description provided for @textPreview.
  ///
  /// In en, this message translates to:
  /// **'This is how text will look.'**
  String get textPreview;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get privacy;

  /// No description provided for @phoneLockOn.
  ///
  /// In en, this message translates to:
  /// **'Phone lock is on'**
  String get phoneLockOn;

  /// No description provided for @phoneLockOff.
  ///
  /// In en, this message translates to:
  /// **'Phone lock is off'**
  String get phoneLockOff;

  /// No description provided for @phoneLock.
  ///
  /// In en, this message translates to:
  /// **'Lock with Face ID or fingerprint'**
  String get phoneLock;

  /// No description provided for @phoneLockSub.
  ///
  /// In en, this message translates to:
  /// **'Uses your phone passcode if that fails'**
  String get phoneLockSub;

  /// No description provided for @phoneLockWeb.
  ///
  /// In en, this message translates to:
  /// **'Available in the iOS and Android app'**
  String get phoneLockWeb;

  /// No description provided for @phoneLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Set up a passcode or Face ID on this phone first'**
  String get phoneLockUnavailable;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @lockNowSub.
  ///
  /// In en, this message translates to:
  /// **'SOS still works while locked'**
  String get lockNowSub;

  /// No description provided for @clearTemp.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary data'**
  String get clearTemp;

  /// No description provided for @clearTempSub.
  ///
  /// In en, this message translates to:
  /// **'Old messages and finished requests. AWS keeps its copies.'**
  String get clearTempSub;

  /// No description provided for @cleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to clear} =1{Cleared 1 item} other{Cleared {count} items}}'**
  String cleared(int count);

  /// No description provided for @eraseAll.
  ///
  /// In en, this message translates to:
  /// **'Erase everything on this phone'**
  String get eraseAll;

  /// No description provided for @eraseAllSub.
  ///
  /// In en, this message translates to:
  /// **'Hold for 3 seconds. This can\'t be undone.'**
  String get eraseAllSub;

  /// No description provided for @erased.
  ///
  /// In en, this message translates to:
  /// **'Everything on this phone was erased'**
  String get erased;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Radio network'**
  String get network;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage network'**
  String get manage;

  /// No description provided for @manageSub.
  ///
  /// In en, this message translates to:
  /// **'Turn radios on or off for everyone'**
  String get manageSub;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Users and roles'**
  String get admin;

  /// No description provided for @adminSub.
  ///
  /// In en, this message translates to:
  /// **'Change who can manage the network'**
  String get adminSub;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInAs(String name);

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Using Mesh as a guest'**
  String get guestMode;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInSub.
  ///
  /// In en, this message translates to:
  /// **'Optional. Helpers and managers sign in.'**
  String get signInSub;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @roleClient.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleClient;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @demoSignIn.
  ///
  /// In en, this message translates to:
  /// **'Demo sign-in. In the real app, your role comes from the server.'**
  String get demoSignIn;

  /// No description provided for @nodeOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get nodeOnline;

  /// No description provided for @nodeOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get nodeOffline;

  /// No description provided for @hopsDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get hopsDirect;

  /// No description provided for @hopsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hop} other{{count} hops}}'**
  String hopsCount(int count);

  /// No description provided for @externalPower.
  ///
  /// In en, this message translates to:
  /// **'External power'**
  String get externalPower;

  /// No description provided for @noNodes.
  ///
  /// In en, this message translates to:
  /// **'No radios heard yet'**
  String get noNodes;

  /// No description provided for @nodeId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get nodeId;

  /// No description provided for @lastHeard.
  ///
  /// In en, this message translates to:
  /// **'Last heard'**
  String get lastHeard;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @signalStrength.
  ///
  /// In en, this message translates to:
  /// **'Signal strength'**
  String get signalStrength;

  /// No description provided for @signalNoise.
  ///
  /// In en, this message translates to:
  /// **'Signal to noise'**
  String get signalNoise;

  /// No description provided for @hopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hops'**
  String get hopsTitle;

  /// No description provided for @manageHint.
  ///
  /// In en, this message translates to:
  /// **'Radios you turn off are hidden from members.'**
  String get manageHint;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this page.'**
  String get loadFailed;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mesh is locked'**
  String get lockedTitle;

  /// No description provided for @lockedSub.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see your requests and messages.'**
  String get lockedSub;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Mesh'**
  String get unlockReason;

  /// No description provided for @unlockWebNote.
  ///
  /// In en, this message translates to:
  /// **'The web preview has no Face ID, so Unlock opens the app directly.'**
  String get unlockWebNote;

  /// No description provided for @unlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock. Try again or use your passcode.'**
  String get unlockFailed;

  /// No description provided for @alertNearby.
  ///
  /// In en, this message translates to:
  /// **'New request nearby: {kind}'**
  String alertNearby(String kind);

  /// No description provided for @alertHelper.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your request'**
  String alertHelper(String name);

  /// No description provided for @navContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get navContacts;

  /// No description provided for @kindFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get kindFood;

  /// No description provided for @kindFoodSub.
  ///
  /// In en, this message translates to:
  /// **'Meals or baby formula'**
  String get kindFoodSub;

  /// No description provided for @kindMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get kindMedicine;

  /// No description provided for @kindMedicineSub.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions, insulin, inhalers'**
  String get kindMedicineSub;

  /// No description provided for @kindTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get kindTransportation;

  /// No description provided for @kindTransportationSub.
  ///
  /// In en, this message translates to:
  /// **'A ride, or help moving someone'**
  String get kindTransportationSub;

  /// No description provided for @kindCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get kindCommunication;

  /// No description provided for @kindCommunicationSub.
  ///
  /// In en, this message translates to:
  /// **'Reach family or call for help'**
  String get kindCommunicationSub;

  /// No description provided for @noteExampleHint.
  ///
  /// In en, this message translates to:
  /// **'For example: need somewhere cold to keep insulin for one person'**
  String get noteExampleHint;

  /// No description provided for @structuredFirst.
  ///
  /// In en, this message translates to:
  /// **'Your choice is sent first, so it gets through even on a weak network. Your note follows when there is room.'**
  String get structuredFirst;

  /// No description provided for @suggestion.
  ///
  /// In en, this message translates to:
  /// **'Sounds like: {kind}'**
  String suggestion(String kind);

  /// No description provided for @useSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get useSuggestion;

  /// No description provided for @amountQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much do you have?'**
  String get amountQuestion;

  /// No description provided for @amountPlenty.
  ///
  /// In en, this message translates to:
  /// **'Plenty'**
  String get amountPlenty;

  /// No description provided for @amountSome.
  ///
  /// In en, this message translates to:
  /// **'Some'**
  String get amountSome;

  /// No description provided for @amountLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get amountLow;

  /// No description provided for @availabilityQuestion.
  ///
  /// In en, this message translates to:
  /// **'When is it available?'**
  String get availabilityQuestion;

  /// No description provided for @availabilityNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get availabilityNow;

  /// No description provided for @availabilityToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get availabilityToday;

  /// No description provided for @availabilityCustom.
  ///
  /// In en, this message translates to:
  /// **'Other time'**
  String get availabilityCustom;

  /// No description provided for @availabilityNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'When?'**
  String get availabilityNoteLabel;

  /// No description provided for @availabilityNoteHint.
  ///
  /// In en, this message translates to:
  /// **'For example: after 6 pm'**
  String get availabilityNoteHint;

  /// No description provided for @transportQuestion.
  ///
  /// In en, this message translates to:
  /// **'How can you transport?'**
  String get transportQuestion;

  /// No description provided for @transportWalking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get transportWalking;

  /// No description provided for @transportBicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get transportBicycle;

  /// No description provided for @transportCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get transportCar;

  /// No description provided for @transportTruck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get transportTruck;

  /// No description provided for @transportVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get transportVan;

  /// No description provided for @capacityQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much can you carry?'**
  String get capacityQuestion;

  /// No description provided for @capacitySmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get capacitySmall;

  /// No description provided for @capacityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get capacityMedium;

  /// No description provided for @capacityLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get capacityLarge;

  /// No description provided for @supplyWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get supplyWater;

  /// No description provided for @supplyFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get supplyFood;

  /// No description provided for @supplyBlankets.
  ///
  /// In en, this message translates to:
  /// **'Blankets'**
  String get supplyBlankets;

  /// No description provided for @supplyBatteries.
  ///
  /// In en, this message translates to:
  /// **'Batteries'**
  String get supplyBatteries;

  /// No description provided for @supplyCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get supplyCharging;

  /// No description provided for @supplyMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get supplyMedicine;

  /// No description provided for @supplyTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get supplyTransportation;

  /// No description provided for @supplyShelter.
  ///
  /// In en, this message translates to:
  /// **'Shelter'**
  String get supplyShelter;

  /// No description provided for @supplyTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get supplyTools;

  /// No description provided for @supplyOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supplyOther;

  /// No description provided for @problemSupplies.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one supply.'**
  String get problemSupplies;

  /// No description provided for @problemTransport.
  ///
  /// In en, this message translates to:
  /// **'Choose how you can transport.'**
  String get problemTransport;

  /// No description provided for @resHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get resHospital;

  /// No description provided for @resPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get resPharmacy;

  /// No description provided for @resPolice.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get resPolice;

  /// No description provided for @resFire.
  ///
  /// In en, this message translates to:
  /// **'Fire station'**
  String get resFire;

  /// No description provided for @resWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get resWater;

  /// No description provided for @resFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get resFood;

  /// No description provided for @resShelter.
  ///
  /// In en, this message translates to:
  /// **'Shelter'**
  String get resShelter;

  /// No description provided for @resCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get resCharging;

  /// No description provided for @resTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get resTransportation;

  /// No description provided for @resRoadProblem.
  ///
  /// In en, this message translates to:
  /// **'Road problem'**
  String get resRoadProblem;

  /// No description provided for @verifiedOrg.
  ///
  /// In en, this message translates to:
  /// **'Verified organization'**
  String get verifiedOrg;

  /// No description provided for @communityResource.
  ///
  /// In en, this message translates to:
  /// **'Community resource'**
  String get communityResource;

  /// No description provided for @unconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed'**
  String get unconfirmed;

  /// No description provided for @confidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get confidenceHigh;

  /// No description provided for @confidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get confidenceMedium;

  /// No description provided for @confidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get confidenceLow;

  /// No description provided for @trustSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get trustSource;

  /// No description provided for @trustCorroboration.
  ///
  /// In en, this message translates to:
  /// **'Confirmations'**
  String get trustCorroboration;

  /// No description provided for @trustFreshness.
  ///
  /// In en, this message translates to:
  /// **'Freshness'**
  String get trustFreshness;

  /// No description provided for @confirmationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No confirmations yet} =1{1 confirmation} other{{count} confirmations}}'**
  String confirmationsCount(int count);

  /// No description provided for @disputesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no disputes} =1{1 dispute} other{{count} disputes}}'**
  String disputesCount(int count);

  /// No description provided for @oneReport.
  ///
  /// In en, this message translates to:
  /// **'Only 1 report so far'**
  String get oneReport;

  /// No description provided for @officialUpdate.
  ///
  /// In en, this message translates to:
  /// **'Official update {time}'**
  String officialUpdate(String time);

  /// No description provided for @lastObservation.
  ///
  /// In en, this message translates to:
  /// **'Most recent observation {time}'**
  String lastObservation(String time);

  /// No description provided for @staleWarning.
  ///
  /// In en, this message translates to:
  /// **'Last observed {time}. May be out of date.'**
  String staleWarning(String time);

  /// No description provided for @voteUseful.
  ///
  /// In en, this message translates to:
  /// **'Useful'**
  String get voteUseful;

  /// No description provided for @voteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get voteConfirm;

  /// No description provided for @voteConfirmSub.
  ///
  /// In en, this message translates to:
  /// **'I saw this myself'**
  String get voteConfirmSub;

  /// No description provided for @voteDispute.
  ///
  /// In en, this message translates to:
  /// **'Dispute'**
  String get voteDispute;

  /// No description provided for @voteDisputeSub.
  ///
  /// In en, this message translates to:
  /// **'What I saw was different'**
  String get voteDisputeSub;

  /// No description provided for @voted.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Your report is signed and shared.'**
  String get voted;

  /// No description provided for @voteWithdrawnToast.
  ///
  /// In en, this message translates to:
  /// **'Report withdrawn'**
  String get voteWithdrawnToast;

  /// No description provided for @approxLocation.
  ///
  /// In en, this message translates to:
  /// **'Approximate location'**
  String get approxLocation;

  /// No description provided for @inventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Supply'**
  String get inventoryTitle;

  /// No description provided for @officialStock.
  ///
  /// In en, this message translates to:
  /// **'Official count: {count} at {time}'**
  String officialStock(int count, String time);

  /// No description provided for @reservedFor.
  ///
  /// In en, this message translates to:
  /// **'{count} reserved for Mission {id}'**
  String reservedFor(int count, String id);

  /// No description provided for @remainingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String remainingCount(int count);

  /// No description provided for @communityReports.
  ///
  /// In en, this message translates to:
  /// **'Community reports'**
  String get communityReports;

  /// No description provided for @observationAt.
  ///
  /// In en, this message translates to:
  /// **'{text} at {time}'**
  String observationAt(String text, String time);

  /// No description provided for @addHereTitle.
  ///
  /// In en, this message translates to:
  /// **'Add something here'**
  String get addHereTitle;

  /// No description provided for @addHereHint.
  ///
  /// In en, this message translates to:
  /// **'Tap and hold the map to add water, food, shelter or a problem you see.'**
  String get addHereHint;

  /// No description provided for @addNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note (optional)'**
  String get addNoteHint;

  /// No description provided for @addResource.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addResource;

  /// No description provided for @resourceAdded.
  ///
  /// In en, this message translates to:
  /// **'Added. Others see an approximate location.'**
  String get resourceAdded;

  /// No description provided for @resourceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get resourceRemoved;

  /// No description provided for @addedByYou.
  ///
  /// In en, this message translates to:
  /// **'Added by you'**
  String get addedByYou;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @lastSyncAgo.
  ///
  /// In en, this message translates to:
  /// **'Last sync {time}'**
  String lastSyncAgo(String time);

  /// No description provided for @alertsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 alert} other{{count} alerts}}'**
  String alertsCount(int count);

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @layerFacilities.
  ///
  /// In en, this message translates to:
  /// **'Hospitals, pharmacies, police and fire'**
  String get layerFacilities;

  /// No description provided for @layerLive.
  ///
  /// In en, this message translates to:
  /// **'Water, food, shelter and reports'**
  String get layerLive;

  /// No description provided for @networkTitle.
  ///
  /// In en, this message translates to:
  /// **'Network status'**
  String get networkTitle;

  /// No description provided for @netInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get netInternet;

  /// No description provided for @netPeers.
  ///
  /// In en, this message translates to:
  /// **'Nearby phones'**
  String get netPeers;

  /// No description provided for @netNode.
  ///
  /// In en, this message translates to:
  /// **'Resilience node'**
  String get netNode;

  /// No description provided for @netLora.
  ///
  /// In en, this message translates to:
  /// **'LoRa radio'**
  String get netLora;

  /// No description provided for @netLastLocal.
  ///
  /// In en, this message translates to:
  /// **'Last sync nearby'**
  String get netLastLocal;

  /// No description provided for @netLastGlobal.
  ///
  /// In en, this message translates to:
  /// **'Last sync with the cloud'**
  String get netLastGlobal;

  /// No description provided for @netConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get netConnected;

  /// No description provided for @netNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get netNotConnected;

  /// No description provided for @peersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 phone} other{{count} phones}}'**
  String peersCount(int count);

  /// No description provided for @queuedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing waiting to send} =1{1 item waiting to send} other{{count} items waiting to send}}'**
  String queuedCount(int count);

  /// No description provided for @demoInternet.
  ///
  /// In en, this message translates to:
  /// **'Demo: pretend the internet is back'**
  String get demoInternet;

  /// No description provided for @demoInternetSub.
  ///
  /// In en, this message translates to:
  /// **'Shows what changes when this phone gets online'**
  String get demoInternetSub;

  /// No description provided for @viewRadios.
  ///
  /// In en, this message translates to:
  /// **'Radios on the mesh'**
  String get viewRadios;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline downloads'**
  String get downloadsTitle;

  /// No description provided for @packageTitle.
  ///
  /// In en, this message translates to:
  /// **'{region} readiness package'**
  String packageTitle(String region);

  /// No description provided for @packageContents.
  ///
  /// In en, this message translates to:
  /// **'Offline map, emergency facilities, routing data, trusted organizations, revocations, emergency instructions and recent resource state.'**
  String get packageContents;

  /// No description provided for @packageSize.
  ///
  /// In en, this message translates to:
  /// **'{size} MB, version {version}'**
  String packageSize(int size, int version);

  /// No description provided for @packageUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date. Downloaded {time}'**
  String packageUpToDate(String time);

  /// No description provided for @packageUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update available: version {version}'**
  String packageUpdate(int version);

  /// No description provided for @downloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download now'**
  String get downloadNow;

  /// No description provided for @downloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String downloadingPercent(int percent);

  /// No description provided for @downloadNeedsNet.
  ///
  /// In en, this message translates to:
  /// **'Needs internet or a Resilience Node nearby.'**
  String get downloadNeedsNet;

  /// No description provided for @preparednessNotice.
  ///
  /// In en, this message translates to:
  /// **'New offline package for {region}: {size} MB'**
  String preparednessNotice(String region, int size);

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @orgsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trusted organizations'**
  String get orgsTitle;

  /// No description provided for @certifiedBy.
  ///
  /// In en, this message translates to:
  /// **'Certified by {name}'**
  String certifiedBy(String name);

  /// No description provided for @rootOfTrust.
  ///
  /// In en, this message translates to:
  /// **'Root of trust'**
  String get rootOfTrust;

  /// No description provided for @revocationsChecked.
  ///
  /// In en, this message translates to:
  /// **'Certificates and revocations checked {time}. Offline, this is the newest list this phone has.'**
  String revocationsChecked(String time);

  /// No description provided for @tabPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get tabPeople;

  /// No description provided for @tabOrganizations.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get tabOrganizations;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @myQr.
  ///
  /// In en, this message translates to:
  /// **'My QR'**
  String get myQr;

  /// No description provided for @moreWaysToAdd.
  ///
  /// In en, this message translates to:
  /// **'More ways to add'**
  String get moreWaysToAdd;

  /// No description provided for @addByUsername.
  ///
  /// In en, this message translates to:
  /// **'Add by username'**
  String get addByUsername;

  /// No description provided for @addByPhone.
  ///
  /// In en, this message translates to:
  /// **'Add by phone number'**
  String get addByPhone;

  /// No description provided for @needsInternetToFind.
  ///
  /// In en, this message translates to:
  /// **'Needs internet. Ask them to show their QR code instead.'**
  String get needsInternetToFind;

  /// No description provided for @metInPerson.
  ///
  /// In en, this message translates to:
  /// **'Met in person'**
  String get metInPerson;

  /// No description provided for @addedByUsername.
  ///
  /// In en, this message translates to:
  /// **'Added by username'**
  String get addedByUsername;

  /// No description provided for @addedByPhone.
  ///
  /// In en, this message translates to:
  /// **'Added by phone number'**
  String get addedByPhone;

  /// No description provided for @myQrTitle.
  ///
  /// In en, this message translates to:
  /// **'My Resilience ID'**
  String get myQrTitle;

  /// No description provided for @myQrHint.
  ///
  /// In en, this message translates to:
  /// **'Show this to someone you meet. It shares your public key, never your phone number.'**
  String get myQrHint;

  /// No description provided for @resilienceId.
  ///
  /// In en, this message translates to:
  /// **'Resilience ID'**
  String get resilienceId;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code.'**
  String get scanHint;

  /// No description provided for @scanUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available here. Type it in instead.'**
  String get scanUnavailable;

  /// No description provided for @typeIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Their Resilience ID'**
  String get typeIdLabel;

  /// No description provided for @typeIdHint.
  ///
  /// In en, this message translates to:
  /// **'16 letters and numbers'**
  String get typeIdHint;

  /// No description provided for @theirName.
  ///
  /// In en, this message translates to:
  /// **'Their name'**
  String get theirName;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @contactAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String contactAdded(String name);

  /// No description provided for @contactRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String contactRemoved(String name);

  /// No description provided for @invalidId.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a Resilience ID.'**
  String get invalidId;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Nobody found with that.'**
  String get notFound;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @messageAction.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageAction;

  /// No description provided for @removeContact.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeContact;

  /// No description provided for @noContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet. Scan someone\'s QR code to add them.'**
  String get noContacts;

  /// No description provided for @tabDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get tabDirect;

  /// No description provided for @tabCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get tabCommunity;

  /// No description provided for @tabMission.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get tabMission;

  /// No description provided for @channelPublic.
  ///
  /// In en, this message translates to:
  /// **'Public. Anyone can read it.'**
  String get channelPublic;

  /// No description provided for @channelCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community members'**
  String get channelCommunity;

  /// No description provided for @channelRestricted.
  ///
  /// In en, this message translates to:
  /// **'Staff only, encrypted'**
  String get channelRestricted;

  /// No description provided for @channelMission.
  ///
  /// In en, this message translates to:
  /// **'Mission team only'**
  String get channelMission;

  /// No description provided for @channelDirect.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get channelDirect;

  /// No description provided for @readOnlyChannel.
  ///
  /// In en, this message translates to:
  /// **'Only verified organizations post here.'**
  String get readOnlyChannel;

  /// No description provided for @sendsOver.
  ///
  /// In en, this message translates to:
  /// **'Sends over: {route}'**
  String sendsOver(String route);

  /// No description provided for @routeInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get routeInternet;

  /// No description provided for @routeLocal.
  ///
  /// In en, this message translates to:
  /// **'Resilience node'**
  String get routeLocal;

  /// No description provided for @routeMesh.
  ///
  /// In en, this message translates to:
  /// **'LoRa mesh'**
  String get routeMesh;

  /// No description provided for @routeQueued.
  ///
  /// In en, this message translates to:
  /// **'Waits on this phone until a route appears'**
  String get routeQueued;

  /// No description provided for @deliveryQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get deliveryQueued;

  /// No description provided for @deliveryPropagating.
  ///
  /// In en, this message translates to:
  /// **'On its way'**
  String get deliveryPropagating;

  /// No description provided for @deliveryDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveryDelivered;

  /// No description provided for @deliveryRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get deliveryRead;

  /// No description provided for @noChannels.
  ///
  /// In en, this message translates to:
  /// **'No conversations here yet'**
  String get noChannels;

  /// No description provided for @deliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get deliveries;

  /// No description provided for @deliveriesSub.
  ///
  /// In en, this message translates to:
  /// **'Missions you can carry'**
  String get deliveriesSub;

  /// No description provided for @tabAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get tabAvailable;

  /// No description provided for @tabAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get tabAssigned;

  /// No description provided for @tabInTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get tabInTransit;

  /// No description provided for @tabHandoff.
  ///
  /// In en, this message translates to:
  /// **'Handoff'**
  String get tabHandoff;

  /// No description provided for @tabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tabCompleted;

  /// No description provided for @missionTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission {id}'**
  String missionTitle(String id);

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get priorityHigh;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal priority'**
  String get priorityNormal;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low priority'**
  String get priorityLow;

  /// No description provided for @pickupLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickupLabel;

  /// No description provided for @destinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destinationLabel;

  /// No description provided for @carrierLabel.
  ///
  /// In en, this message translates to:
  /// **'Carrier'**
  String get carrierLabel;

  /// No description provided for @packageLabel.
  ///
  /// In en, this message translates to:
  /// **'Package {id}'**
  String packageLabel(String id);

  /// No description provided for @exactHidden.
  ///
  /// In en, this message translates to:
  /// **'Exact address shown to the carrier only'**
  String get exactHidden;

  /// No description provided for @acceptMission.
  ///
  /// In en, this message translates to:
  /// **'Accept mission'**
  String get acceptMission;

  /// No description provided for @missionAccepted.
  ///
  /// In en, this message translates to:
  /// **'Mission accepted. You can now see the exact addresses.'**
  String get missionAccepted;

  /// No description provided for @missionReleased.
  ///
  /// In en, this message translates to:
  /// **'Mission given back'**
  String get missionReleased;

  /// No description provided for @confirmPickup.
  ///
  /// In en, this message translates to:
  /// **'Confirm pickup'**
  String get confirmPickup;

  /// No description provided for @pickedUp.
  ///
  /// In en, this message translates to:
  /// **'Pickup confirmed and signed'**
  String get pickedUp;

  /// No description provided for @confirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get confirmDelivery;

  /// No description provided for @deliveredToast.
  ///
  /// In en, this message translates to:
  /// **'Delivery confirmed and signed'**
  String get deliveredToast;

  /// No description provided for @handOff.
  ///
  /// In en, this message translates to:
  /// **'Hand off'**
  String get handOff;

  /// No description provided for @handoffWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the next driver to scan the package code'**
  String get handoffWaiting;

  /// No description provided for @handoffConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Handoff confirmed: {name} has package {id}'**
  String handoffConfirmed(String name, String id);

  /// No description provided for @packageCode.
  ///
  /// In en, this message translates to:
  /// **'Package code'**
  String get packageCode;

  /// No description provided for @packageQrHint.
  ///
  /// In en, this message translates to:
  /// **'The other person scans this. It holds the package number and a signature, nothing private.'**
  String get packageQrHint;

  /// No description provided for @scanPackage.
  ///
  /// In en, this message translates to:
  /// **'Scan the package code'**
  String get scanPackage;

  /// No description provided for @enterPackageId.
  ///
  /// In en, this message translates to:
  /// **'Package number'**
  String get enterPackageId;

  /// No description provided for @wrongPackage.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t package {id}.'**
  String wrongPackage(String id);

  /// No description provided for @mStageAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get mStageAvailable;

  /// No description provided for @mStageAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned to you'**
  String get mStageAssigned;

  /// No description provided for @mStageInTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get mStageInTransit;

  /// No description provided for @mStageHandoff.
  ///
  /// In en, this message translates to:
  /// **'Awaiting handoff'**
  String get mStageHandoff;

  /// No description provided for @mStageDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get mStageDelivered;

  /// No description provided for @handedOffTo.
  ///
  /// In en, this message translates to:
  /// **'Handed off to {name}'**
  String handedOffTo(String name);

  /// No description provided for @noMissions.
  ///
  /// In en, this message translates to:
  /// **'Nothing here right now'**
  String get noMissions;

  /// No description provided for @deliveriesHint.
  ///
  /// In en, this message translates to:
  /// **'Offer transportation to see missions near you.'**
  String get deliveriesHint;

  /// No description provided for @sectionActivity.
  ///
  /// In en, this message translates to:
  /// **'Your activity'**
  String get sectionActivity;

  /// No description provided for @sectionNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network and data'**
  String get sectionNetwork;

  /// No description provided for @sectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sectionSettings;

  /// No description provided for @sectionManage.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get sectionManage;

  /// No description provided for @myRequests.
  ///
  /// In en, this message translates to:
  /// **'My requests'**
  String get myRequests;

  /// No description provided for @openCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None open} =1{1 open} other{{count} open}}'**
  String openCount(int count);

  /// No description provided for @mySupplies.
  ///
  /// In en, this message translates to:
  /// **'My supplies'**
  String get mySupplies;

  /// No description provided for @notOffering.
  ///
  /// In en, this message translates to:
  /// **'Not offering anything'**
  String get notOffering;

  /// No description provided for @orgCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 organization} other{{count} organizations}}'**
  String orgCount(int count);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed history'**
  String get historyTitle;

  /// No description provided for @historyHint.
  ///
  /// In en, this message translates to:
  /// **'Each step is signed on the phone that made it.'**
  String get historyHint;

  /// No description provided for @signedBy.
  ///
  /// In en, this message translates to:
  /// **'Signed by {id}'**
  String signedBy(String id);

  /// No description provided for @evHelpRequested.
  ///
  /// In en, this message translates to:
  /// **'Help requested'**
  String get evHelpRequested;

  /// No description provided for @evHelpCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get evHelpCancelled;

  /// No description provided for @evHelpAccepted.
  ///
  /// In en, this message translates to:
  /// **'Helper accepted'**
  String get evHelpAccepted;

  /// No description provided for @evHelpReleased.
  ///
  /// In en, this message translates to:
  /// **'Helper stepped back'**
  String get evHelpReleased;

  /// No description provided for @evHelpOffered.
  ///
  /// In en, this message translates to:
  /// **'Offer published'**
  String get evHelpOffered;

  /// No description provided for @evOfferWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Offer withdrawn'**
  String get evOfferWithdrawn;

  /// No description provided for @evResourceCreated.
  ///
  /// In en, this message translates to:
  /// **'Resource added'**
  String get evResourceCreated;

  /// No description provided for @evResourceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Resource removed'**
  String get evResourceRemoved;

  /// No description provided for @evResourceConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get evResourceConfirmed;

  /// No description provided for @evResourceDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get evResourceDisputed;

  /// No description provided for @evResourceUseful.
  ///
  /// In en, this message translates to:
  /// **'Marked useful'**
  String get evResourceUseful;

  /// No description provided for @evVoteWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Report withdrawn'**
  String get evVoteWithdrawn;

  /// No description provided for @evContactAdded.
  ///
  /// In en, this message translates to:
  /// **'Contact added'**
  String get evContactAdded;

  /// No description provided for @evContactRemoved.
  ///
  /// In en, this message translates to:
  /// **'Contact removed'**
  String get evContactRemoved;

  /// No description provided for @evMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get evMessageSent;

  /// No description provided for @evMissionAccepted.
  ///
  /// In en, this message translates to:
  /// **'Mission accepted'**
  String get evMissionAccepted;

  /// No description provided for @evMissionReleased.
  ///
  /// In en, this message translates to:
  /// **'Mission given back'**
  String get evMissionReleased;

  /// No description provided for @evPackagePickedUp.
  ///
  /// In en, this message translates to:
  /// **'Package picked up'**
  String get evPackagePickedUp;

  /// No description provided for @evPackageTransferred.
  ///
  /// In en, this message translates to:
  /// **'Package handed off'**
  String get evPackageTransferred;

  /// No description provided for @evDeliveryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Delivery completed'**
  String get evDeliveryCompleted;

  /// No description provided for @stageSavedTheirs.
  ///
  /// In en, this message translates to:
  /// **'Saved on their phone'**
  String get stageSavedTheirs;

  /// No description provided for @stageSavedTheirsSub.
  ///
  /// In en, this message translates to:
  /// **'Kept there until a radio was in range'**
  String get stageSavedTheirsSub;

  /// No description provided for @callEmergency.
  ///
  /// In en, this message translates to:
  /// **'Call 911'**
  String get callEmergency;

  /// No description provided for @callEmergencySub.
  ///
  /// In en, this message translates to:
  /// **'If no one on the mesh can reach you in time'**
  String get callEmergencySub;

  /// No description provided for @cannotCall.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t make phone calls'**
  String get cannotCall;

  /// No description provided for @translateMessage.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translateMessage;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get showOriginal;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation needs an internet connection. Showing the original.'**
  String get translationFailed;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyText;

  /// No description provided for @copiedToast.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedToast;
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
      <String>['en', 'es', 'fil', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fil':
      return AppLocalizationsFil();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
