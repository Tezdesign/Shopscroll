import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/models/money.dart';
import 'package:shopscroll_shared/models/product.dart';
import 'package:shopscroll_shared/models/product_draft.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:shopscroll_shared/widgets/pill_tabs.dart';

import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/seller_product_repository.dart';
import 'flow_widgets.dart';
import 'product_messages.dart';
import 'quick_edit_sheet.dart';

/// The seller's Products list (spec 0015, AC-11): Live, Drafts, Out of stock
/// and Archived, 20 at a time, with a menu per row to edit, copy, archive or
/// delete. There is no Figma frame for it yet, so it is built from the
/// existing tokens and list patterns and should be checked against a design
/// when one exists.
class SellerProductsScreen extends ConsumerStatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  ConsumerState<SellerProductsScreen> createState() =>
      _SellerProductsScreenState();
}

const _tabLabels = ['Live', 'Drafts', 'Out of stock', 'Archived'];
const _pageSize = 20;

/// One tab's loaded rows. Products and drafts share the shape, only one list
/// is used per tab.
class _Page {
  List<Product> products = [];
  List<ProductDraft> drafts = [];
  bool loading = false;
  bool loaded = false;
  bool hasMore = true;
  bool failed = false;

  int get count => products.length + drafts.length;
}

class _SellerProductsScreenState extends ConsumerState<SellerProductsScreen> {
  int _tab = 0;
  final _pages = List.generate(_tabLabels.length, (_) => _Page());

  SellerProductRepository get _repo => ref.read(sellerProductRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load(_tab, reset: true);
  }

  SellerProductTab? _productTab(int tab) => switch (tab) {
    0 => SellerProductTab.live,
    2 => SellerProductTab.outOfStock,
    3 => SellerProductTab.archived,
    _ => null,
  };

  Future<void> _load(int tab, {bool reset = false}) async {
    final page = _pages[tab];
    if (page.loading) return;
    setState(() {
      page.loading = true;
      page.failed = false;
      if (reset) {
        page.products = [];
        page.drafts = [];
        page.hasMore = true;
      }
    });
    try {
      final productTab = _productTab(tab);
      if (productTab == null) {
        final rows = await _repo.listDrafts(offset: page.drafts.length, limit: _pageSize);
        page.drafts = [...page.drafts, ...rows];
        page.hasMore = rows.length == _pageSize;
      } else {
        final rows = await _repo.listProducts(
          productTab,
          offset: page.products.length,
          limit: _pageSize,
        );
        page.products = [...page.products, ...rows];
        page.hasMore = rows.length == _pageSize;
      }
      page.loaded = true;
    } catch (_) {
      page.failed = true;
    }
    if (mounted) setState(() => page.loading = false);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _refreshAll() {
    for (var i = 0; i < _pages.length; i++) {
      _pages[i].loaded = false;
    }
    _load(_tab, reset: true);
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      if (!mounted) return;
      if (done != null) _say(done);
      _refreshAll();
    } on SellerProductException catch (error) {
      if (mounted) _say(issueMessage(DraftIssue(error.code, error.variantId)));
    } catch (_) {
      if (mounted) _say("Couldn't do that. Check your connection and try again.");
    }
  }

  Future<void> _openEdit(String draftId) async {
    await context.push('/store/products/$draftId/edit');
    if (mounted) _refreshAll();
  }

  Future<void> _edit(Product product) async {
    try {
      final draft = await _repo.startEdit(product.id);
      if (mounted) await _openEdit(draft.id);
    } catch (_) {
      if (mounted) _say("Couldn't open this product. Try again.");
    }
  }

  Future<void> _similar(Product product) async {
    try {
      final draft = await _repo.createSimilar(product.id);
      if (mounted) await _openEdit(draft.id);
    } catch (_) {
      if (mounted) _say("Couldn't copy this product. Try again.");
    }
  }

