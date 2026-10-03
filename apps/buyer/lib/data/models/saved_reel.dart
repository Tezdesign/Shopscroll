import 'package:shopscroll_shared/models/reel.dart';

/// A reel the buyer saved (spec 0008): the [Reel] plus the time it was
/// saved, which orders the My collection list. Unavailable reels are kept,
/// so the buyer can still clear them.
class SavedReel {
  const SavedReel(this.reel, this.savedAt);

  final Reel reel;
  final DateTime savedAt;
}
