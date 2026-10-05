import 'package:shopscroll_shared/models/product_draft.dart';

/// What the person reads for each reason code of `save_product` and of the
/// phone's own check (spec 0015, AC-7). One place, so a message is the same
/// whether it came from here or from the server.
String issueMessage(DraftIssue issue, {String? variantLabel}) {
  final row = variantLabel ?? 'a variant';
  return switch (issue.code) {
    'bad_title' => 'Give the product a title of 2 to 100 characters.',
    'bad_description' => 'The description is too long. Keep it under 2000 characters.',
    'bad_category' => 'Choose a category.',
    'no_photo' => 'Add at least one photo.',
    'too_many_photos' => 'A product can have 8 photos at most.',
    'bad_photo_path' => 'A photo could not be used. Remove it and add it again.',
    'no_variants' => 'Add a price and stock.',
    'too_many_variants' => 'A product can have 100 variants at most. Remove some sizes or colors.',
    'duplicate_variant' => 'Two rows have the same color and size.',
    'missing_price' => 'Enter a price above 0 for $row.',
    'bad_stock' => 'Stock for $row must be 0 or more.',
    'bad_sku' => 'A SKU, size or color name is too long.',
    'bad_attributes' => 'A detail is too long or empty.',
    'bad_price' => 'The price before discount is not valid.',
    'not_found' => 'This draft is no longer here. Start again from Add product.',
    'not_seller' || 'no_session' => 'Sign in as a store owner to publish.',
    _ => 'Something went wrong. Try again.',
  };
}

/// The step that holds the field behind an issue, so a "Fix" link can go there.
int stepFor(DraftIssue issue) => switch (issue.code) {
  'bad_title' ||
  'bad_category' ||
  'no_photo' ||
  'too_many_photos' ||
  'bad_photo_path' ||
  'bad_description' => 1,
  'bad_attributes' || 'bad_price' => 3,
  _ => 2,
};
