import 'dart:convert';
import 'dart:io';
import 'package:resilience/core/event_factory.dart';
import 'package:resilience/core/lamport_clock.dart';
import 'package:resilience/core/signing.dart';
import 'package:resilience/gen/resilience/v1/event.pb.dart';

/// Generates a Dart-signed SignedEvent and writes it as base64 JSON so the Go
/// verifier can prove cross-language agreement on the BLAKE2b content hash and
/// Ed25519 signature over the canonical preimages.
Future<void> main() async {
  final signer = Signer();
  final seed = List<int>.generate(32, (i) => i + 1);
  final kp = await signer.keyPairFromSeed(seed);
  final clock = LamportClock();
  final body = ResourceBody(
    resourceId: 'xlang-1',
    category: ResourceCategory.RESOURCE_CATEGORY_WATER,
    title: 'Water available',
    amount: AmountBand.AMOUNT_BAND_PLENTY,
    availability: Availability.AVAILABILITY_NOW,
    provenance: ProvenanceKind.PROVENANCE_KIND_COMMUNITY,
  );
  final ev = await EventFactory(signer: signer).buildFromMessage(
    keyPair: kp,
    clock: clock,
    type: EventType.EVENT_TYPE_RESOURCE_CREATED,
    body: body,
  );
  final bytes = ev.writeToBuffer();
  final out = {
    'event_b64': base64.encode(bytes),
    'pub_b64': base64.encode(kp.publicKey),
    'event_id_hex':
        ev.header.eventId.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
  };
  final f = File('/projects/sandbox/.toolchain/xlang/vector.json');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(jsonEncode(out));
  // ignore: avoid_print
  print('wrote vector id=${out['event_id_hex']}');
}
