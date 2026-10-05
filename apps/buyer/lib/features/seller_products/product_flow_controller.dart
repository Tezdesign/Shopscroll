import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shopscroll_shared/models/ids.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product_draft.dart';

import '../../data/repositories/seller_product_repository.dart';
import 'variant_options.dart';

/// Where one photo of the draft is in its upload (spec 0015, AC-5).
enum PhotoStatus { uploading, done, failed }

/// One photo in the draft. [bytes] are kept while the phone still has them, so
/// the picture shows at once and a failed upload can be tried again. [path] is
/// the storage path once uploaded.
class PhotoItem {
  const PhotoItem({
    required this.id,
    this.path,
    this.bytes,
    required this.status,
  });

  final String id;
  final String? path;
  final Uint8List? bytes;
  final PhotoStatus status;

  PhotoItem copyWith({String? path, PhotoStatus? status}) => PhotoItem(
    id: id,
    path: path ?? this.path,
    bytes: bytes,
    status: status ?? this.status,
  );
}

enum SaveStatus { idle, saving, saved, failed }

/// How a Publish tap ended.
sealed class PublishResult {
  const PublishResult();
}

class Published extends PublishResult {
  const Published(this.productId);
  final String productId;
}

/// Something has to be fixed first. [issues] use the `save_product` codes.
class PublishRefused extends PublishResult {
  const PublishRefused(this.issues);
  final List<DraftIssue> issues;
}

/// A photo failed and the seller has to retry or remove it.
class PublishPhotoFailed extends PublishResult {
  const PublishPhotoFailed();
}

/// The phone could not reach the server. Nothing was lost.
class PublishNetworkFailed extends PublishResult {
  const PublishNetworkFailed();
}

/// The seller left the flow while it waited for photos, so nothing was
/// published (spec 0015, AC-8).
class PublishCancelled extends PublishResult {
  const PublishCancelled();
}

/// The state of the add or edit product flow, owned by its screen
/// (spec 0015). It holds the draft, saves it a little after the seller stops
/// typing, uploads photos in the background and publishes.
class ProductFlowController extends ChangeNotifier {
  ProductFlowController({
    required this.repository,
    required ProductDraft draft,
    required bool persisted,
    this.autosaveDelay = const Duration(seconds: 2),
    // ignore: prefer_initializing_formals
  }) : _draft = draft,
       // ignore: prefer_initializing_formals
       _persisted = persisted {
    // A product always has a row to price. Without options it is the one
    // plain row (spec 0015, AC-4).
    if (draft.data.variants.isEmpty) {
      _draft = draft.copyWith(
        data: draft.data.copyWith(
          variants: [DraftVariant(id: newUuid(), stockSet: true)],
        ),
      );
    }
    _photos = [
      for (final path in draft.data.photos)
        PhotoItem(id: newUuid(), path: path, status: PhotoStatus.done),
    ];
    _optionsEnabled = draft.data.hasOptions;
    _defaultPrice = draft.data.variants.isEmpty
        ? ''
        : draft.data.variants.first.price;
  }

  final SellerProductRepository repository;
  final Duration autosaveDelay;

  ProductDraft _draft;
  bool _persisted;
  late List<PhotoItem> _photos;
  late bool _optionsEnabled;
  late String _defaultPrice;

  Timer? _timer;
  bool _dirty = false;
  Future<void>? _saveFuture;
  bool _disposed = false;
  SaveStatus _saveStatus = SaveStatus.idle;
  bool _publishing = false;
  final List<Completer<void>> _uploadWaiters = [];
  final Set<int> _attemptedSteps = {};
  int _bulkRevision = 0;
  int _fieldRevision = 0;

  ProductDraft get draft => _draft;
  ProductDraftData get data => _draft.data;
  int get step => _draft.step;
  List<PhotoItem> get photos => List.unmodifiable(_photos);
  SaveStatus get saveStatus => _saveStatus;
  bool get publishing => _publishing;
  bool get optionsEnabled => _optionsEnabled;
  String get defaultPrice => _defaultPrice;

