import 'package:shopscroll_shared/models/product.dart';

/// A product the buyer saved (spec 0008): the [Product] plus the time it
/// was saved, which orders the My collection list. Not a table of its own,
/// `product_saves` only holds the ids and the time.
class SavedProduct {
  const SavedProduct(this.product, this.savedAt);

  final Product product;
  final DateTime savedAt;
}
