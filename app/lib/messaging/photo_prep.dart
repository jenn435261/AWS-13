import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A photo prepared for secure sending: a re-encoded JPEG with EXIF (including
/// any GPS tags) stripped, plus a tiny inline thumbnail.
class PreparedPhoto {
  PreparedPhoto({
    required this.jpeg,
    required this.thumbnail,
    required this.width,
    required this.height,
  });

  /// Full-size re-encoded JPEG (<=1600px on the long edge), EXIF-free.
  final Uint8List jpeg;

  /// Tiny JPEG thumbnail (<=8KB) safe to embed inline in the E2E message.
  final Uint8List thumbnail;

  final int width;
  final int height;
}

/// Longest edge of a sent photo, per spec §6.
const int kMaxPhotoEdge = 1600;

/// Thumbnail longest edge.
const int kThumbnailEdge = 96;

/// Thumbnail hard byte ceiling (spec §6: <=8KB inline).
const int kThumbnailMaxBytes = 8 * 1024;

/// Decode [original] image bytes, STRIP all EXIF (including GPS coordinates),
/// downscale so the longest edge is <= [kMaxPhotoEdge], and re-encode as JPEG.
/// A small [PreparedPhoto.thumbnail] is produced for inline preview.
///
/// Privacy: re-encoding through a fresh [img.Image] drops every metadata tag,
/// so a photo's embedded GPS location never leaves the device. Returns null if
/// the bytes are not a decodable image.
PreparedPhoto? preparePhoto(Uint8List original, {int quality = 82}) {
  final decoded = img.decodeImage(original);
  if (decoded == null) return null;

  // Downscale the long edge to at most kMaxPhotoEdge.
  img.Image full = decoded;
  final longEdge = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longEdge > kMaxPhotoEdge) {
    if (decoded.width >= decoded.height) {
      full = img.copyResize(decoded, width: kMaxPhotoEdge);
    } else {
      full = img.copyResize(decoded, height: kMaxPhotoEdge);
    }
  }

  // Explicitly drop ALL metadata: copyResize/decodeImage carry EXIF forward,
  // so we clear it (and any ICC/text chunks) before encoding. This is what
  // strips embedded GPS coordinates and camera identifiers.
  full.exif = img.ExifData();
  full.iccProfile = null;
  full.textData?.clear();

  // Re-encode as JPEG from the metadata-free image.
  var jpeg = img.encodeJpg(full, quality: quality);
  // If still large, step the quality down to stay near the ~250KB target.
  var q = quality;
  while (jpeg.length > 250 * 1024 && q > 40) {
    q -= 12;
    jpeg = img.encodeJpg(full, quality: q);
  }

  // Thumbnail: small, and squeezed under the inline byte ceiling.
  final thumbSource = (full.width > full.height)
      ? img.copyResize(full, width: kThumbnailEdge)
      : img.copyResize(full, height: kThumbnailEdge);
  var tq = 70;
  var thumb = img.encodeJpg(thumbSource, quality: tq);
  while (thumb.length > kThumbnailMaxBytes && tq > 20) {
    tq -= 10;
    thumb = img.encodeJpg(thumbSource, quality: tq);
  }

  return PreparedPhoto(
    jpeg: Uint8List.fromList(jpeg),
    thumbnail: Uint8List.fromList(thumb),
    width: full.width,
    height: full.height,
  );
}