  /// Goes up when text fields change from outside (an accepted suggestion), so
  /// the fields on screen know to show the new text.
  int get fieldRevision => _fieldRevision;

  /// Goes up whenever many rows change at once (default price, set all, copy
  /// down), so a row's text fields know to show the new values.
  int get bulkRevision => _bulkRevision;
  List<DraftVariant> get variants => data.variants;
  List<ColorOption> get colors => colorsOf(data.variants);
  List<String> get sizes => sizesOf(data.variants);

  int get uploadingCount =>
      _photos.where((p) => p.status == PhotoStatus.uploading).length;
  bool get hasFailedPhoto =>
      _photos.any((p) => p.status == PhotoStatus.failed);

  /// Set once a step's Continue was tapped with something missing, so that
  /// step starts showing what is missing.
  bool attempted(int step) => _attemptedSteps.contains(step);

  /// What is still missing for one step (1 Basics, 2 Price and stock), or for
  /// everything on step 3.
  List<DraftIssue> issuesFor(int step) {
    const basics = {'bad_title', 'bad_category', 'no_photo', 'too_many_photos'};
    const money = {
      'no_variants',
      'too_many_variants',
      'missing_price',
      'bad_stock',
      'duplicate_variant',
    };
    final all = data.issues();
    return switch (step) {
      1 => all.where((i) => basics.contains(i.code)).toList(),
      2 => all.where((i) => money.contains(i.code)).toList(),
      _ => all,
    };
  }

  /// Marks the step as tried and says whether it can be left. Photos still
  /// uploading do not block moving on, Publish waits for them.
  bool tryContinue(int step) {
    final ok = issuesFor(step).isEmpty && !hasFailedPhoto;
    if (!ok) {
      _attemptedSteps.add(step);
      notifyListeners();
    }
    return ok;
  }

  // ----- Fields ----------------------------------------------------------

  /// Makes sure the draft exists on the server and is up to date, and waits.
  /// "Fill from photos" needs the draft row to find its photos.
  Future<void> ensureSaved() {
    _dirty = true;
    return flush();
  }

  /// Applies the parts of a suggestion the seller accepted (spec 0015, AC-13).
  /// Empty values are skipped. Colors turn the options on and add one color
  /// each; the seller reviews them on the next step.
  void applyAutofill({
    String? title,
    String? description,
    String? category,
    String? material,
    List<ColorOption> colors = const [],
  }) {
    _fieldRevision++;
    _draft = _draft.copyWith(
      data: _draft.data.copyWith(
        title: (title != null && title.trim().isNotEmpty) ? title.trim() : null,
        description: (description != null && description.trim().isNotEmpty)
            ? description.trim()
            : null,
        category: (category != null && category.isNotEmpty) ? category : null,
      ),
    );
    if (material != null && material.trim().isNotEmpty) {
      setAttribute('material', material.trim());
    }
    if (colors.isNotEmpty) {
      setOptionsEnabled(true);
      for (final color in colors) {
        addColor(color);
      }
    }
    _touch();
  }

  void setStep(int step) {
    _draft = _draft.copyWith(step: step);
    _touch();
  }

  void setTitle(String value) => _update((d) => d.copyWith(title: value));
  void setDescription(String value) =>
      _update((d) => d.copyWith(description: value));
  void setCategory(String value) => _update((d) => d.copyWith(category: value));

