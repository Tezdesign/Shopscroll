import 'package:flutter/material.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:shopscroll_shared/widgets/search_field.dart';

import '../../data/repositories/chat_repository.dart';
import '../activity/messages_tab.dart';

/// The Messages tab of the seller shell at `/store/messages` (spec 0020, AC-1,
/// AC-9): one search field over the list of customers who wrote to the store,
/// newest first, with the unread ones in bold. The list is the buyer's
/// [MessagesTab] acting as the store, so paging, pull to refresh and the live
/// reload are the same code. The shell already restricts the area to sellers
/// ([SellerShell]).
///
/// Figma node 5667:8915 (Messages-inbox-seller) and 5667:8946 (empty).
/// Deviations: the status bar and tab bar are the phone's and the shell's; the
/// search filters the rows that are loaded, by customer name or last message.
class SellerInboxScreen extends StatefulWidget {
  const SellerInboxScreen({super.key});

  @override
  State<SellerInboxScreen> createState() => _SellerInboxScreenState();
}

class _SellerInboxScreenState extends State<SellerInboxScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white100,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.sm,
              ),
              child: SearchField(
                controller: _search,
                hintText: 'Search',
                onChanged: (text) => setState(() => _query = text),
              ),
            ),
            Expanded(
              child: MessagesTab(query: _query, role: ChatRole.store),
            ),
          ],
        ),
      ),
    );
  }
}
