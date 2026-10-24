import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/labels.dart';
import '../state/app_scope.dart';
import '../ui/feedback.dart';

/// The local emergency number. 911 covers the US and Canada.
const emergencyNumber = '911';

/// The manual fallback that needs no mesh at all: a normal phone call.
Future<void> callEmergencyServices(BuildContext context) async {
  final scope = AppScope.of(context);
  final l = AppLocalizations.of(context);
  Haptics.strong();
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: emergencyNumber));
  } catch (_) {}
  if (!opened) {
    scope.feedback.toast(l.cannotCall, icon: Icons.phone_disabled_outlined);
  }
}
