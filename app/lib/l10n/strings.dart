import 'package:flutter/widgets.dart';

import 'strings_fr.dart';
import 'strings_new.dart';
import 'strings_zh.dart';

/// Centralized localization for Resilience Network.
///
/// Hand-rolled (no codegen) so builds stay fast. Every user-facing string in
/// the UI MUST come from here — no hardcoded English in widgets. Add a locale
/// by adding a map to [_data]; the app advertises [supportedLocales].
///
/// Rule compliance: strings are short and plain so they render at >= 16px
/// without overflow, and support the two-tap emergency flows.
class L10n {
  final Locale locale;
  const L10n(this.locale);

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('zh'),
  ];

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n) ?? const L10n(Locale('en'));
  }

  String t(String key) {
    final lang = locale.languageCode;
    return _lookup(lang, key) ?? _lookup('en', key) ?? key;
  }

  /// Newer strings override the original set; fr and zh live in their own files.
  static String? _lookup(String lang, String key) {
    switch (lang) {
      case 'fr':
        return kStringsFr[key];
      case 'zh':
        return kStringsZh[key];
      default:
        return kStringsNew[lang]?[key] ?? _data[lang]?[key];
    }
  }

  /// The complete set of English keys — the union of the original [_data]
  /// English map and the later [kStringsNew] English additions. English is the
  /// source of truth, so this is the key set every other locale must cover.
  /// Exposed so tests can pin l10n parity against the real English set rather
  /// than a proxy.
  static Set<String> get englishKeys => <String>{
        ...?_data['en']?.keys,
        ...?kStringsNew['en']?.keys,
      };

  /// Human-readable language name for a code (for the language switcher).
  static String languageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'zh':
        return '中文（简体）';
      default:
        return code;
    }
  }

  static const Map<String, Map<String, String>> _data = {
    'en': {
      'app_title': 'Resilience',
      // Nav
      'nav_map': 'Map',
      'nav_messages': 'Messages',
      'nav_contacts': 'Contacts',
      'nav_more': 'More',
      'nav_deliveries': 'Deliveries',
      // Map / primary actions
      'i_need_help': 'I Need Help',
      'offer_help': 'Offer Help',
      'you_are_here': 'You',
      'offline': 'Offline',
      'online': 'Online',
      'ready': 'Ready',
      'last_sync': 'Last sync',
      // Help flow
      'what_do_you_need': 'What do you need?',
      'anything_else': 'Anything else?',
      'add_a_note': 'Add a note (optional)',
      'send': 'Send',
      'send_request': 'Send request',
      'send_offer': 'Send offer',
      'structure_with_ai': 'Structure with AI',
      'ai_offline_suggestion': 'Offline suggestion',
      'request_sent': 'Request sent',
      'offer_sent': 'Offer sent',
      'undo': 'Undo',
      // Categories
      'cat_water': 'Water',
      'cat_food': 'Food',
      'cat_medicine': 'Medicine',
      'cat_shelter': 'Shelter',
      'cat_power': 'Power',
      'cat_transportation': 'Transportation',
      'cat_medical_help': 'Medical Help',
      'cat_communication': 'Communication',
      'cat_blankets': 'Blankets',
      'cat_batteries': 'Batteries',
      'cat_charging': 'Charging',
      'cat_tools': 'Tools',
      'cat_other': 'Other',
      // Offer detail
      'amount': 'Amount',
      'availability': 'Availability',
      'amount_plenty': 'Plenty',
      'amount_some': 'Some',
      'amount_low': 'Low',
      'avail_now': 'Now',
      'avail_today': 'Today',
      'avail_custom': 'Custom',
      'advanced_options': 'Advanced options',
      // Trust
      'verified_organization': 'Verified organization',
      'community_resource': 'Community resource',
      'confirmations': 'confirmations',
      'disputes': 'disputes',
      'useful': 'Useful',
      'confirm': 'Confirm',
      'dispute': 'Dispute',
      'confidence_high': 'High confidence',
      'confidence_medium': 'Medium confidence',
      'confidence_low': 'Low confidence',
      'confidence_unconfirmed': 'Unconfirmed',
      'last_confirmed': 'Last confirmed',
      'last_observed': 'Last observed',
      // Messages
      'direct': 'Direct',
      'community': 'Community',
      'mission': 'Mission',
      'type_a_message': 'Type a message',
      'queued': 'Queued',
      'propagating': 'Propagating',
      'delivered': 'Delivered',
      'read': 'Read',
      'conn_internet': 'Internet',
      'conn_local': 'Local',
      'conn_mesh': 'Mesh',
      'conn_queued': 'Queued',
      // Contacts
      'people': 'People',
      'organizations': 'Organizations',
      'verified': 'Verified',
      'scan_qr': 'Scan QR',
      'my_qr': 'My QR',
      'add_by_username': 'Add by username',
      'add_by_phone': 'Add by phone',
      'manual_entry': 'Enter code manually',
      'my_resilience_id': 'My Resilience ID',
      'copy': 'Copy',
      'copied': 'Copied to clipboard',
      // Location sharing
      'share_location': 'Share my location',
      'share_with_contact': 'With a contact',
      'share_with_channel': 'With a channel',
      'share_public_beacon': 'Public beacon',
      'share_duration': 'Share for',
      'dur_15m': '15 minutes',
      'dur_1h': '1 hour',
      'dur_custom': 'Custom',
      'precision': 'Precision',
      'precision_exact': 'Exact location',
      'precision_approx': 'Approximate (neighborhood)',
      'stop_sharing': 'Stop sharing',
      'sharing_active': 'Sharing active',
      'public_beacon_warning':
          'A public beacon reveals your location to everyone on the network. Use only if you intend this.',
      'location_shared': 'Location shared',
      'location_share_stopped': 'Location sharing stopped',
      'expires_in': 'Expires in',
      // More / settings
      'my_supplies': 'My Supplies',
      'my_requests': 'My Requests',
      'offline_downloads': 'Offline Downloads',
      'network_status': 'Network Status',
      'trusted_organizations': 'Trusted Organizations',
      'settings': 'Settings',
      'language': 'Language',
      'biometric_lock': 'Biometric lock',
      'data_controls': 'Data Controls',
      'clear_cache': 'Clear temporary cache',
      'full_wipe': 'Erase all data',
      'full_wipe_confirm':
          'This permanently erases your identity, messages, and all local data. This cannot be undone.',
      'cancel': 'Cancel',
      'erase': 'Erase',
      'nearby_peers': 'Nearby peers',
      'resilience_node': 'Resilience node',
      'lora': 'LoRa',
      // Generic
      'loading': 'Loading',
      'retry': 'Retry',
      'back': 'Back',
      'next': 'Next',
      'done': 'Done',
      'msg_not_connected': 'Secure messaging is not connected yet',
      'msg_not_connected_hint': 'Add contacts now. Encrypted chat turns on once contact keys can sync between devices.',
      'location_not_connected': 'Location sharing is not connected yet',
      'add_contact': 'Add contact',
      'contact_added': 'Contact added',
      'contact_exists': 'Already in your contacts',
      'invalid_code': 'That code is not a valid Resilience ID card',
      'paste_code': 'Paste a contact code',
      'add': 'Add',
      'no_contacts': 'No contacts yet',
      'no_contacts_hint': 'Tap Add contact to scan or enter a code.',
      'remove_contact': 'Remove contact',
      'contact_removed': 'Contact removed',
      'copy_code': 'Copy my code',
      'share_your_code': 'Show this to the person you want to connect with',
      'close': 'Close',
      'scan_hint': 'Point the camera at a Resilience QR code',
      'camera_unavailable': 'Camera unavailable. Enter the code manually instead.',
      'dur_4h': '4 hours',
      'dur_24h': '24 hours',
      'dur_indefinite': 'Until I stop',
      'sharing_until_stopped': 'until you stop it',
      'no_requests': 'You have not made any requests',
      'no_requests_hint': 'Requests you send appear here.',
      'no_supplies': 'You have not offered any supplies',
      'no_supplies_hint': 'Offers you send appear here.',
      'requests_sent': 'Requests',
      'offers_sent': 'Offers',
      'no_trusted_orgs': 'No verified organizations yet',
      'no_trusted_hint': 'Organizations appear here once a trusted root is installed from a readiness package. Resources from verified organizations are badged on the map.',
      'trusted_roots': 'Trusted roots on this device',
      'node_address': 'Resilience node address',
      'node_hint': 'e.g. http://192.168.1.20:8080 (a node on your local Wi-Fi)',
      'check_node': 'Check node',
      'node_not_set': 'Enter your node address to see what it offers.',
      'pkg_app': 'Android app',
      'pkg_map': 'Offline map',
      'pkg_readiness': 'Readiness guide',
      'pkg_available': 'Available',
      'pkg_missing': 'Not on this node',
      'pkg_unreachable': 'Node not reachable',
      'downloads_explainer': 'Packages are served by a Resilience Node over local Wi-Fi so you can prepare before a disruption.',
      'status_checking': 'Checking…',
      'status_reachable': 'Reachable',
      'status_unreachable': 'Not reachable',
      'status_unavailable_here': 'Not available in this browser',
      'status_not_configured': 'Not set up',
      'status_not_supported': 'Not supported yet',
      'last_checked': 'Last checked',
      'refresh': 'Refresh',
      'data_erased': 'All local data erased',
      'cache_cleared': 'Temporary cache cleared',
      'location_not_sent': 'Your location is not shared until a position source is connected.',
      'unlock_to_continue': 'Unlock to continue',
    },
    'es': {
      'app_title': 'Resiliencia',
      'nav_map': 'Mapa',
      'nav_messages': 'Mensajes',
      'nav_contacts': 'Contactos',
      'nav_more': 'Más',
      'nav_deliveries': 'Entregas',
      'i_need_help': 'Necesito Ayuda',
      'offer_help': 'Ofrecer Ayuda',
      'you_are_here': 'Tú',
      'offline': 'Sin conexión',
      'online': 'En línea',
      'ready': 'Listo',
      'last_sync': 'Última sinc.',
      'what_do_you_need': '¿Qué necesitas?',
      'anything_else': '¿Algo más?',
      'add_a_note': 'Agregar una nota (opcional)',
      'send': 'Enviar',
      'send_request': 'Enviar solicitud',
      'send_offer': 'Enviar oferta',
      'structure_with_ai': 'Estructurar con IA',
      'ai_offline_suggestion': 'Sugerencia sin conexión',
      'request_sent': 'Solicitud enviada',
      'offer_sent': 'Oferta enviada',
      'undo': 'Deshacer',
      'cat_water': 'Agua',
      'cat_food': 'Comida',
      'cat_medicine': 'Medicina',
      'cat_shelter': 'Refugio',
      'cat_power': 'Energía',
      'cat_transportation': 'Transporte',
      'cat_medical_help': 'Ayuda médica',
      'cat_communication': 'Comunicación',
      'cat_blankets': 'Mantas',
      'cat_batteries': 'Baterías',
      'cat_charging': 'Carga',
      'cat_tools': 'Herramientas',
      'cat_other': 'Otro',
      'amount': 'Cantidad',
      'availability': 'Disponibilidad',
      'amount_plenty': 'Mucha',
      'amount_some': 'Alguna',
      'amount_low': 'Poca',
      'avail_now': 'Ahora',
      'avail_today': 'Hoy',
      'avail_custom': 'Personalizado',
      'advanced_options': 'Opciones avanzadas',
      'verified_organization': 'Organización verificada',
      'community_resource': 'Recurso comunitario',
      'confirmations': 'confirmaciones',
      'disputes': 'disputas',
      'useful': 'Útil',
      'confirm': 'Confirmar',
      'dispute': 'Disputar',
      'confidence_high': 'Alta confianza',
      'confidence_medium': 'Confianza media',
      'confidence_low': 'Baja confianza',
      'confidence_unconfirmed': 'Sin confirmar',
      'last_confirmed': 'Confirmado',
      'last_observed': 'Observado',
      'direct': 'Directo',
      'community': 'Comunidad',
      'mission': 'Misión',
      'type_a_message': 'Escribe un mensaje',
      'queued': 'En cola',
      'propagating': 'Propagando',
      'delivered': 'Entregado',
      'read': 'Leído',
      'conn_internet': 'Internet',
      'conn_local': 'Local',
      'conn_mesh': 'Malla',
      'conn_queued': 'En cola',
      'people': 'Personas',
      'organizations': 'Organizaciones',
      'verified': 'Verificado',
      'scan_qr': 'Escanear QR',
      'my_qr': 'Mi QR',
      'add_by_username': 'Agregar por usuario',
      'add_by_phone': 'Agregar por teléfono',
      'manual_entry': 'Ingresar código manualmente',
      'my_resilience_id': 'Mi ID de Resiliencia',
      'copy': 'Copiar',
      'copied': 'Copiado al portapapeles',
      'share_location': 'Compartir mi ubicación',
      'share_with_contact': 'Con un contacto',
      'share_with_channel': 'Con un canal',
      'share_public_beacon': 'Baliza pública',
      'share_duration': 'Compartir por',
      'dur_15m': '15 minutos',
      'dur_1h': '1 hora',
      'dur_custom': 'Personalizado',
      'precision': 'Precisión',
      'precision_exact': 'Ubicación exacta',
      'precision_approx': 'Aproximada (vecindario)',
      'stop_sharing': 'Dejar de compartir',
      'sharing_active': 'Compartiendo ahora',
      'public_beacon_warning':
          'Una baliza pública revela tu ubicación a todos en la red. Úsala solo si es tu intención.',
      'location_shared': 'Ubicación compartida',
      'location_share_stopped': 'Se dejó de compartir la ubicación',
      'expires_in': 'Expira en',
      'my_supplies': 'Mis Suministros',
      'my_requests': 'Mis Solicitudes',
      'offline_downloads': 'Descargas sin conexión',
      'network_status': 'Estado de red',
      'trusted_organizations': 'Organizaciones de confianza',
      'settings': 'Ajustes',
      'language': 'Idioma',
      'biometric_lock': 'Bloqueo biométrico',
      'data_controls': 'Control de datos',
      'clear_cache': 'Borrar caché temporal',
      'full_wipe': 'Borrar todos los datos',
      'full_wipe_confirm':
          'Esto borra permanentemente tu identidad, mensajes y todos los datos locales. No se puede deshacer.',
      'cancel': 'Cancelar',
      'erase': 'Borrar',
      'nearby_peers': 'Dispositivos cercanos',
      'resilience_node': 'Nodo de resiliencia',
      'lora': 'LoRa',
      'loading': 'Cargando',
      'retry': 'Reintentar',
      'back': 'Atrás',
      'next': 'Siguiente',
      'done': 'Listo',
      'msg_not_connected': 'La mensajería segura aún no está conectada',
      'msg_not_connected_hint': 'Agrega contactos ahora. El chat cifrado se activa cuando las claves de contacto puedan sincronizarse entre dispositivos.',
      'location_not_connected': 'Compartir ubicación aún no está conectado',
      'add_contact': 'Agregar contacto',
      'contact_added': 'Contacto agregado',
      'contact_exists': 'Ya está en tus contactos',
      'invalid_code': 'Ese código no es una tarjeta de ID Resilience válida',
      'paste_code': 'Pega un código de contacto',
      'add': 'Agregar',
      'no_contacts': 'Aún no hay contactos',
      'no_contacts_hint': 'Toca Agregar contacto para escanear o ingresar un código.',
      'remove_contact': 'Eliminar contacto',
      'contact_removed': 'Contacto eliminado',
      'copy_code': 'Copiar mi código',
      'share_your_code': 'Muestra esto a la persona con quien quieres conectarte',
      'close': 'Cerrar',
      'scan_hint': 'Apunta la cámara a un código QR de Resilience',
      'camera_unavailable': 'Cámara no disponible. Ingresa el código manualmente.',
      'dur_4h': '4 horas',
      'dur_24h': '24 horas',
      'dur_indefinite': 'Hasta que lo detenga',
      'sharing_until_stopped': 'hasta que lo detengas',
      'no_requests': 'No has hecho solicitudes',
      'no_requests_hint': 'Las solicitudes que envíes aparecen aquí.',
      'no_supplies': 'No has ofrecido suministros',
      'no_supplies_hint': 'Las ofertas que envíes aparecen aquí.',
      'requests_sent': 'Solicitudes',
      'offers_sent': 'Ofertas',
      'no_trusted_orgs': 'Aún no hay organizaciones verificadas',
      'no_trusted_hint': 'Las organizaciones aparecen aquí cuando se instala una raíz de confianza desde un paquete de preparación. Los recursos de organizaciones verificadas se marcan en el mapa.',
      'trusted_roots': 'Raíces de confianza en este dispositivo',
      'node_address': 'Dirección del nodo de resiliencia',
      'node_hint': 'p. ej. http://192.168.1.20:8080 (un nodo en tu Wi-Fi local)',
      'check_node': 'Comprobar nodo',
      'node_not_set': 'Ingresa la dirección de tu nodo para ver qué ofrece.',
      'pkg_app': 'App de Android',
      'pkg_map': 'Mapa sin conexión',
      'pkg_readiness': 'Guía de preparación',
      'pkg_available': 'Disponible',
      'pkg_missing': 'No está en este nodo',
      'pkg_unreachable': 'Nodo no accesible',
      'downloads_explainer': 'Los paquetes los sirve un nodo de resiliencia por Wi-Fi local para que te prepares antes de una interrupción.',
      'status_checking': 'Comprobando…',
      'status_reachable': 'Accesible',
      'status_unreachable': 'No accesible',
      'status_unavailable_here': 'No disponible en este navegador',
      'status_not_configured': 'Sin configurar',
      'status_not_supported': 'Aún no compatible',
      'last_checked': 'Última comprobación',
      'refresh': 'Actualizar',
      'data_erased': 'Todos los datos locales borrados',
      'cache_cleared': 'Caché temporal borrada',
      'location_not_sent': 'Tu ubicación no se comparte hasta que se conecte una fuente de posición.',
      'unlock_to_continue': 'Desbloquea para continuar',
    },
  };
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      L10n.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}
