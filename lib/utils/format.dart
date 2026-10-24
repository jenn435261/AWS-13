import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

String clockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

IconData batteryIcon(int? percent) {
  if (percent == null) return Icons.power;
  if (percent < 20) return Icons.battery_alert;
  return Icons.battery_std;
}

const _distance = Distance();

double metersBetween(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);
