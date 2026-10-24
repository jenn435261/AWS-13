// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Mesh';

  @override
  String get navMap => 'Mapa';

  @override
  String get navMessages => 'Mensajes';

  @override
  String get navMore => 'Más';

  @override
  String get helpButton => 'Ayuda';

  @override
  String get helpButtonSemantics => 'Pedir ayuda';

  @override
  String get helpButtonHint =>
      'Toca para ver opciones. Mantén pulsado 2 segundos para enviar un SOS.';

  @override
  String get helpMenuTitle => '¿Qué quieres hacer?';

  @override
  String get needHelp => 'Necesito ayuda';

  @override
  String get needHelpSub => 'Di a quienes están cerca lo que necesitas';

  @override
  String get canHelp => 'Puedo ayudar';

  @override
  String get canHelpSub => 'Avisa a quienes están cerca lo que puedes ofrecer';

  @override
  String get sosTip =>
      '¿En peligro? Mantén pulsado el botón rojo de Ayuda para enviar un SOS al instante.';

  @override
  String get holdForSos => 'Mantén pulsado para SOS';

  @override
  String get holdForSosSub => 'Envía tu ubicación al instante';

  @override
  String get keepHolding => 'Sigue pulsando para enviar el SOS';

  @override
  String get sosSent => 'SOS enviado con tu ubicación';

  @override
  String get undo => 'Deshacer';

  @override
  String get redo => 'Rehacer';

  @override
  String get dismiss => 'Cerrar';

  @override
  String get next => 'Siguiente';

  @override
  String get close => 'Cerrar';

  @override
  String get edit => 'Editar';

  @override
  String get view => 'Ver';

  @override
  String get send => 'Enviar';

  @override
  String radiosNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count radios cerca',
      one: '1 radio cerca',
      zero: 'No hay radios cerca',
    );
    return '$_temp0';
  }

  @override
  String get online => 'En línea';

  @override
  String get offline => 'Sin conexión';

  @override
  String get layers => 'Capas';

  @override
  String get layerRequests => 'Pedidos de ayuda';

  @override
  String get layerRadios => 'Radios y cobertura';

  @override
  String get myLocation => 'Mostrar mi ubicación';

  @override
  String get language => 'Idioma';

  @override
  String get nothingNearby => 'Todavía no hay nada cerca';

  @override
  String distanceMeters(int meters) {
    return 'a $meters m';
  }

  @override
  String distanceKm(String km) {
    return 'a $km km';
  }

  @override
  String get howItTravels => 'Cómo viajan tus pedidos';

  @override
  String get travelPhone => 'Este teléfono';

  @override
  String get travelPhoneSub => 'Guarda todo primero, incluso sin señal';

  @override
  String get travelMesh => 'Red de radios';

  @override
  String get travelMeshSub => 'Lo pasa de radio en radio';

  @override
  String get travelCloud => 'AWS';

  @override
  String get travelCloudOnline => 'Lo revisa y guarda una copia';

  @override
  String get travelCloudOffline =>
      'Fuera de alcance. Tu pedido espera en la red.';

  @override
  String get travelHelpers => 'Ayudantes';

  @override
  String get travelHelpersSub => 'Ven tu pedido y responden';

  @override
  String get showOnMap => 'Ver en el mapa';

  @override
  String get openDetails => 'Ver detalles';

  @override
  String get kindMedical => 'Ayuda médica';

  @override
  String get kindMedicalSub => 'Herido, enfermo o atrapado';

  @override
  String get kindWater => 'Agua';

  @override
  String get kindWaterSub => 'Agua potable';

  @override
  String get kindShelter => 'Refugio';

  @override
  String get kindShelterSub => 'Un lugar seguro donde quedarse';

  @override
  String get kindPower => 'Electricidad';

  @override
  String get kindPowerSub => 'Cargar un teléfono o un aparato médico';

  @override
  String get kindOther => 'Otra cosa';

  @override
  String get kindOtherSub => 'Descríbelo en el siguiente paso';

  @override
  String get kindSos => 'SOS';

  @override
  String get urgencyNow => 'Ahora mismo';

  @override
  String get urgencyNowSub => 'Hay riesgo para la vida o la seguridad';

  @override
  String get urgencySoon => 'En unas horas';

  @override
  String get urgencySoonSub => 'Está empeorando';

  @override
  String get urgencyLater => 'Puede esperar';

  @override
  String get urgencyLaterSub => 'Estable por ahora';

  @override
  String get stageSaved => 'Guardado en este teléfono';

  @override
  String get stageSavedSub => 'Se envía cuando haya una radio al alcance';

  @override
  String get stageMesh => 'Enviado por la red';

  @override
  String stageMeshSub(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'Pasó por $hops radios',
      one: 'Pasó por 1 radio',
      zero: 'Llegó directo a una radio',
    );
    return '$_temp0';
  }

  @override
  String get stageVerified => 'Revisado por el servidor';

  @override
  String get stageVerifiedSub => 'AWS revisó el pedido y guardó una copia';

  @override
  String get stageAssigned => 'Ayudante encontrado';

  @override
  String stageAssignedSub(String name) {
    return '$name aceptó el pedido';
  }

  @override
  String get stageOnTheWay => 'La ayuda va en camino';

  @override
  String stageOnTheWaySub(String name) {
    return '$name va hacia allí';
  }

  @override
  String get stageResolved => 'Resuelto';

  @override
  String get stageResolvedSub => 'Marcado como terminado';

  @override
  String get stageWaiting => 'En espera';

  @override
  String stepOf(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get helpStep1Title => '¿Qué necesitas?';

  @override
  String get helpStep2Title => '¿Algo más?';

  @override
  String get urgencyQuestion => '¿Qué tan urgente es?';

  @override
  String get peopleQuestion => '¿Cuántas personas necesitan ayuda?';

  @override
  String peopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get fewerPeople => 'Menos personas';

  @override
  String get morePeople => 'Más personas';

  @override
  String get locationTitle => 'Ubicación';

  @override
  String locationAuto(int meters) {
    return 'Se comparte automáticamente, con precisión de $meters m';
  }

  @override
  String get locationMissing =>
      'Tu ubicación no está disponible. Describe dónde estás.';

  @override
  String get locationNoteLabel => 'Describe dónde estás';

  @override
  String get locationNoteHint =>
      'Por ejemplo: segundo piso, junto a las escaleras';

  @override
  String get noteLabel => '¿Algo más? (opcional)';

  @override
  String get sendRequest => 'Enviar pedido';

  @override
  String get requestSent => 'Pedido enviado';

  @override
  String get requestDiscarded => 'Pedido descartado';

  @override
  String get requestCancelled => 'Pedido cancelado';

  @override
  String get requestRestored => 'Pedido restaurado';

  @override
  String get cancelRequest => 'Cancelar pedido';

  @override
  String get problemMissingKind => 'Elige lo que necesitas.';

  @override
  String problemPeople(int max) {
    return 'Escribe entre 1 y $max personas.';
  }

  @override
  String problemNoteTooLong(int max) {
    return 'Las notas deben tener menos de $max caracteres.';
  }

  @override
  String get problemLocation =>
      'Describe dónde estás, porque tu ubicación no está disponible.';

  @override
  String get offerStep1Title => 'Lo que puedo ofrecer';

  @override
  String get offerStep2Title => 'Algunos detalles';

  @override
  String get offerNoteLabel => 'Nota para quienes están cerca (opcional)';

  @override
  String get offerNoteHint => 'Por ejemplo: tengo un auto con espacio para 4';

  @override
  String get startOffering => 'Empezar a ofrecer';

  @override
  String get offeringStarted => 'Estás ofreciendo ayuda';

  @override
  String offeringList(String list) {
    return 'Ofreces: $list';
  }

  @override
  String get stopOffering => 'Detener';

  @override
  String get offerStopped => 'Dejaste de ofrecer ayuda';

  @override
  String get offerPrompt => '¿Puedes ayudar? Avisa a quienes están cerca.';

  @override
  String get tabNearMe => 'Cerca de mí';

  @override
  String get tabMine => 'Míos';

  @override
  String get iCanHelp => 'Puedo ayudar';

  @override
  String get youAreHelping => 'Estás ayudando';

  @override
  String get stopHelping => 'Dejar de ayudar';

  @override
  String get acceptedToast => 'Estás ayudando. Ya saben que vas en camino.';

  @override
  String get releasedToast => 'Dejaste de ayudar';

  @override
  String get noNearby => 'No hay pedidos abiertos cerca';

  @override
  String get noMine => 'No has pedido ayuda';

  @override
  String fromName(String name) {
    return 'De $name';
  }

  @override
  String get justNow => 'ahora mismo';

  @override
  String minutesAgo(int n) {
    return 'hace $n min';
  }

  @override
  String hoursAgo(int n) {
    return 'hace $n h';
  }

  @override
  String daysAgo(int n) {
    return 'hace $n d';
  }

  @override
  String get progressTitle => 'Avance';

  @override
  String get detailsTitle => 'Detalles';

  @override
  String get showToResponder => 'Mostrar al rescatista';

  @override
  String get requestNotFound => 'Este pedido ya no está disponible.';

  @override
  String get cardNeedHelp => 'Necesito ayuda';

  @override
  String get cardSwipeHint =>
      'Desliza a la izquierda o la derecha para cambiar el idioma';

  @override
  String get cardTheirWords => 'Sus propias palabras, sin traducir:';

  @override
  String get urgencyTitle => 'Urgencia';

  @override
  String get peopleTitle => 'Personas';

  @override
  String get noMessages => 'Todavía no hay mensajes';

  @override
  String get messageHint => 'Mensaje';

  @override
  String get languageSystem => 'Usar el idioma del teléfono';

  @override
  String get display => 'Pantalla y accesibilidad';

  @override
  String displaySub(int percent) {
    return 'Tamaño del texto $percent %';
  }

  @override
  String get theme => 'Tema';

  @override
  String get themeAuto => 'Automático';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get textSize => 'Tamaño del texto';

  @override
  String get highContrast => 'Alto contraste';

  @override
  String get highContrastSub => 'Colores y bordes más fuertes';

  @override
  String get textPreview => 'Así se verá el texto.';

  @override
  String get privacy => 'Privacidad y seguridad';

  @override
  String get phoneLockOn => 'El bloqueo está activado';

  @override
  String get phoneLockOff => 'El bloqueo está desactivado';

  @override
  String get phoneLock => 'Bloquear con Face ID o huella';

  @override
  String get phoneLockSub => 'Usa el código del teléfono si eso falla';

  @override
  String get phoneLockWeb => 'Disponible en la app para iOS y Android';

  @override
  String get phoneLockUnavailable =>
      'Primero configura un código o Face ID en este teléfono';

  @override
  String get lockNow => 'Bloquear ahora';

  @override
  String get lockNowSub => 'El SOS sigue funcionando con el bloqueo';

  @override
  String get clearTemp => 'Borrar datos temporales';

  @override
  String get clearTempSub =>
      'Mensajes viejos y pedidos terminados. AWS conserva sus copias.';

  @override
  String cleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se borraron $count elementos',
      one: 'Se borró 1 elemento',
      zero: 'No hay nada que borrar',
    );
    return '$_temp0';
  }

  @override
  String get eraseAll => 'Borrar todo en este teléfono';

  @override
  String get eraseAllSub => 'Mantén pulsado 3 segundos. No se puede deshacer.';

  @override
  String get erased => 'Se borró todo en este teléfono';

  @override
  String get network => 'Red de radios';

  @override
  String get manage => 'Administrar la red';

  @override
  String get manageSub => 'Activar o desactivar radios para todos';

  @override
  String get admin => 'Usuarios y roles';

  @override
  String get adminSub => 'Cambiar quién puede administrar la red';

  @override
  String get account => 'Cuenta';

  @override
  String signedInAs(String name) {
    return 'Sesión iniciada como $name';
  }

  @override
  String get guestMode => 'Usando Mesh como invitado';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signInSub =>
      'Opcional. Los ayudantes y administradores inician sesión.';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get roleLabel => 'Rol';

  @override
  String get roleClient => 'Miembro';

  @override
  String get roleManager => 'Coordinador';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get demoSignIn =>
      'Inicio de sesión de prueba. En la app real, el servidor asigna tu rol.';

  @override
  String get nodeOnline => 'En línea';

  @override
  String get nodeOffline => 'Sin conexión';

  @override
  String get hopsDirect => 'Directo';

  @override
  String hopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saltos',
      one: '1 salto',
    );
    return '$_temp0';
  }

  @override
  String get externalPower => 'Corriente externa';

  @override
  String get noNodes => 'Todavía no se escucha ninguna radio';

  @override
  String get nodeId => 'ID';

  @override
  String get lastHeard => 'Última señal';

  @override
  String get battery => 'Batería';

  @override
  String get signalStrength => 'Intensidad de la señal';

  @override
  String get signalNoise => 'Señal a ruido';

  @override
  String get hopsTitle => 'Saltos';

  @override
  String get manageHint =>
      'Las radios que desactives no se mostrarán a los miembros.';

  @override
  String get loadFailed => 'No se pudo cargar esta página.';

  @override
  String get lockedTitle => 'Mesh está bloqueado';

  @override
  String get lockedSub => 'Desbloquea para ver tus pedidos y mensajes.';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get unlockReason => 'Desbloquear Mesh';

  @override
  String get unlockWebNote =>
      'La vista web no tiene Face ID, así que Desbloquear abre la app directamente.';

  @override
  String get unlockFailed =>
      'No se pudo desbloquear. Inténtalo de nuevo o usa tu código.';

  @override
  String alertNearby(String kind) {
    return 'Nuevo pedido cerca: $kind';
  }

  @override
  String alertHelper(String name) {
    return '$name aceptó tu pedido';
  }

  @override
  String get navContacts => 'Contactos';

  @override
  String get kindFood => 'Comida';

  @override
  String get kindFoodSub => 'Comidas o leche de fórmula';

  @override
  String get kindMedicine => 'Medicinas';

  @override
  String get kindMedicineSub => 'Recetas, insulina, inhaladores';

  @override
  String get kindTransportation => 'Transporte';

  @override
  String get kindTransportationSub =>
      'Que te lleven, o ayuda para mover a alguien';

  @override
  String get kindCommunication => 'Comunicación';

  @override
  String get kindCommunicationSub => 'Contactar a la familia o pedir ayuda';

  @override
  String get noteExampleHint =>
      'Por ejemplo: necesito un lugar frío para guardar insulina para una persona';

  @override
  String get structuredFirst =>
      'Tu elección se envía primero, así llega incluso con mala señal. Tu nota se envía cuando haya espacio.';

  @override
  String suggestion(String kind) {
    return 'Parece: $kind';
  }

  @override
  String get useSuggestion => 'Usar esto';

  @override
  String get amountQuestion => '¿Cuánto tienes?';

  @override
  String get amountPlenty => 'Mucho';

  @override
  String get amountSome => 'Algo';

  @override
  String get amountLow => 'Poco';

  @override
  String get availabilityQuestion => '¿Cuándo está disponible?';

  @override
  String get availabilityNow => 'Ahora';

  @override
  String get availabilityToday => 'Hoy';

  @override
  String get availabilityCustom => 'Otro momento';

  @override
  String get availabilityNoteLabel => '¿Cuándo?';

  @override
  String get availabilityNoteHint => 'Por ejemplo: después de las 6 pm';

  @override
  String get transportQuestion => '¿Cómo puedes transportar?';

  @override
  String get transportWalking => 'A pie';

  @override
  String get transportBicycle => 'Bicicleta';

  @override
  String get transportCar => 'Auto';

  @override
  String get transportTruck => 'Camión';

  @override
  String get transportVan => 'Camioneta';

  @override
  String get capacityQuestion => '¿Cuánto puedes llevar?';

  @override
  String get capacitySmall => 'Poco';

  @override
  String get capacityMedium => 'Mediano';

  @override
  String get capacityLarge => 'Mucho';

  @override
  String get supplyWater => 'Agua';

  @override
  String get supplyFood => 'Comida';

  @override
  String get supplyBlankets => 'Cobijas';

  @override
  String get supplyBatteries => 'Pilas';

  @override
  String get supplyCharging => 'Carga';

  @override
  String get supplyMedicine => 'Medicinas';

  @override
  String get supplyTransportation => 'Transporte';

  @override
  String get supplyShelter => 'Refugio';

  @override
  String get supplyTools => 'Herramientas';

  @override
  String get supplyOther => 'Otra cosa';

  @override
  String get problemSupplies => 'Elige al menos una cosa.';

  @override
  String get problemTransport => 'Elige cómo puedes transportar.';

  @override
  String get resHospital => 'Hospital';

  @override
  String get resPharmacy => 'Farmacia';

  @override
  String get resPolice => 'Policía';

  @override
  String get resFire => 'Estación de bomberos';

  @override
  String get resWater => 'Agua';

  @override
  String get resFood => 'Comida';

  @override
  String get resShelter => 'Refugio';

  @override
  String get resCharging => 'Carga';

  @override
  String get resTransportation => 'Transporte';

  @override
  String get resRoadProblem => 'Problema en la calle';

  @override
  String get verifiedOrg => 'Organización verificada';

  @override
  String get communityResource => 'Recurso de la comunidad';

  @override
  String get unconfirmed => 'Sin confirmar';

  @override
  String get confidenceHigh => 'Confianza alta';

  @override
  String get confidenceMedium => 'Confianza media';

  @override
  String get confidenceLow => 'Confianza baja';

  @override
  String get trustSource => 'Fuente';

  @override
  String get trustCorroboration => 'Confirmaciones';

  @override
  String get trustFreshness => 'Actualidad';

  @override
  String confirmationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count confirmaciones',
      one: '1 confirmación',
      zero: 'Sin confirmaciones todavía',
    );
    return '$_temp0';
  }

  @override
  String disputesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objeciones',
      one: '1 objeción',
      zero: 'sin objeciones',
    );
    return '$_temp0';
  }

  @override
  String get oneReport => 'Solo 1 reporte por ahora';

  @override
  String officialUpdate(String time) {
    return 'Actualización oficial $time';
  }

  @override
  String lastObservation(String time) {
    return 'Observación más reciente $time';
  }

  @override
  String staleWarning(String time) {
    return 'Visto por última vez $time. Puede estar desactualizado.';
  }

  @override
  String get voteUseful => 'Útil';

  @override
  String get voteConfirm => 'Confirmar';

  @override
  String get voteConfirmSub => 'Lo vi yo mismo';

  @override
  String get voteDispute => 'Objetar';

  @override
  String get voteDisputeSub => 'Lo que vi fue distinto';

  @override
  String get voted => 'Gracias. Tu reporte está firmado y compartido.';

  @override
  String get voteWithdrawnToast => 'Reporte retirado';

  @override
  String get approxLocation => 'Ubicación aproximada';

  @override
  String get inventoryTitle => 'Existencias';

  @override
  String officialStock(int count, String time) {
    return 'Conteo oficial: $count a las $time';
  }

  @override
  String reservedFor(int count, String id) {
    return '$count reservados para la Misión $id';
  }

  @override
  String remainingCount(int count) {
    return 'Quedan $count';
  }

  @override
  String get communityReports => 'Reportes de la comunidad';

  @override
  String observationAt(String text, String time) {
    return '$text a las $time';
  }

  @override
  String get addHereTitle => 'Agregar algo aquí';

  @override
  String get addHereHint =>
      'Mantén pulsado el mapa para agregar agua, comida, refugio o un problema que veas.';

  @override
  String get addNoteHint => 'Agrega una nota corta (opcional)';

  @override
  String get addResource => 'Agregar';

  @override
  String get resourceAdded =>
      'Agregado. Los demás ven una ubicación aproximada.';

  @override
  String get resourceRemoved => 'Eliminado';

  @override
  String get addedByYou => 'Agregado por ti';

  @override
  String get statusOffline => 'Sin conexión';

  @override
  String get statusOnline => 'En línea';

  @override
  String get statusReady => 'Listo';

  @override
  String lastSyncAgo(String time) {
    return 'Última sincronización $time';
  }

  @override
  String alertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alertas',
      one: '1 alerta',
    );
    return '$_temp0';
  }

  @override
  String get alertsTitle => 'Alertas';

  @override
  String get layerFacilities => 'Hospitales, farmacias, policía y bomberos';

  @override
  String get layerLive => 'Agua, comida, refugio y reportes';

  @override
  String get networkTitle => 'Estado de la red';

  @override
  String get netInternet => 'Internet';

  @override
  String get netPeers => 'Teléfonos cercanos';

  @override
  String get netNode => 'Nodo de resiliencia';

  @override
  String get netLora => 'Radio LoRa';

  @override
  String get netLastLocal => 'Última sincronización cercana';

  @override
  String get netLastGlobal => 'Última sincronización con la nube';

  @override
  String get netConnected => 'Conectado';

  @override
  String get netNotConnected => 'Sin conectar';

  @override
  String peersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teléfonos',
      one: '1 teléfono',
      zero: 'Ninguno',
    );
    return '$_temp0';
  }

  @override
  String queuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos pendientes de enviar',
      one: '1 elemento pendiente de enviar',
      zero: 'Nada pendiente de enviar',
    );
    return '$_temp0';
  }

  @override
  String get demoInternet => 'Prueba: simular que volvió el internet';

  @override
  String get demoInternetSub =>
      'Muestra qué cambia cuando este teléfono se conecta';

  @override
  String get viewRadios => 'Radios en la red';

  @override
  String get downloadsTitle => 'Descargas sin conexión';

  @override
  String packageTitle(String region) {
    return 'Paquete de preparación de $region';
  }

  @override
  String get packageContents =>
      'Mapa sin conexión, servicios de emergencia, rutas, organizaciones de confianza, revocaciones, instrucciones de emergencia y estado reciente de recursos.';

  @override
  String packageSize(int size, int version) {
    return '$size MB, versión $version';
  }

  @override
  String packageUpToDate(String time) {
    return 'Actualizado. Descargado $time';
  }

  @override
  String packageUpdate(int version) {
    return 'Hay una actualización: versión $version';
  }

  @override
  String get downloadNow => 'Descargar ahora';

  @override
  String downloadingPercent(int percent) {
    return 'Descargando $percent %';
  }

  @override
  String get downloadNeedsNet =>
      'Necesita internet o un nodo de resiliencia cerca.';

  @override
  String preparednessNotice(String region, int size) {
    return 'Nuevo paquete sin conexión para $region: $size MB';
  }

  @override
  String get download => 'Descargar';

  @override
  String get orgsTitle => 'Organizaciones de confianza';

  @override
  String certifiedBy(String name) {
    return 'Certificada por $name';
  }

  @override
  String get rootOfTrust => 'Raíz de confianza';

  @override
  String revocationsChecked(String time) {
    return 'Certificados y revocaciones revisados $time. Sin conexión, esta es la lista más reciente que tiene este teléfono.';
  }

  @override
  String get tabPeople => 'Personas';

  @override
  String get tabOrganizations => 'Organizaciones';

  @override
  String get scanQr => 'Escanear QR';

  @override
  String get myQr => 'Mi QR';

  @override
  String get moreWaysToAdd => 'Otras formas de agregar';

  @override
  String get addByUsername => 'Agregar por usuario';

  @override
  String get addByPhone => 'Agregar por número de teléfono';

  @override
  String get needsInternetToFind =>
      'Necesita internet. Pídele que te muestre su código QR.';

  @override
  String get metInPerson => 'En persona';

  @override
  String get addedByUsername => 'Agregado por usuario';

  @override
  String get addedByPhone => 'Agregado por teléfono';

  @override
  String get myQrTitle => 'Mi ID de Resiliencia';

  @override
  String get myQrHint =>
      'Muéstralo a quien conozcas. Comparte tu clave pública, nunca tu número de teléfono.';

  @override
  String get resilienceId => 'ID de Resiliencia';

  @override
  String get scanTitle => 'Escanear un código QR';

  @override
  String get scanHint => 'Apunta la cámara al código QR.';

  @override
  String get scanUnavailable =>
      'La cámara no está disponible aquí. Escríbelo en su lugar.';

  @override
  String get typeIdLabel => 'Su ID de Resiliencia';

  @override
  String get typeIdHint => '16 letras y números';

  @override
  String get theirName => 'Su nombre';

  @override
  String get addContact => 'Agregar contacto';

  @override
  String contactAdded(String name) {
    return '$name agregado';
  }

  @override
  String contactRemoved(String name) {
    return '$name eliminado';
  }

  @override
  String get invalidId => 'Eso no parece un ID de Resiliencia.';

  @override
  String get notFound => 'No se encontró a nadie.';

  @override
  String get usernameLabel => 'Usuario';

  @override
  String get phoneLabel => 'Número de teléfono';

  @override
  String get find => 'Buscar';

  @override
  String get messageAction => 'Mensaje';

  @override
  String get removeContact => 'Eliminar';

  @override
  String get noContacts =>
      'Todavía no hay contactos. Escanea el código QR de alguien para agregarlo.';

  @override
  String get tabDirect => 'Directos';

  @override
  String get tabCommunity => 'Comunidad';

  @override
  String get tabMission => 'Misión';

  @override
  String get channelPublic => 'Público. Cualquiera puede leerlo.';

  @override
  String get channelCommunity => 'Miembros de la comunidad';

  @override
  String get channelRestricted => 'Solo personal, cifrado';

  @override
  String get channelMission => 'Solo el equipo de la misión';

  @override
  String get channelDirect => 'Privado';

  @override
  String get readOnlyChannel =>
      'Solo las organizaciones verificadas publican aquí.';

  @override
  String sendsOver(String route) {
    return 'Se envía por: $route';
  }

  @override
  String get routeInternet => 'Internet';

  @override
  String get routeLocal => 'Nodo de resiliencia';

  @override
  String get routeMesh => 'Red LoRa';

  @override
  String get routeQueued => 'Espera en este teléfono hasta que haya ruta';

  @override
  String get deliveryQueued => 'En cola';

  @override
  String get deliveryPropagating => 'En camino';

  @override
  String get deliveryDelivered => 'Entregado';

  @override
  String get deliveryRead => 'Leído';

  @override
  String get noChannels => 'Todavía no hay conversaciones aquí';

  @override
  String get deliveries => 'Entregas';

  @override
  String get deliveriesSub => 'Misiones que puedes llevar';

  @override
  String get tabAvailable => 'Disponibles';

  @override
  String get tabAssigned => 'Asignadas';

  @override
  String get tabInTransit => 'En camino';

  @override
  String get tabHandoff => 'Traspaso';

  @override
  String get tabCompleted => 'Terminadas';

  @override
  String missionTitle(String id) {
    return 'Misión $id';
  }

  @override
  String get priorityHigh => 'Prioridad alta';

  @override
  String get priorityNormal => 'Prioridad normal';

  @override
  String get priorityLow => 'Prioridad baja';

  @override
  String get pickupLabel => 'Recoger en';

  @override
  String get destinationLabel => 'Destino';

  @override
  String get carrierLabel => 'Lo lleva';

  @override
  String packageLabel(String id) {
    return 'Paquete $id';
  }

  @override
  String get exactHidden => 'La dirección exacta solo la ve quien lo lleva';

  @override
  String get acceptMission => 'Aceptar misión';

  @override
  String get missionAccepted =>
      'Misión aceptada. Ya puedes ver las direcciones exactas.';

  @override
  String get missionReleased => 'Misión devuelta';

  @override
  String get confirmPickup => 'Confirmar recogida';

  @override
  String get pickedUp => 'Recogida confirmada y firmada';

  @override
  String get confirmDelivery => 'Confirmar entrega';

  @override
  String get deliveredToast => 'Entrega confirmada y firmada';

  @override
  String get handOff => 'Pasar a otro';

  @override
  String get handoffWaiting =>
      'Esperando a que el siguiente conductor escanee el código del paquete';

  @override
  String handoffConfirmed(String name, String id) {
    return 'Traspaso confirmado: $name tiene el paquete $id';
  }

  @override
  String get packageCode => 'Código del paquete';

  @override
  String get packageQrHint =>
      'La otra persona escanea esto. Contiene el número del paquete y una firma, nada privado.';

  @override
  String get scanPackage => 'Escanear el código del paquete';

  @override
  String get enterPackageId => 'Número del paquete';

  @override
  String wrongPackage(String id) {
    return 'Ese no es el paquete $id.';
  }

  @override
  String get mStageAvailable => 'Disponible';

  @override
  String get mStageAssigned => 'Asignada a ti';

  @override
  String get mStageInTransit => 'En camino';

  @override
  String get mStageHandoff => 'Esperando traspaso';

  @override
  String get mStageDelivered => 'Entregada';

  @override
  String handedOffTo(String name) {
    return 'Entregada a $name';
  }

  @override
  String get noMissions => 'Nada por ahora';

  @override
  String get deliveriesHint =>
      'Ofrece transporte para ver misiones cerca de ti.';

  @override
  String get sectionActivity => 'Tu actividad';

  @override
  String get sectionNetwork => 'Red y datos';

  @override
  String get sectionSettings => 'Ajustes';

  @override
  String get sectionManage => 'Administración';

  @override
  String get myRequests => 'Mis pedidos';

  @override
  String openCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count abiertos',
      one: '1 abierto',
      zero: 'Ninguno abierto',
    );
    return '$_temp0';
  }

  @override
  String get mySupplies => 'Lo que ofrezco';

  @override
  String get notOffering => 'No estás ofreciendo nada';

  @override
  String orgCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count organizaciones',
      one: '1 organización',
    );
    return '$_temp0';
  }

  @override
  String get historyTitle => 'Historial firmado';

  @override
  String get historyHint => 'Cada paso se firma en el teléfono que lo hizo.';

  @override
  String signedBy(String id) {
    return 'Firmado por $id';
  }

  @override
  String get evHelpRequested => 'Ayuda pedida';

  @override
  String get evHelpCancelled => 'Pedido cancelado';

  @override
  String get evHelpAccepted => 'Un ayudante aceptó';

  @override
  String get evHelpReleased => 'El ayudante se retiró';

  @override
  String get evHelpOffered => 'Oferta publicada';

  @override
  String get evOfferWithdrawn => 'Oferta retirada';

  @override
  String get evResourceCreated => 'Recurso agregado';

  @override
  String get evResourceRemoved => 'Recurso eliminado';

  @override
  String get evResourceConfirmed => 'Confirmado';

  @override
  String get evResourceDisputed => 'Objetado';

  @override
  String get evResourceUseful => 'Marcado como útil';

  @override
  String get evVoteWithdrawn => 'Reporte retirado';

  @override
  String get evContactAdded => 'Contacto agregado';

  @override
  String get evContactRemoved => 'Contacto eliminado';

  @override
  String get evMessageSent => 'Mensaje enviado';

  @override
  String get evMissionAccepted => 'Misión aceptada';

  @override
  String get evMissionReleased => 'Misión devuelta';

  @override
  String get evPackagePickedUp => 'Paquete recogido';

  @override
  String get evPackageTransferred => 'Paquete traspasado';

  @override
  String get evDeliveryCompleted => 'Entrega completada';

  @override
  String get stageSavedTheirs => 'Guardado en su teléfono';

  @override
  String get stageSavedTheirsSub => 'Se guardó ahí hasta tener una radio cerca';

  @override
  String get mapSource => 'Mapa de calles de Amazon Location';

  @override
  String get mapSourceNote =>
      'Necesita internet. Los marcadores, radios y solicitudes se siguen viendo cuando el mapa de calles no carga.';

  @override
  String get mapNotSetUp => 'Mapa de calles sin configurar';

  @override
  String get mapOffline => 'El mapa de calles necesita internet';

  @override
  String get mapLoading => 'Cargando mapa de calles';

  @override
  String get missionNotFound => 'Esta entrega ya no está disponible.';

  @override
  String get resourceNotFound => 'Este lugar ya no está en el mapa.';

  @override
  String get navNewMessage => 'Mensaje nuevo';

  @override
  String get navChannels => 'Canales';

  @override
  String get navNoDirectChats =>
      'Todavía no hay nadie a quien escribir directamente. Escanea el código QR de alguien para agregarlo.';

  @override
  String get navAddDetails => 'Agregar detalles';

  @override
  String get navAddDetailsSub => 'Una nota y cuántas personas';

  @override
  String get navAdvanced => 'Avanzado';

  @override
  String get navRequestTakenBack => 'Pedido retirado';

  @override
  String get navChangeOffer => 'Cambiar lo que ofrezco';

  @override
  String get navHoldForMore => 'Mantén presionado para ver más acciones';

  @override
  String navLocationTyped(String place) {
    return 'Tu ubicación: $place';
  }

  @override
  String get sosContactsTitle => 'Contactos de emergencia';

  @override
  String sosContactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
      zero: 'Ninguno todavía',
    );
    return '$_temp0';
  }

  @override
  String get sosContactsIntro =>
      'Si un SOS no llega a ninguna red, Mesh te ayuda a enviar un mensaje de texto a estas personas desde la app de mensajes de tu teléfono.';

  @override
  String get sosContactsEmpty => 'Todavía no tienes contactos de emergencia.';

  @override
  String get sosAddContact => 'Agregar contacto de emergencia';

  @override
  String get sosEditContact => 'Editar contacto de emergencia';

  @override
  String get sosContactName => 'Nombre';

  @override
  String get sosContactPhone => 'Número de teléfono';

  @override
  String get sosContactPhoneHint => 'Por ejemplo: +1 408 555 0100';

  @override
  String get sosContactPhoneInvalid =>
      'Revisa el número: usa dígitos y + antes del código de país';

  @override
  String get sosSaveContact => 'Guardar';

  @override
  String sosContactSaved(String name) {
    return 'Se guardó a $name';
  }

  @override
  String sosContactRemoved(String name) {
    return 'Se quitó a $name';
  }

  @override
  String sosRemoveContact(String name) {
    return 'Quitar a $name';
  }

  @override
  String sosContactsFull(int count) {
    return 'Puedes guardar hasta $count contactos de emergencia.';
  }

  @override
  String get sosNoNetworkTitle => 'No se llegó a ninguna red';

  @override
  String get sosNoNetworkBody =>
      'Tu SOS está guardado en este teléfono y saldrá en cuanto Mesh encuentre una red. Envía un mensaje a tus contactos de emergencia o llama al 911 ahora.';

  @override
  String get sosNoNetworkBodyNoContacts =>
      'Tu SOS está guardado en este teléfono y saldrá en cuanto Mesh encuentre una red. Llama al 911 ahora si puedes.';

  @override
  String sosTextContacts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar SMS a $count contactos de emergencia',
      one: 'Enviar SMS a 1 contacto de emergencia',
    );
    return '$_temp0';
  }

  @override
  String get sosCall911 => 'Llamar al 911';

  @override
  String get sosNotNow => 'Ahora no';

  @override
  String get sosDone => 'Listo';

  @override
  String get sosAddContacts => 'Agregar contactos de emergencia';

  @override
  String get sosMessageLabel => 'Tu mensaje de texto';

  @override
  String get sosLaunchFailed =>
      'Este teléfono no pudo abrirlo. Inténtalo de nuevo o usa la app de tu teléfono.';

  @override
  String sosTextBody(String name, String location, String time) {
    return 'SOS de $name. Necesito ayuda. Ubicación: $location. Hora: $time.';
  }

  @override
  String sosTextBodyGuest(String location, String time) {
    return 'SOS. Necesito ayuda. Ubicación: $location. Hora: $time.';
  }

  @override
  String get sosLocationUnknown => 'desconocida';
}
