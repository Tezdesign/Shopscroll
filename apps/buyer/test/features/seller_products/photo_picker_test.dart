import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:marketplace_app/features/seller_products/photo_picker.dart';

void main() {
  // Spec 0015, AC-5: every photo leaves the phone as a JPEG, 1600 pixels at most.
  test('a large PNG becomes a JPEG at most 1600 pixels wide', () async {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 3200, height: 1600)));

    final out = await toUploadJpeg(png);

    expect(out[0], 0xFF);
    expect(out[1], 0xD8);
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(out.length, lessThanOrEqualTo(maxPhotoBytes));
  });

  test('a tall PNG is limited on its height', () async {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 800, height: 2400)));

    final decoded = img.decodeJpg(await toUploadJpeg(png))!;

    expect(decoded.height, 1600);
    expect(decoded.width, lessThan(800));
  });

  test('a small JPEG passes through untouched', () async {
    final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 100, height: 100)));

    expect(await toUploadJpeg(jpg), same(jpg));
  });

  test('bytes that are not an image are refused', () async {
    await expectLater(toUploadJpeg(Uint8List.fromList([1, 2, 3, 4, 5])), throwsA(anything));
  });
}
