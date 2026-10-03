import 'package:flutter/material.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/coming_soon_screen.dart';

void main() {
  runApp(const SellerApp());
}

/// Empty seller app shell (spec 0011): starts with the shared theme and
/// nothing else. Seller features get their own scope rows and specs.
class SellerApp extends StatelessWidget {
  const SellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopscroll Seller',
      theme: AppTheme.light,
      home: const ComingSoonScreen(label: 'Seller app', icon: Icons.storefront),
    );
  }
}
