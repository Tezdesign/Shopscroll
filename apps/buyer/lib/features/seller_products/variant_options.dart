import 'package:shopscroll_shared/models/ids.dart';
import 'package:shopscroll_shared/models/product_draft.dart';

/// A color a seller can offer. [value] is the ARGB number stored with the
/// product, the same form as `Product.colorOptions`. These are product data
/// (what the item looks like), not interface colors, so they are not design
/// tokens (spec 0015, AC-4).
class ColorOption {
  const ColorOption(this.name, this.value);
  final String name;
  final int value;
}

/// The colors offered as one tap choices in the options editor.
const colorPalette = <ColorOption>[
  ColorOption('Black', 0xFF000000),
  ColorOption('White', 0xFFFFFFFF),
  ColorOption('Grey', 0xFF8E8E8E),
  ColorOption('Beige', 0xFFD9C3A5),
  ColorOption('Brown', 0xFF7A4B2A),
  ColorOption('Red', 0xFFD62828),
  ColorOption('Burgundy', 0xFF8C2F39),
  ColorOption('Pink', 0xFFF2A1C1),
  ColorOption('Orange', 0xFFF77F00),
  ColorOption('Yellow', 0xFFFFD60A),
  ColorOption('Green', 0xFF2D936C),
  ColorOption('Blue', 0xFF1E6FEB),
  ColorOption('Navy', 0xFF14213D),
];

/// Size presets: clothing letters and shoe numbers.
const letterSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
const shoeSizes = ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'];

/// The rows for the chosen colors and sizes, one per combination, colors
/// first (spec 0015, AC-4). A combination that already has a row keeps it, so
/// adding a size never wipes the prices typed so far. A new row starts with
/// [defaultPrice] and stock 0. With no colors and no sizes the result is the
/// one plain row of a product without options, reusing [existing] when there
/// is one.
List<DraftVariant> buildVariants({
  required List<DraftVariant> existing,
  required List<ColorOption> colors,
  required List<String> sizes,
  String defaultPrice = '',
}) {
  DraftVariant? find(int? color, String? size) {
    for (final v in existing) {
      if (v.colorValue == color && v.size == size) return v;
    }
    return null;
  }

  final colorList = colors.isEmpty ? <ColorOption?>[null] : colors;
  final sizeList = sizes.isEmpty ? <String?>[null] : sizes;
  final out = <DraftVariant>[];
  for (final color in colorList) {
    for (final size in sizeList) {
      final kept = find(color?.value, size);
      if (kept != null) {
        out.add(kept);
        continue;
      }
      // The plain row inherits the price and stock of the first old row, so
      // switching options off does not lose what was typed.
      final inherit = (color == null && size == null && existing.isNotEmpty)
          ? existing.first
          : null;
      out.add(
        DraftVariant(
          id: newUuid(),
          colorName: color?.name,
          colorValue: color?.value,
          size: size,
          price: inherit?.price ?? defaultPrice,
          stock: inherit?.stock ?? 0,
          stockSet: true,
        ),
      );
    }
  }
  return out;
}

/// The distinct colors in the rows, in order.
List<ColorOption> colorsOf(List<DraftVariant> variants) {
  final seen = <int>{};
  return [
    for (final v in variants)
      if (v.colorValue != null && seen.add(v.colorValue!))
        ColorOption(v.colorName ?? 'Color', v.colorValue!),
  ];
}

/// The distinct sizes in the rows, in order.
List<String> sizesOf(List<DraftVariant> variants) {
  final seen = <String>{};
  return [
    for (final v in variants)
      if (v.size != null && seen.add(v.size!)) v.size!,
  ];
}

/// "Burgundy / S", "S", "Burgundy" or "Standard" for a row.
String variantLabel(DraftVariant v) {
  final parts = [
    if (v.colorName != null) v.colorName!,
    if (v.colorName == null && v.colorValue != null) 'Color',
    if (v.size != null) v.size!,
  ];
  return parts.isEmpty ? 'Standard' : parts.join(' / ');
}