  /// An empty value removes the key.
  void setAttribute(String key, String value) {
    final next = {...data.attributes};
    if (value.trim().isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    _update((d) => d.copyWith(attributes: next));
  }

  void _update(ProductDraftData Function(ProductDraftData) change) {
    _draft = _draft.copyWith(data: change(_draft.data));
    _touch();
  }

  // ----- Photos ----------------------------------------------------------

  /// Adds photos (already shrunk to JPEG) up to the limit and uploads them in
  /// the background. Returns how many were left out for lack of room.
  int addPhotos(List<Uint8List> jpegs) {
    final room = ProductDraftData.maxPhotos - _photos.length;
    final taken = jpegs.take(room < 0 ? 0 : room).toList();
    for (final bytes in taken) {
      final item = PhotoItem(
        id: newUuid(),
        bytes: bytes,
        status: PhotoStatus.uploading,
      );
      _photos.add(item);
      unawaited(_upload(item.id));
    }
    notifyListeners();
    return jpegs.length - taken.length;
  }

  Future<void> _upload(String photoId) async {
    final index = _photos.indexWhere((p) => p.id == photoId);
    if (index < 0) return;
    final bytes = _photos[index].bytes;
    if (bytes == null) return;
    try {
      final path = await repository.uploadPhoto(_draft.id, bytes);
      final at = _photos.indexWhere((p) => p.id == photoId);
      if (at < 0) {
        // Removed while uploading: the file is not wanted.
        unawaited(repository.deletePhoto(path));
      } else {
        _photos[at] = _photos[at].copyWith(
          path: path,
          status: PhotoStatus.done,
        );
        _syncPhotos();
      }
    } catch (_) {
      final at = _photos.indexWhere((p) => p.id == photoId);
      if (at >= 0) {
        _photos[at] = _photos[at].copyWith(status: PhotoStatus.failed);
      }
    }
    if (!_disposed) notifyListeners();
    _releaseWaiters();
  }

  void retryPhoto(String photoId) {
    final at = _photos.indexWhere((p) => p.id == photoId);
    if (at < 0 || _photos[at].status != PhotoStatus.failed) return;
    _photos[at] = _photos[at].copyWith(status: PhotoStatus.uploading);
    notifyListeners();
    unawaited(_upload(photoId));
  }

  void removePhoto(String photoId) {
    final at = _photos.indexWhere((p) => p.id == photoId);
    if (at < 0) return;
    final removed = _photos.removeAt(at);
    final path = removed.path;
    if (path != null) {
      // Only a photo this draft added is deleted. A live product's own photos
      // stay in storage until the edit is saved.
      if (path.contains('/${_draft.id}/')) {
        unawaited(repository.deletePhoto(path));
      }
      _update(
        (d) => d.copyWith(
          variants: [
            for (final v in d.variants)
              v.imagePath == path ? v.copyWith(clearImagePath: true) : v,
          ],
        ),
      );
    }
    _syncPhotos();
    _releaseWaiters();
    notifyListeners();
  }

  /// Moves a photo. Index 0 is the cover.
  void movePhoto(int from, int to) {
    if (from < 0 || from >= _photos.length) return;
    final target = to.clamp(0, _photos.length - 1);
    final item = _photos.removeAt(from);
    _photos.insert(target, item);
    _syncPhotos();
    notifyListeners();
  }

  void setCover(int index) => movePhoto(index, 0);

  void _syncPhotos() {
    final paths = [
      for (final p in _photos)
        if (p.status == PhotoStatus.done && p.path != null) p.path!,
    ];
    _update((d) => d.copyWith(photos: paths));
  }

  Future<void> _waitForUploads() async {
    while (uploadingCount > 0 && !_disposed) {
      final waiter = Completer<void>();
      _uploadWaiters.add(waiter);
      await waiter.future;
    }
  }

  void _releaseWaiters({bool force = false}) {
    if (!force && uploadingCount > 0) return;
    for (final w in _uploadWaiters) {
      if (!w.isCompleted) w.complete();
    }
    _uploadWaiters.clear();
  }

  // ----- Price, stock and options ------------------------------------------

  /// Turns the colors and sizes editor on or off. Off leaves the one plain
  /// row, keeping the price and stock of the first row.
  void setOptionsEnabled(bool enabled) {
    _optionsEnabled = enabled;
    if (!enabled) {
      _update(
        (d) => d.copyWith(
          variants: buildVariants(
            existing: d.variants,
            colors: const [],
            sizes: const [],
            defaultPrice: _defaultPrice,
          ),
        ),
      );
    } else {
      notifyListeners();
    }
  }

  /// Sets the price of every row that is empty or still at the old default,
  /// so a price typed on purpose for one row is kept.
  void setDefaultPrice(String value) {
    final old = _defaultPrice;
    _defaultPrice = value;
    _bulkRevision++;
    _update(
      (d) => d.copyWith(
        variants: [
          for (final v in d.variants)
            v.price.isEmpty || v.price == old ? v.copyWith(price: value) : v,
        ],
      ),
    );
  }

  void _rebuild({List<ColorOption>? colors, List<String>? sizes}) {
    _update(
      (d) => d.copyWith(
        variants: buildVariants(
          existing: d.variants,
          colors: colors ?? colorsOf(d.variants),
          sizes: sizes ?? sizesOf(d.variants),
          defaultPrice: _defaultPrice,
        ),
      ),
    );
  }

  void addColor(ColorOption color) {
    final current = colors;
    if (current.any((c) => c.value == color.value)) return;
    _rebuild(colors: [...current, color]);
  }

  void removeColor(int value) =>
      _rebuild(colors: colors.where((c) => c.value != value).toList());

  void toggleSize(String size) {
    final current = sizes;
    _rebuild(
      sizes: current.contains(size)
          ? current.where((s) => s != size).toList()
          : [...current, size],
    );
  }

  /// Returns false for an empty or too long name, or one already there.
  bool addCustomSize(String raw) {
    final size = raw.trim();
    if (size.isEmpty || size.length > 20 || sizes.contains(size)) return false;
    _rebuild(sizes: [...sizes, size]);
    return true;
  }

  void setVariantPrice(String id, String value) =>
      _changeVariant(id, (v) => v.copyWith(price: value));

  void setVariantStock(String id, int stock) => _changeVariant(
    id,
    (v) => v.copyWith(stock: stock < 0 ? 0 : stock, stockSet: true),
  );

  void setVariantSku(String id, String value) =>
      _changeVariant(id, (v) => v.copyWith(sku: value));

  void _changeVariant(String id, DraftVariant Function(DraftVariant) change) {
    _update(
      (d) => d.copyWith(
        variants: [for (final v in d.variants) v.id == id ? change(v) : v],
      ),
    );
  }

  void setAllPrices(String value) {
    _bulkRevision++;
    _update(
      (d) => d.copyWith(
        variants: [for (final v in d.variants) v.copyWith(price: value)],
      ),
    );
  }

  void setAllStock(int stock) {
    _bulkRevision++;
    _update(
      (d) => d.copyWith(
        variants: [
          for (final v in d.variants)
            v.copyWith(stock: stock < 0 ? 0 : stock, stockSet: true),
        ],
      ),
    );
  }

  /// Copies the price (or the stock) of row [index] onto the rows below it.
  void copyDown(int index, {required bool price}) {
    final rows = data.variants;
    if (index < 0 || index >= rows.length) return;
    final source = rows[index];
    _bulkRevision++;
    _update(
      (d) => d.copyWith(
        variants: [
          for (var i = 0; i < rows.length; i++)
            i <= index
                ? rows[i]
                : price
                ? rows[i].copyWith(price: source.price)
                : rows[i].copyWith(stock: source.stock, stockSet: true),
        ],
      ),
    );
  }

  /// Shows one of the product's photos for every row of a color (AC-5). A null
  /// path clears the link.
  void setColorPhoto(int colorValue, String? path) {
    _update(
      (d) => d.copyWith(
        variants: [
          for (final v in d.variants)
            v.colorValue == colorValue
                ? (path == null
                      ? v.copyWith(clearImagePath: true)
                      : v.copyWith(imagePath: path))
                : v,
        ],
      ),
    );
  }

  /// The photo linked to a color, taken from its first row.
  String? colorPhoto(int colorValue) {
    for (final v in data.variants) {
      if (v.colorValue == colorValue) return v.imagePath;
    }
    return null;
  }

  // ----- Saving ----------------------------------------------------------

  void _touch() {
    _dirty = true;
    if (_saveStatus == SaveStatus.saved || _saveStatus == SaveStatus.failed) {
      _saveStatus = SaveStatus.idle;
    }
    _timer?.cancel();
    _timer = Timer(autosaveDelay, () => unawaited(flush()));
    if (!_disposed) notifyListeners();
  }

  /// Saves now and waits for it. Safe to call often: calls made while a save
  /// runs share it and save again afterwards if something changed meanwhile.
  Future<void> flush() {
    _timer?.cancel();
    return _saveFuture ??= _runSaves().whenComplete(() => _saveFuture = null);
  }

  Future<void> _runSaves() async {
    while (_dirty && !_disposed) {
      _dirty = false;
      _saveStatus = SaveStatus.saving;
      notifyListeners();
      try {
        if (!_persisted) {
          final created = await repository.createDraft(
            id: _draft.id,
            sourceProductId: _draft.sourceProductId,
            data: _draft.data,
          );
          _persisted = true;
          _draft = _draft.copyWith(updatedAt: created.updatedAt);
        }
        // The row is made with the fields only, so the step is saved on top.
        await repository.saveDraft(_draft);
        _saveStatus = SaveStatus.saved;
      } catch (_) {
        _dirty = true;
        _saveStatus = SaveStatus.failed;
        if (!_disposed) notifyListeners();
        return;
      }
    }
    if (!_disposed) notifyListeners();
  }

  /// True once the draft exists on the server (or was opened from there).
  bool get persisted => _persisted;

  /// Removes the draft the seller chose to throw away.
  Future<void> discard() async {
    _timer?.cancel();
    _dirty = false;
    if (_persisted) await repository.deleteDraft(_draft.id);
    for (final p in _photos) {
      final path = p.path;
      if (!_persisted && path != null) {
        unawaited(repository.deletePhoto(path));
      }
    }
  }

  // ----- Publishing ------------------------------------------------------

  /// Waits for photos still uploading, saves, and publishes (spec 0015, AC-7
  /// and AC-8). Leaving the flow while it waits cancels it.
  Future<PublishResult> publish() async {
    _publishing = true;
    notifyListeners();
    try {
      await _waitForUploads();
      if (_disposed) return const PublishCancelled();
      if (hasFailedPhoto) return const PublishPhotoFailed();
      final issues = data.issues();
      if (issues.isNotEmpty) return PublishRefused(issues);

      _dirty = true;
      await flush();
      if (_saveStatus == SaveStatus.failed) {
        return const PublishNetworkFailed();
      }
      try {
        final id = await repository.publish(_draft.id);
        return Published(id);
      } on SellerProductException catch (error) {
        return PublishRefused([DraftIssue(error.code, error.variantId)]);
      } catch (_) {
        return const PublishNetworkFailed();
      }
    } finally {
      _publishing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// The lowest price of the rows, formatted, for the preview.
  String? previewPriceLabel(String currency) {
    final lowest = data.lowestPrice;
    return lowest == null ? null : Money.format(lowest, currency);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _releaseWaiters(force: true);
    // A change not yet saved is sent on the way out, best effort.
    if (_dirty) unawaited(_flushOnExit());
    super.dispose();
  }

  Future<void> _flushOnExit() async {
    try {
      if (!_persisted) {
        await repository.createDraft(
          id: _draft.id,
          sourceProductId: _draft.sourceProductId,
          data: _draft.data,
        );
      }
      await repository.saveDraft(_draft);
    } catch (_) {
      // Nothing more can be done once the screen is gone.
    }
  }
}
