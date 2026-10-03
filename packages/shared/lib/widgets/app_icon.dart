import 'package:flutter/material.dart';

/// Reproduces the Figma "Icons" component set (Design System-mobile,
/// node 443:2430): 32 glyphs used throughout the app.
///
/// Figma exports each glyph as its own short-lived image asset, which isn't
/// viable to embed permanently (same reasoning as the bottom nav bar icons),
/// so each glyph is mapped to the semantically-closest Material icon here —
/// one small registry instead of 32 separate widgets, since every instance
/// is really just "this glyph, at this size/color".
enum AppIconGlyph {
  edit,
  user,
  back,
  close,
  store,
  chat,
  filter,
  delivery,
  timer,
  add,
  web,
  location,
  cart,
  sortBy,
  report,
  view,
  check,
  email,
  phone,
  save,
  saveFilled,
  notAllowed,
  verifiedBadge,
  forward,
  chevronDown,
  upload,
  download,
  search,
  deals,
  category,
  name,
  document,
  logout,
  openExternal,
  delete,
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {super.key, this.size = 24, this.color});

  final AppIconGlyph glyph;
  final double size;
  final Color? color;

  static const Map<AppIconGlyph, IconData> _icons = {
    AppIconGlyph.edit: Icons.edit_outlined,
    AppIconGlyph.user: Icons.person_outline,
    AppIconGlyph.back: Icons.chevron_left,
    AppIconGlyph.close: Icons.close,
    AppIconGlyph.store: Icons.storefront_outlined,
    AppIconGlyph.chat: Icons.chat_bubble_outline,
    AppIconGlyph.filter: Icons.tune,
    AppIconGlyph.delivery: Icons.local_shipping_outlined,
    AppIconGlyph.timer: Icons.access_time,
    AppIconGlyph.add: Icons.add,
    AppIconGlyph.web: Icons.language,
    AppIconGlyph.location: Icons.location_on_outlined,
    AppIconGlyph.cart: Icons.shopping_cart_outlined,
    AppIconGlyph.sortBy: Icons.swap_vert,
    AppIconGlyph.report: Icons.warning_amber_rounded,
    AppIconGlyph.view: Icons.visibility_outlined,
    AppIconGlyph.check: Icons.check,
    AppIconGlyph.email: Icons.email_outlined,
    AppIconGlyph.phone: Icons.phone_outlined,
    AppIconGlyph.save: Icons.bookmark_border,
    AppIconGlyph.saveFilled: Icons.bookmark,
    AppIconGlyph.notAllowed: Icons.block,
    AppIconGlyph.verifiedBadge: Icons.verified_outlined,
    AppIconGlyph.forward: Icons.chevron_right,
    AppIconGlyph.chevronDown: Icons.keyboard_arrow_down,
    AppIconGlyph.upload: Icons.upload_outlined,
    AppIconGlyph.download: Icons.download_outlined,
    AppIconGlyph.search: Icons.search,
    AppIconGlyph.deals: Icons.local_offer_outlined,
    AppIconGlyph.category: Icons.category_outlined,
    AppIconGlyph.name: Icons.badge_outlined,
    AppIconGlyph.document: Icons.content_copy,
    AppIconGlyph.logout: Icons.logout,
    AppIconGlyph.openExternal: Icons.open_in_new,
    AppIconGlyph.delete: Icons.delete_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Icon(_icons[glyph], size: size, color: color);
  }
}
