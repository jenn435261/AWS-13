import 'package:flutter/widgets.dart';

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
  ];

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n) ?? const L10n(Locale('en'));
  }

  String t(String key) {
    final lang = locale.languageCode;
    return _data[lang]?[key] ?? _data['en']![key] ?? key;
  }

  /// Human-readable language name for a code (for the language switcher).
  static String languageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
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