  Future<void> _quickEdit(Product product) async {
    final changed = await showQuickEditSheet(context, product, _repo);
    if (changed == true && mounted) {
      _say('Saved');
      _refreshAll();
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action, style: const TextStyle(color: AppColors.error500)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_tab];
    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: FlowHeader(
                title: 'Products',
                onBack: () => context.canPop() ? context.pop() : context.go('/store'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: PillTabs(
                    labels: _tabLabels,
                    activeIndex: _tab,
                    onChanged: (index) {
                      setState(() => _tab = index);
                      if (!_pages[index].loaded) _load(index, reset: true);
                    },
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody(page)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: AppButton(
                  label: 'Add product',
                  leadingIcon: Icons.add,
                  onPressed: () async {
                    await context.push('/store/products/new');
                    if (mounted) _refreshAll();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(_Page page) {
    if (page.loading && page.count == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    if (page.failed && page.count == 0) {
      return _Message(
        title: "Couldn't load your products.",
        action: 'Try again',
        onAction: () => _load(_tab, reset: true),
      );
    }
    if (page.count == 0) {
      return _Message(
        title: switch (_tab) {
          0 => 'No live products yet.',
          1 => 'No drafts.',
          2 => 'Nothing is out of stock.',
          _ => 'No archived products.',
        },
        body: _tab == 0 ? 'Add a product to start selling.' : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(_tab, reset: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        children: [
          for (final draft in page.drafts)
            _DraftRow(
              draft: draft,
              onOpen: () => _openEdit(draft.id),
              onDelete: () async {
                if (await _confirm(
                  'Delete this draft?',
                  'It will be removed for good.',
                  'Delete',
                )) {
                  await _run(() => _repo.deleteDraft(draft.id), done: 'Draft deleted');
                }
              },
            ),
          for (final product in page.products)
            _ProductRow(
              product: product,
              onOpen: () => _edit(product),
              onQuickEdit: () => _quickEdit(product),
              onSimilar: () => _similar(product),
              onArchive: () => _run(
                () => _repo.setArchived(product.id, true),
                done: 'Archived. You can restore it from the Archived tab.',
              ),
              onRestore: () => _run(
                () => _repo.setArchived(product.id, false),
                done: 'Restored',
              ),
              onDelete: () async {
                if (await _confirm(
                  'Delete this product?',
                  'It will be removed for good.',
                  'Delete',
                )) {
                  await _run(() => _repo.deleteProduct(product.id), done: 'Product deleted');
                }
              },
            ),
          if (page.hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: page.loading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: 'Show more',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: () => _load(_tab),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body, this.action, this.onAction});

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: flowSectionStyle, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(body!, style: flowBodyStyle, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.base),
              AppButton(
                label: action!,
                size: AppButtonSize.small,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The price shown on a row: one price, or "from low to high" when the
/// variants differ.
String priceRangeLabel(Product product) {
  final prices = product.variants.map((v) => v.price).toList()..sort();
  if (prices.isEmpty || prices.first == prices.last) {
    return Money.format(prices.isEmpty ? product.price : prices.first, product.currency);
  }
  return '${Money.format(prices.first, product.currency)} to ${Money.format(prices.last, product.currency)}';
}

int totalStockOf(Product product) =>
    product.variants.fold(0, (sum, v) => sum + v.stock);

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onOpen,
    required this.onQuickEdit,
    required this.onSimilar,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onOpen;
  final VoidCallback onQuickEdit;
  final VoidCallback onSimilar;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final archived = product.status == ProductStatus.archived;
    final stock = totalStockOf(product);
    final out = !archived && !product.inStock;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 64,
                height: 64,
                child: product.imageUrl == null
                    ? const ColoredBox(color: AppColors.neutral200)
                    : Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const ColoredBox(color: AppColors.neutral200),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: flowLabelStyle,
                  ),
                  Text(priceRangeLabel(product), style: flowBodyStyle),
                  Text(
                    archived
                        ? 'Archived'
                        : out
                        ? 'Out of stock'
                        : '$stock in stock',
                    style: flowHelperStyle.copyWith(
                      color: out ? AppColors.error500 : AppColors.neutral900,
                      fontWeight: out ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More for ${product.title}',
              onSelected: (value) => switch (value) {
                'quick' => onQuickEdit(),
                'edit' => onOpen(),
                'similar' => onSimilar(),
                'archive' => onArchive(),
                'restore' => onRestore(),
                _ => onDelete(),
              },
              itemBuilder: (context) => [
                if (!archived)
                  const PopupMenuItem(value: 'quick', child: Text('Edit price and stock')),
                const PopupMenuItem(value: 'edit', child: Text('Edit product')),
                const PopupMenuItem(value: 'similar', child: Text('Create similar')),
                if (archived) ...[
                  const PopupMenuItem(value: 'restore', child: Text('Restore')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ] else
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.onOpen,
    required this.onDelete,
  });

  final ProductDraft draft;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final data = draft.data;
    final title = data.title.trim().isEmpty ? 'Untitled draft' : data.title.trim();
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 64,
                height: 64,
                child: data.photos.isEmpty
                    ? const ColoredBox(
                        color: AppColors.neutral200,
                        child: Icon(Icons.edit_outlined, color: AppColors.neutral600),
                      )
                    : PhotoImage(path: data.photos.first),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: flowLabelStyle,
                  ),
                  Text(
                    draft.isEdit ? 'Editing a live product' : 'Not published yet',
                    style: flowBodyStyle,
                  ),
                  Text(
                    'Step ${draft.step} of 3 · ${agoLabel(draft.updatedAt)}',
                    style: flowHelperStyle,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More for $title',
              onSelected: (value) => value == 'open' ? onOpen() : onDelete(),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'open', child: Text('Continue editing')),
                PopupMenuItem(value: 'delete', child: Text('Delete draft')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "just now", "5 min ago", "3 h ago" or "2 days ago".
String agoLabel(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  final days = diff.inDays;
  return days == 1 ? '1 day ago' : '$days days ago';
}
