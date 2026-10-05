
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum PhotoSourceChoice { camera, gallery }

/// Asks the person for photos and returns them as JPEG bytes ready to upload
/// (at most 1600 pixels on the longest side, under 2 MB). A provider so a test
/// can hand in fixed bytes without a camera.
typedef PhotoPicker =
    Future<List<Uint8List>> Function(PhotoSourceChoice source, {required int max});

final photoPickerProvider = Provider<PhotoPicker>((ref) => pickProductPhotos);

const maxPhotoSide = 1600;
const maxPhotoBytes = 2 * 1024 * 1024;

/// The real picker (spec 0015, AC-5). `image_picker` already shrinks to 1600
/// pixels and turns an iPhone HEIC into JPEG; [toUploadJpeg] covers what it
/// leaves as PNG or still too big.
Future<List<Uint8List>> pickProductPhotos(
  PhotoSourceChoice source, {
  required int max,
}) async {
  final picker = ImagePicker();
  final files = switch (source) {
    PhotoSourceChoice.camera => [
      await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxPhotoSide.toDouble(),
        maxHeight: maxPhotoSide.toDouble(),
        imageQuality: 85,
      ),
    ],
    PhotoSourceChoice.gallery => await picker.pickMultiImage(
      maxWidth: maxPhotoSide.toDouble(),
      maxHeight: maxPhotoSide.toDouble(),
      imageQuality: 85,
    ),
  };
  final out = <Uint8List>[];
  for (final file in files.whereType<XFile>().take(max)) {
    out.add(await toUploadJpeg(await file.readAsBytes()));
  }
  return out;
}

/// JPEG bytes under [maxPhotoSide] and [maxPhotoBytes] for any photo the
/// phone gave. A JPEG under the size limit passes through untouched (the
/// picker already shrank it to the side limit). Anything
/// else is decoded, shrunk and saved as JPEG on a background isolate. Throws
/// a [FormatException] for bytes that are not an image.
Future<Uint8List> toUploadJpeg(Uint8List bytes) async {
  if (_isJpeg(bytes) && bytes.length <= maxPhotoBytes) return bytes;
  return compute(_reencode, bytes);
}

bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

Uint8List _reencode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');
  var image = decoded;
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxPhotoSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxPhotoSide)
        : img.copyResize(image, height: maxPhotoSide);
  }
  var quality = 85;
  var out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  while (out.length > maxPhotoBytes && quality > 40) {
    quality -= 15;
    out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
  return out;
}
