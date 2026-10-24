// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tagalog (`tl`).
class AppLocalizationsTl extends AppLocalizations {
  AppLocalizationsTl([String locale = 'tl']) : super(locale);

  @override
  String get appTitle => 'Mesh';

  @override
  String get navMap => 'Mapa';

  @override
  String get navMessages => 'Mensahe';

  @override
  String get navMore => 'Iba pa';

  @override
  String get helpButton => 'Tulong';

  @override
  String get helpButtonSemantics => 'Humingi ng tulong';

  @override
  String get helpButtonHint =>
      'I-tap para sa mga pagpipilian. Pindutin nang 2 segundo para magpadala ng SOS.';

  @override
  String get helpMenuTitle => 'Ano ang gusto mong gawin?';

  @override
  String get needHelp => 'Kailangan ko ng tulong';

  @override
  String get needHelpSub => 'Sabihin sa mga malapit kung ano ang kailangan mo';

  @override
  String get canHelp => 'Kaya kong tumulong';

  @override
  String get canHelpSub => 'Ipaalam sa mga malapit kung ano ang maibibigay mo';

  @override
  String get sosTip =>
      'Nasa panganib? Pindutin nang matagal ang pulang Tulong button para agad magpadala ng SOS.';

  @override
  String get holdForSos => 'Pindutin nang matagal para sa SOS';

  @override
  String get holdForSosSub => 'Agad ipapadala ang iyong lokasyon';

  @override
  String get keepHolding => 'Patuloy na pindutin para maipadala ang SOS';

  @override
  String get sosSent => 'Naipadala ang SOS kasama ang iyong lokasyon';

  @override
  String get undo => 'I-undo';

  @override
  String get redo => 'Ulitin';

  @override
  String get dismiss => 'Isara';

  @override
  String get next => 'Susunod';

  @override
  String get close => 'Isara';

  @override
  String get edit => 'Baguhin';

  @override
  String get view => 'Tingnan';

  @override
  String get send => 'Ipadala';

