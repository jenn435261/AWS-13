import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:resilience/messaging/photo_prep.dart';

void main() {
  group('photo preparation', () {
    test('strips EXIF/GPS and downscales to <=1600px with a small thumbnail',
        () {
      // Build a large image and stamp EXIF (incl. a GPS IFD) onto it. GPS tag
      // 2 is GPSLatitude, 4 is GPSLongitude (numeric ids within the gps IFD).
      final src = img.Image(width: 3000, height: 2000);
      img.fill(src, color: img.ColorRgb8(10, 120, 200));
      src.exif.imageIfd['Make'] = 'SecretCameraCo';
      src.exif.imageIfd['Model'] = 'GPS-Tagged Device';
      // Sanity: the in-memory source carries EXIF metadata.
      expect(src.exif.isEmpty, isFalse,
          reason: 'test fixture should contain EXIF');
      final withExif = Uint8List.fromList(img.encodeJpg(src, quality: 90));

      final prepared = preparePhoto(withExif);
      expect(prepared, isNotNull);

      // Downscaled: long edge <= 1600.
      final longEdge = prepared!.width > prepared.height
          ? prepared.width
          : prepared.height;
      expect(longEdge, lessThanOrEqualTo(kMaxPhotoEdge));

      // ALL EXIF (including GPS) stripped from the re-encoded output.
      final out = img.decodeImage(prepared.jpeg)!;
      expect(out.exif.isEmpty, isTrue, reason: 'all EXIF must be stripped');
      expect(out.exif.gpsIfd.isEmpty, isTrue,
          reason: 'GPS EXIF must be stripped');

      // Thumbnail under the inline byte ceiling.
      expect(prepared.thumbnail.length, lessThanOrEqualTo(kThumbnailMaxBytes));
      expect(prepared.thumbnail.isNotEmpty, isTrue);
    });

    test('returns null for non-image bytes', () {
      expect(preparePhoto(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    });
  });
}