  @override
  String radiosNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count radyo sa malapit',
      one: '1 radyo sa malapit',
      zero: 'Walang radyo sa malapit',
    );
    return '$_temp0';
  }

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get layers => 'Mga layer';

  @override
  String get layerRequests => 'Mga hiling ng tulong';

  @override
  String get layerRadios => 'Mga radyo at abot ng signal';

  @override
  String get myLocation => 'Ipakita ang lokasyon ko';

  @override
  String get language => 'Wika';

  @override
  String get nothingNearby => 'Wala pang malapit';

  @override
  String distanceMeters(int meters) {
    return '$meters m ang layo';
  }

  @override
  String distanceKm(String km) {
    return '$km km ang layo';
  }

  @override
  String get howItTravels => 'Paano naipapadala ang iyong hiling';

  @override
  String get travelPhone => 'Ang teleponong ito';

  @override
  String get travelPhoneSub => 'Sine-save muna ang lahat, kahit walang signal';

  @override
  String get travelMesh => 'Network ng radyo';

  @override
  String get travelMeshSub => 'Ipinapasa mula radyo hanggang radyo';

  @override
  String get travelCloud => 'AWS';

  @override
  String get travelCloudOnline => 'Sinusuri ito at nagtatabi ng kopya';

  @override
  String get travelCloudOffline =>
      'Hindi maabot. Naghihintay ang hiling mo sa network.';

  @override
  String get travelHelpers => 'Mga tumutulong';

  @override
  String get travelHelpersSub => 'Nakikita ang hiling mo at sumasagot';

  @override
  String get showOnMap => 'Ipakita sa mapa';

  @override
  String get openDetails => 'Buksan ang detalye';

  @override
  String get kindMedical => 'Medikal na tulong';

  @override
  String get kindMedicalSub => 'Sugatan, may sakit o naipit';

  @override
  String get kindWater => 'Tubig';

  @override
  String get kindWaterSub => 'Malinis na inuming tubig';

  @override
  String get kindShelter => 'Matutuluyan';

  @override
  String get kindShelterSub => 'Isang ligtas na lugar';

  @override
  String get kindPower => 'Kuryente';

  @override
  String get kindPowerSub => 'Mag-charge ng telepono o medikal na gamit';

  @override
  String get kindOther => 'Iba pa';

  @override
  String get kindOtherSub => 'Ilarawan ito sa susunod na hakbang';

  @override
  String get kindSos => 'SOS';

  @override
  String get urgencyNow => 'Ngayon na';

  @override
  String get urgencyNowSub => 'Nanganganib ang buhay o kaligtasan';

  @override
  String get urgencySoon => 'Sa loob ng ilang oras';

  @override
  String get urgencySoonSub => 'Lumalala';

  @override
  String get urgencyLater => 'Makakapaghintay';

  @override
  String get urgencyLaterSub => 'Maayos sa ngayon';

  @override
  String get stageSaved => 'Naka-save sa teleponong ito';

  @override
  String get stageSavedSub => 'Ipapadala kapag may radyo nang abot';

  @override
  String get stageMesh => 'Naipadala sa network';

  @override
  String stageMeshSub(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'Dumaan sa $hops radyo',
      one: 'Dumaan sa 1 radyo',
      zero: 'Diretsong umabot sa radyo',
    );
    return '$_temp0';
  }

  @override
  String get stageVerified => 'Nasuri ng server';

  @override
  String get stageVerifiedSub => 'Sinuri ng AWS ang hiling at nagtabi ng kopya';

  @override
  String get stageAssigned => 'May tutulong na';

  @override
  String stageAssignedSub(String name) {
    return 'Tinanggap ni $name ang hiling';
  }

  @override
  String get stageOnTheWay => 'Papunta na ang tulong';

  @override
  String stageOnTheWaySub(String name) {
    return 'Papunta na roon si $name';
  }

  @override
  String get stageResolved => 'Tapos na';

  @override
  String get stageResolvedSub => 'Minarkahang tapos';

  @override
  String get stageWaiting => 'Naghihintay';

  @override
  String stepOf(int step, int total) {
    return 'Hakbang $step sa $total';
  }

  @override
  String get helpStep1Title => 'Ano ang kailangan mo?';

  @override
  String get helpStep2Title => 'May iba pa ba?';

  @override
  String get urgencyQuestion => 'Gaano kabilis kailangan?';

  @override
  String get peopleQuestion => 'Ilang tao ang nangangailangan ng tulong?';

  @override
  String peopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tao',
      one: '1 tao',
    );
    return '$_temp0';
  }

  @override
  String get fewerPeople => 'Bawasan ang tao';

  @override
  String get morePeople => 'Dagdagan ang tao';

  @override
  String get locationTitle => 'Lokasyon';

  @override
  String locationAuto(int meters) {
    return 'Awtomatikong ibinabahagi, tumpak hanggang $meters m';
  }

  @override
  String get locationMissing =>
      'Hindi makuha ang lokasyon mo. Ilarawan kung nasaan ka.';

  @override
  String get locationNoteLabel => 'Ilarawan kung nasaan ka';

  @override
  String get locationNoteHint =>
      'Halimbawa: ikalawang palapag, malapit sa hagdan';

  @override
  String get noteLabel => 'May iba pa ba? (opsyonal)';

  @override
  String get sendRequest => 'Ipadala ang hiling';

  @override
  String get requestSent => 'Naipadala ang hiling';

  @override
  String get requestDiscarded => 'Itinapon ang hiling';

  @override
  String get requestCancelled => 'Kinansela ang hiling';

  @override
  String get requestRestored => 'Naibalik ang hiling';

  @override
  String get cancelRequest => 'Kanselahin ang hiling';

  @override
  String get problemMissingKind => 'Piliin kung ano ang kailangan mo.';

  @override
  String problemPeople(int max) {
    return 'Maglagay ng 1 hanggang $max tao.';
  }

  @override
  String problemNoteTooLong(int max) {
    return 'Dapat mas maikli sa $max na character ang tala.';
  }

  @override
  String get problemLocation =>
      'Ilarawan kung nasaan ka, dahil hindi makuha ang lokasyon mo.';

  @override
  String get offerStep1Title => 'Mga maibibigay ko';

  @override
  String get offerStep2Title => 'Ilang detalye';

  @override
  String get offerNoteLabel => 'Tala para sa mga malapit (opsyonal)';

  @override
  String get offerNoteHint => 'Halimbawa: may kotse ako na kasya ang 4';

  @override
  String get startOffering => 'Magsimulang tumulong';

  @override
  String get offeringStarted => 'Nag-aalok ka ng tulong';

  @override
  String offeringList(String list) {
    return 'Inaalok mo: $list';
  }

  @override
  String get stopOffering => 'Itigil';

  @override
  String get offerStopped => 'Tumigil ka sa pag-aalok ng tulong';

  @override
  String get offerPrompt => 'Kaya mong tumulong? Ipaalam sa mga malapit.';

  @override
  String get tabNearMe => 'Malapit sa akin';

  @override
  String get tabMine => 'Akin';

  @override
  String get iCanHelp => 'Tutulong ako';

  @override
  String get youAreHelping => 'Tumutulong ka';

  @override
  String get stopHelping => 'Itigil ang pagtulong';

  @override
  String get acceptedToast => 'Tumutulong ka. Alam nilang papunta ka na.';

  @override
  String get releasedToast => 'Tumigil ka sa pagtulong';

  @override
  String get noNearby => 'Walang bukas na hiling sa malapit';

  @override
  String get noMine => 'Hindi ka pa humihingi ng tulong';

  @override
  String fromName(String name) {
    return 'Mula kay $name';
  }

  @override
  String get justNow => 'ngayon lang';

  @override
  String minutesAgo(int n) {
    return '$n min ang nakalipas';
  }

  @override
  String hoursAgo(int n) {
    return '$n oras ang nakalipas';
  }

  @override
  String daysAgo(int n) {
    return '$n araw ang nakalipas';
  }

  @override
  String get progressTitle => 'Progreso';

  @override
  String get detailsTitle => 'Detalye';

  @override
  String get showToResponder => 'Ipakita sa rescuer';

  @override
  String get requestNotFound => 'Wala na ang hiling na ito.';

  @override
  String get cardNeedHelp => 'Kailangan ko ng tulong';

  @override
  String get cardSwipeHint =>
      'Mag-swipe pakaliwa o pakanan para palitan ang wika';

  @override
  String get cardTheirWords => 'Sarili nilang salita, hindi isinalin:';

  @override
  String get urgencyTitle => 'Pagkaapurahan';

  @override
  String get peopleTitle => 'Mga tao';

  @override
  String get noMessages => 'Wala pang mensahe';

  @override
  String get messageHint => 'Mensahe';

  @override
  String get languageSystem => 'Gamitin ang setting ng telepono';

  @override
  String get display => 'Display at accessibility';

  @override
  String displaySub(int percent) {
    return 'Laki ng text $percent%';
  }

  @override
  String get theme => 'Tema';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Maliwanag';

  @override
  String get themeDark => 'Madilim';

  @override
  String get textSize => 'Laki ng text';

  @override
  String get highContrast => 'Mataas na contrast';

  @override
  String get highContrastSub => 'Mas matingkad na kulay at gilid';

  @override
  String get textPreview => 'Ganito ang magiging hitsura ng text.';

  @override
  String get privacy => 'Privacy at seguridad';

  @override
  String get phoneLockOn => 'Naka-on ang lock';

  @override
  String get phoneLockOff => 'Naka-off ang lock';

  @override
  String get phoneLock => 'I-lock gamit ang Face ID o fingerprint';

  @override
  String get phoneLockSub => 'Gagamitin ang passcode ng telepono kung pumalya';

  @override
  String get phoneLockWeb => 'Available sa iOS at Android app';

  @override
  String get phoneLockUnavailable =>
      'Mag-set up muna ng passcode o Face ID sa teleponong ito';

  @override
  String get lockNow => 'I-lock ngayon';

  @override
  String get lockNowSub => 'Gumagana pa rin ang SOS kahit naka-lock';

  @override
  String get clearTemp => 'Burahin ang pansamantalang data';

  @override
  String get clearTempSub =>
      'Lumang mensahe at tapos nang hiling. May kopya pa rin ang AWS.';

  @override
  String cleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nabura ang $count item',
      one: 'Nabura ang 1 item',
      zero: 'Walang buburahin',
    );
    return '$_temp0';
  }

  @override
  String get eraseAll => 'Burahin ang lahat sa teleponong ito';

  @override
  String get eraseAllSub => 'Pindutin nang 3 segundo. Hindi na ito maibabalik.';

  @override
  String get erased => 'Nabura ang lahat sa teleponong ito';

  @override
  String get network => 'Network ng radyo';

  @override
  String get manage => 'Pamahalaan ang network';

  @override
  String get manageSub => 'I-on o i-off ang mga radyo para sa lahat';

  @override
  String get admin => 'Mga user at tungkulin';

  @override
  String get adminSub => 'Baguhin kung sino ang puwedeng mamahala sa network';

  @override
  String get account => 'Account';

  @override
  String signedInAs(String name) {
    return 'Naka-sign in bilang $name';
  }

  @override
  String get guestMode => 'Ginagamit ang Mesh bilang bisita';

  @override
  String get signIn => 'Mag-sign in';

  @override
  String get signInSub =>
      'Opsyonal. Nagsa-sign in ang mga tumutulong at tagapamahala.';

  @override
  String get signOut => 'Mag-sign out';

  @override
  String get nameLabel => 'Pangalan';

  @override
  String get roleLabel => 'Tungkulin';

  @override
  String get roleClient => 'Miyembro';

  @override
  String get roleManager => 'Tagapamahala';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get demoSignIn =>
      'Demo na sign-in. Sa tunay na app, ang server ang magbibigay ng tungkulin mo.';

  @override
  String get nodeOnline => 'Online';

  @override
  String get nodeOffline => 'Offline';

  @override
  String get hopsDirect => 'Diretso';

  @override
  String hopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hop',
      one: '1 hop',
    );
    return '$_temp0';
  }

  @override
  String get externalPower => 'Panlabas na kuryente';

  @override
  String get noNodes => 'Wala pang naririnig na radyo';

  @override
  String get nodeId => 'ID';

  @override
  String get lastHeard => 'Huling narinig';

  @override
  String get battery => 'Baterya';

  @override
  String get signalStrength => 'Lakas ng signal';

  @override
  String get signalNoise => 'Signal laban sa ingay';

  @override
  String get hopsTitle => 'Mga hop';

  @override
  String get manageHint =>
      'Ang mga radyong ino-off mo ay hindi makikita ng mga miyembro.';

  @override
  String get loadFailed => 'Hindi ma-load ang pahinang ito.';

  @override
  String get lockedTitle => 'Naka-lock ang Mesh';

  @override
  String get lockedSub =>
      'I-unlock para makita ang iyong mga hiling at mensahe.';

  @override
  String get unlock => 'I-unlock';

  @override
  String get unlockReason => 'I-unlock ang Mesh';

  @override
  String get unlockWebNote =>
      'Walang Face ID sa web preview, kaya bubuksan agad ng I-unlock ang app.';

  @override
  String get unlockFailed =>
      'Hindi ma-unlock. Subukang muli o gamitin ang passcode.';

  @override
  String alertNearby(String kind) {
    return 'Bagong hiling sa malapit: $kind';
  }

  @override
  String alertHelper(String name) {
    return 'Tinanggap ni $name ang hiling mo';
  }

  @override
  String get navContacts => 'Contacts';

  @override
  String get kindFood => 'Pagkain';

  @override
  String get kindFoodSub => 'Pagkain o gatas ng sanggol';

  @override
  String get kindMedicine => 'Gamot';

  @override
  String get kindMedicineSub => 'Reseta, insulin, inhaler';

  @override
  String get kindTransportation => 'Sasakyan';

  @override
  String get kindTransportationSub => 'Masasakyan, o tulong sa paglipat ng tao';

  @override
  String get kindCommunication => 'Komunikasyon';

  @override
  String get kindCommunicationSub => 'Makontak ang pamilya o humingi ng tulong';

  @override
  String get noteExampleHint =>
      'Halimbawa: kailangan ng malamig na lugar para sa insulin ng isang tao';

  @override
  String get structuredFirst =>
      'Ipinapadala muna ang pinili mo, kaya nakakarating kahit mahina ang signal. Kasunod ang tala kapag may puwang.';

  @override
  String suggestion(String kind) {
    return 'Mukhang: $kind';
  }

  @override
  String get useSuggestion => 'Gamitin ito';

  @override
  String get amountQuestion => 'Gaano karami ang mayroon ka?';

  @override
  String get amountPlenty => 'Marami';

  @override
  String get amountSome => 'Ilan';

  @override
  String get amountLow => 'Kaunti';

  @override
  String get availabilityQuestion => 'Kailan ito available?';

  @override
  String get availabilityNow => 'Ngayon';

  @override
  String get availabilityToday => 'Ngayong araw';

  @override
  String get availabilityCustom => 'Ibang oras';

  @override
  String get availabilityNoteLabel => 'Kailan?';

  @override
  String get availabilityNoteHint => 'Halimbawa: pagkatapos ng 6 pm';

  @override
  String get transportQuestion => 'Paano ka makakapaghatid?';

  @override
  String get transportWalking => 'Naglalakad';

  @override
  String get transportBicycle => 'Bisikleta';

  @override
  String get transportCar => 'Kotse';

  @override
  String get transportTruck => 'Trak';

  @override
  String get transportVan => 'Van';

  @override
  String get capacityQuestion => 'Gaano karami ang kaya mong dalhin?';

  @override
  String get capacitySmall => 'Kaunti';

  @override
  String get capacityMedium => 'Katamtaman';

  @override
  String get capacityLarge => 'Marami';

  @override
  String get supplyWater => 'Tubig';

  @override
  String get supplyFood => 'Pagkain';

  @override
  String get supplyBlankets => 'Kumot';

  @override
  String get supplyBatteries => 'Baterya';

  @override
  String get supplyCharging => 'Pag-charge';

  @override
  String get supplyMedicine => 'Gamot';

  @override
  String get supplyTransportation => 'Sasakyan';

  @override
  String get supplyShelter => 'Matutuluyan';

  @override
  String get supplyTools => 'Kagamitan';

  @override
  String get supplyOther => 'Iba pa';

  @override
  String get problemSupplies => 'Pumili ng kahit isa.';

  @override
  String get problemTransport => 'Piliin kung paano ka makakapaghatid.';

  @override
  String get resHospital => 'Ospital';

  @override
  String get resPharmacy => 'Botika';

  @override
  String get resPolice => 'Pulis';

  @override
  String get resFire => 'Istasyon ng bumbero';

  @override
  String get resWater => 'Tubig';

  @override
  String get resFood => 'Pagkain';

  @override
  String get resShelter => 'Matutuluyan';

  @override
  String get resCharging => 'Charging';

  @override
  String get resTransportation => 'Sasakyan';

  @override
  String get resRoadProblem => 'Problema sa kalsada';

  @override
  String get verifiedOrg => 'Beripikadong organisasyon';

  @override
  String get communityResource => 'Mula sa komunidad';

  @override
  String get unconfirmed => 'Hindi pa kumpirmado';

  @override
  String get confidenceHigh => 'Mataas ang tiwala';

  @override
  String get confidenceMedium => 'Katamtaman ang tiwala';

  @override
  String get confidenceLow => 'Mababa ang tiwala';

  @override
  String get trustSource => 'Pinagmulan';

  @override
  String get trustCorroboration => 'Mga kumpirmasyon';

  @override
  String get trustFreshness => 'Kung gaano kabago';

  @override
  String confirmationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kumpirmasyon',
      one: '1 kumpirmasyon',
      zero: 'Wala pang kumpirmasyon',
    );
    return '$_temp0';
  }

  @override
  String disputesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tutol',
      one: '1 tutol',
      zero: 'walang tutol',
    );
    return '$_temp0';
  }

  @override
  String get oneReport => '1 ulat pa lang';

  @override
  String officialUpdate(String time) {
    return 'Opisyal na update $time';
  }

  @override
  String lastObservation(String time) {
    return 'Pinakahuling nakita $time';
  }

  @override
  String staleWarning(String time) {
    return 'Huling nakita $time. Baka luma na.';
  }

  @override
  String get voteUseful => 'Nakatulong';

  @override
  String get voteConfirm => 'Kumpirmahin';

  @override
  String get voteConfirmSub => 'Nakita ko mismo';

  @override
  String get voteDispute => 'Tumutol';

  @override
  String get voteDisputeSub => 'Iba ang nakita ko';

  @override
  String get voted => 'Salamat. Pirmado at naibahagi ang ulat mo.';

  @override
  String get voteWithdrawnToast => 'Binawi ang ulat';

  @override
  String get approxLocation => 'Tinatayang lokasyon';

  @override
  String get inventoryTitle => 'Supply';

  @override
  String officialStock(int count, String time) {
    return 'Opisyal na bilang: $count noong $time';
  }

  @override
  String reservedFor(int count, String id) {
    return '$count nakareserba para sa Misyon $id';
  }

  @override
  String remainingCount(int count) {
    return '$count natitira';
  }

  @override
  String get communityReports => 'Mga ulat ng komunidad';

  @override
  String observationAt(String text, String time) {
    return '$text noong $time';
  }

  @override
  String get addHereTitle => 'Magdagdag dito';

  @override
  String get addHereHint =>
      'Pindutin nang matagal ang mapa para magdagdag ng tubig, pagkain, matutuluyan o problemang nakita mo.';

  @override
  String get addNoteHint => 'Magdagdag ng maikling tala (opsyonal)';

  @override
  String get addResource => 'Idagdag';

  @override
  String get resourceAdded =>
      'Naidagdag. Tinatayang lokasyon ang nakikita ng iba.';

  @override
  String get resourceRemoved => 'Inalis';

  @override
  String get addedByYou => 'Idinagdag mo';

  @override
  String get statusOffline => 'Offline';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusReady => 'Handa';

  @override
  String lastSyncAgo(String time) {
    return 'Huling sync $time';
  }

  @override
  String alertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alerto',
      one: '1 alerto',
    );
    return '$_temp0';
  }

  @override
  String get alertsTitle => 'Mga alerto';

  @override
  String get layerFacilities => 'Ospital, botika, pulis at bumbero';

  @override
  String get layerLive => 'Tubig, pagkain, matutuluyan at ulat';

  @override
  String get networkTitle => 'Kalagayan ng network';

  @override
  String get netInternet => 'Internet';

  @override
  String get netPeers => 'Mga teleponong malapit';

  @override
  String get netNode => 'Resilience node';

  @override
  String get netLora => 'LoRa na radyo';

  @override
  String get netLastLocal => 'Huling sync sa malapit';

  @override
  String get netLastGlobal => 'Huling sync sa cloud';

  @override
  String get netConnected => 'Nakakonekta';

  @override
  String get netNotConnected => 'Hindi nakakonekta';

  @override
  String peersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count telepono',
      one: '1 telepono',
      zero: 'Wala',
    );
    return '$_temp0';
  }

  @override
  String queuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item ang naghihintay',
      one: '1 item ang naghihintay',
      zero: 'Walang naghihintay na ipadala',
    );
    return '$_temp0';
  }

  @override
  String get demoInternet => 'Demo: kunwaring bumalik ang internet';

  @override
  String get demoInternetSub =>
      'Ipinapakita kung ano ang nagbabago kapag nag-online ang telepono';

  @override
  String get viewRadios => 'Mga radyo sa network';

  @override
  String get downloadsTitle => 'Mga download para sa offline';

  @override
  String packageTitle(String region) {
    return 'Readiness package ng $region';
  }

  @override
  String get packageContents =>
      'Offline na mapa, mga pasilidad pang-emergency, data ng ruta, mga pinagkakatiwalaang organisasyon, mga binawing sertipiko, mga gabay pang-emergency at pinakahuling kalagayan ng mga resource.';

  @override
  String packageSize(int size, int version) {
    return '$size MB, bersyon $version';
  }

  @override
  String packageUpToDate(String time) {
    return 'Napapanahon. Na-download $time';
  }

  @override
  String packageUpdate(int version) {
    return 'May update: bersyon $version';
  }

  @override
  String get downloadNow => 'I-download ngayon';

  @override
  String downloadingPercent(int percent) {
    return 'Dina-download $percent%';
  }

  @override
  String get downloadNeedsNet =>
      'Kailangan ng internet o Resilience Node sa malapit.';

  @override
  String preparednessNotice(String region, int size) {
    return 'Bagong offline package para sa $region: $size MB';
  }

  @override
  String get download => 'I-download';

  @override
  String get orgsTitle => 'Mga pinagkakatiwalaang organisasyon';

  @override
  String certifiedBy(String name) {
    return 'Sertipikado ng $name';
  }

  @override
  String get rootOfTrust => 'Ugat ng tiwala';

  @override
  String revocationsChecked(String time) {
    return 'Nasuri ang mga sertipiko at binawi $time. Kapag offline, ito ang pinakabagong listahan sa teleponong ito.';
  }

  @override
  String get tabPeople => 'Mga tao';

  @override
  String get tabOrganizations => 'Mga organisasyon';

  @override
  String get scanQr => 'I-scan ang QR';

  @override
  String get myQr => 'QR ko';

  @override
  String get moreWaysToAdd => 'Iba pang paraan';

  @override
  String get addByUsername => 'Idagdag gamit ang username';

  @override
  String get addByPhone => 'Idagdag gamit ang numero';

  @override
  String get needsInternetToFind =>
      'Kailangan ng internet. Hilingin na ipakita nila ang QR code nila.';

  @override
  String get metInPerson => 'Nakilala nang personal';

  @override
  String get addedByUsername => 'Idinagdag gamit ang username';

  @override
  String get addedByPhone => 'Idinagdag gamit ang numero';

  @override
  String get myQrTitle => 'Ang Resilience ID ko';

  @override
  String get myQrHint =>
      'Ipakita ito sa taong makikilala mo. Ibinabahagi nito ang public key mo, hindi kailanman ang numero mo.';

  @override
  String get resilienceId => 'Resilience ID';

  @override
  String get scanTitle => 'Mag-scan ng QR code';

  @override
  String get scanHint => 'Itutok ang camera sa QR code.';

  @override
  String get scanUnavailable =>
      'Hindi magagamit ang camera dito. I-type na lang ito.';

  @override
  String get typeIdLabel => 'Ang Resilience ID nila';

  @override
  String get typeIdHint => '16 na letra at numero';

  @override
  String get theirName => 'Pangalan nila';

  @override
  String get addContact => 'Idagdag ang contact';

  @override
  String contactAdded(String name) {
    return 'Naidagdag si $name';
  }

  @override
  String contactRemoved(String name) {
    return 'Inalis si $name';
  }

  @override
  String get invalidId => 'Mukhang hindi iyan Resilience ID.';

  @override
  String get notFound => 'Walang nahanap.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get phoneLabel => 'Numero ng telepono';

  @override
  String get find => 'Hanapin';

  @override
  String get messageAction => 'Mensahe';

  @override
  String get removeContact => 'Alisin';

  @override
  String get noContacts =>
      'Wala pang contact. I-scan ang QR code ng isang tao para idagdag sila.';

  @override
  String get tabDirect => 'Direkta';

  @override
  String get tabCommunity => 'Komunidad';

  @override
  String get tabMission => 'Misyon';

  @override
  String get channelPublic => 'Pampubliko. Kahit sino ay makakabasa.';

  @override
  String get channelCommunity => 'Mga miyembro ng komunidad';

  @override
  String get channelRestricted => 'Para sa staff lang, naka-encrypt';

  @override
  String get channelMission => 'Para sa team ng misyon lang';

  @override
  String get channelDirect => 'Pribado';

  @override
  String get readOnlyChannel =>
      'Ang mga beripikadong organisasyon lang ang nagpo-post dito.';

  @override
  String sendsOver(String route) {
    return 'Ipinapadala sa: $route';
  }

  @override
  String get routeInternet => 'Internet';

  @override
  String get routeLocal => 'Resilience node';

  @override
  String get routeMesh => 'LoRa mesh';

  @override
  String get routeQueued => 'Naghihintay sa teleponong ito hanggang may ruta';

  @override
  String get deliveryQueued => 'Nakapila';

  @override
  String get deliveryPropagating => 'Papunta na';

  @override
  String get deliveryDelivered => 'Naihatid';

  @override
  String get deliveryRead => 'Nabasa';

  @override
  String get noChannels => 'Wala pang usapan dito';

  @override
  String get deliveries => 'Mga paghahatid';

  @override
  String get deliveriesSub => 'Mga misyong kaya mong dalhin';

  @override
  String get tabAvailable => 'Bukas';

  @override
  String get tabAssigned => 'Nakatalaga';

  @override
  String get tabInTransit => 'Dinadala';

  @override
  String get tabHandoff => 'Pagpasa';

  @override
  String get tabCompleted => 'Tapos na';

  @override
  String missionTitle(String id) {
    return 'Misyon $id';
  }

  @override
  String get priorityHigh => 'Mataas na priyoridad';

  @override
  String get priorityNormal => 'Karaniwang priyoridad';

  @override
  String get priorityLow => 'Mababang priyoridad';

  @override
  String get pickupLabel => 'Kukunin sa';

  @override
  String get destinationLabel => 'Dadalhin sa';

  @override
  String get carrierLabel => 'Magdadala';

  @override
  String packageLabel(String id) {
    return 'Package $id';
  }

  @override
  String get exactHidden => 'Ang eksaktong address ay para lang sa magdadala';

  @override
  String get acceptMission => 'Tanggapin ang misyon';

  @override
  String get missionAccepted =>
      'Tinanggap ang misyon. Nakikita mo na ang eksaktong address.';

  @override
  String get missionReleased => 'Ibinalik ang misyon';

  @override
  String get confirmPickup => 'Kumpirmahin ang pagkuha';

  @override
  String get pickedUp => 'Nakumpirma at napirmahan ang pagkuha';

  @override
  String get confirmDelivery => 'Kumpirmahin ang paghatid';

  @override
  String get deliveredToast => 'Nakumpirma at napirmahan ang paghatid';

  @override
  String get handOff => 'Ipasa';

  @override
  String get handoffWaiting =>
      'Hinihintay na i-scan ng susunod na driver ang code ng package';

  @override
  String handoffConfirmed(String name, String id) {
    return 'Nakumpirma ang pagpasa: nasa kay $name ang package $id';
  }

  @override
  String get packageCode => 'Code ng package';

  @override
  String get packageQrHint =>
      'I-scan ito ng kabilang tao. Numero ng package at pirma lang ang laman nito, walang pribado.';

  @override
  String get scanPackage => 'I-scan ang code ng package';

  @override
  String get enterPackageId => 'Numero ng package';

  @override
  String wrongPackage(String id) {
    return 'Hindi iyan ang package $id.';
  }

  @override
  String get mStageAvailable => 'Bukas';

  @override
  String get mStageAssigned => 'Nakatalaga sa iyo';

  @override
  String get mStageInTransit => 'Dinadala';

  @override
  String get mStageHandoff => 'Naghihintay ng pagpasa';

  @override
  String get mStageDelivered => 'Naihatid';

  @override
  String handedOffTo(String name) {
    return 'Ipinasa kay $name';
  }

  @override
  String get noMissions => 'Wala pa sa ngayon';

  @override
  String get deliveriesHint =>
      'Mag-alok ng sasakyan para makita ang mga misyon sa malapit.';

  @override
  String get sectionActivity => 'Mga ginawa mo';

  @override
  String get sectionNetwork => 'Network at data';

  @override
  String get sectionSettings => 'Mga setting';

  @override
  String get sectionManage => 'Pamamahala';

  @override
  String get myRequests => 'Mga hiling ko';

  @override
  String openCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bukas',
      one: '1 bukas',
      zero: 'Walang bukas',
    );
    return '$_temp0';
  }

  @override
  String get mySupplies => 'Mga inaalok ko';

  @override
  String get notOffering => 'Wala kang inaalok';

  @override
  String orgCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count organisasyon',
      one: '1 organisasyon',
    );
    return '$_temp0';
  }

  @override
  String get historyTitle => 'Pirmadong kasaysayan';

  @override
  String get historyHint =>
      'Pinipirmahan ang bawat hakbang sa teleponong gumawa nito.';

  @override
  String signedBy(String id) {
    return 'Pinirmahan ni $id';
  }

  @override
  String get evHelpRequested => 'Humingi ng tulong';

  @override
  String get evHelpCancelled => 'Kinansela ang hiling';

  @override
  String get evHelpAccepted => 'Tinanggap ng tutulong';

  @override
  String get evHelpReleased => 'Umatras ang tutulong';

  @override
  String get evHelpOffered => 'Nai-post ang alok';

  @override
  String get evOfferWithdrawn => 'Binawi ang alok';

  @override
  String get evResourceCreated => 'Idinagdag ang resource';

  @override
  String get evResourceRemoved => 'Inalis ang resource';

  @override
  String get evResourceConfirmed => 'Kinumpirma';

  @override
  String get evResourceDisputed => 'Tinutulan';

  @override
  String get evResourceUseful => 'Minarkahang nakatulong';

  @override
  String get evVoteWithdrawn => 'Binawi ang ulat';

  @override
  String get evContactAdded => 'Idinagdag ang contact';

  @override
  String get evContactRemoved => 'Inalis ang contact';

  @override
  String get evMessageSent => 'Naipadala ang mensahe';

  @override
  String get evMissionAccepted => 'Tinanggap ang misyon';

  @override
  String get evMissionReleased => 'Ibinalik ang misyon';

  @override
  String get evPackagePickedUp => 'Nakuha ang package';

  @override
  String get evPackageTransferred => 'Naipasa ang package';

  @override
  String get evDeliveryCompleted => 'Natapos ang paghatid';

  @override
  String get stageSavedTheirs => 'Naka-save sa telepono nila';

  @override
  String get stageSavedTheirsSub =>
      'Itinago roon hanggang may radyo sa malapit';

  @override
  String get mapSource => 'Mapa ng kalye mula sa Amazon Location';

  @override
  String get mapSourceNote =>
      'Kailangan ng internet. Makikita pa rin ang mga pin, radyo at hiling kapag hindi ma-load ang mapa ng kalye.';

  @override
  String get mapNotSetUp => 'Hindi pa naka-set up ang mapa ng kalye';

  @override
  String get mapOffline => 'Kailangan ng internet ang mapa ng kalye';

  @override
  String get mapLoading => 'Nilo-load ang mapa ng kalye';

  @override
  String get missionNotFound => 'Wala na ang paghahatid na ito.';

  @override
  String get resourceNotFound => 'Wala na sa mapa ang lugar na ito.';

  @override
  String get navNewMessage => 'Bagong mensahe';

  @override
  String get navChannels => 'Mga channel';

  @override
  String get navNoDirectChats =>
      'Wala ka pang direktang mamemensahe. I-scan ang QR code ng isang tao para idagdag siya.';

  @override
  String get navAddDetails => 'Magdagdag ng detalye';

  @override
  String get navAddDetailsSub => 'Isang tala, at ilang tao';

  @override
  String get navAdvanced => 'Karagdagang detalye';

  @override
  String get navRequestTakenBack => 'Binawi ang hiling';

  @override
  String get navChangeOffer => 'Baguhin ang inaalok ko';

  @override
  String get navHoldForMore => 'Pindutin nang matagal para sa iba pang aksyon';

  @override
  String navLocationTyped(String place) {
    return 'Lokasyon mo: $place';
  }

  @override
  String get sosContactsTitle => 'Mga contact sa emergency';

  @override
  String sosContactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tao',
      one: '1 tao',
      zero: 'Wala pa',
    );
    return '$_temp0';
  }

  @override
  String get sosContactsIntro =>
      'Kapag walang naabot na network ang SOS, tutulungan ka ng Mesh na i-text ang mga taong ito gamit ang messaging app ng telepono mo.';

  @override
  String get sosContactsEmpty => 'Wala ka pang contact sa emergency.';

  @override
  String get sosAddContact => 'Magdagdag ng contact sa emergency';

  @override
  String get sosEditContact => 'Baguhin ang contact sa emergency';

  @override
  String get sosContactName => 'Pangalan';

  @override
  String get sosContactPhone => 'Numero ng telepono';

  @override
  String get sosContactPhoneHint => 'Halimbawa: +1 408 555 0100';

  @override
  String get sosContactPhoneInvalid =>
      'Suriin ang numero: gumamit ng mga digit, at + bago ang country code';

  @override
  String get sosSaveContact => 'I-save';

  @override
  String sosContactSaved(String name) {
    return 'Na-save si $name';
  }

  @override
  String sosContactRemoved(String name) {
    return 'Inalis si $name';
  }

  @override
  String sosRemoveContact(String name) {
    return 'Alisin si $name';
  }

  @override
  String sosContactsFull(int count) {
    return 'Hanggang $count contact sa emergency ang puwedeng i-save.';
  }

  @override
  String get sosNoNetworkTitle => 'Walang naabot na network';

  @override
  String get sosNoNetworkBody =>
      'Naka-save sa teleponong ito ang SOS mo at ipapadala agad kapag may nahanap na network ang Mesh. I-text ang mga contact mo sa emergency o tumawag sa 911 ngayon.';

  @override
  String get sosNoNetworkBodyNoContacts =>
      'Naka-save sa teleponong ito ang SOS mo at ipapadala agad kapag may nahanap na network ang Mesh. Tumawag sa 911 ngayon kung kaya mo.';

  @override
  String sosTextContacts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I-text ang $count contact sa emergency',
      one: 'I-text ang 1 contact sa emergency',
    );
    return '$_temp0';
  }

  @override
  String get sosCall911 => 'Tumawag sa 911';

  @override
  String get sosNotNow => 'Hindi muna';

  @override
  String get sosDone => 'Tapos na';

  @override
  String get sosAddContacts => 'Magdagdag ng mga contact sa emergency';

  @override
  String get sosMessageLabel => 'Ang text mo';

  @override
  String get sosLaunchFailed =>
      'Hindi ito mabuksan ng telepono. Subukan ulit, o gamitin ang sariling app ng telepono mo.';

  @override
  String sosTextBody(String name, String location, String time) {
    return 'SOS mula kay $name. Kailangan ko ng tulong. Lokasyon: $location. Oras: $time.';
  }

  @override
  String sosTextBodyGuest(String location, String time) {
    return 'SOS. Kailangan ko ng tulong. Lokasyon: $location. Oras: $time.';
  }

  @override
  String get sosLocationUnknown => 'hindi alam';
}
