import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopscroll_shared/theme/app_theme.dart';
import 'package:marketplace_app/data/mock/mock_cart_items.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import 'package:marketplace_app/data/models/order.dart';
import 'package:marketplace_app/data/models/place_order_request.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';
import 'package:shopscroll_shared/models/user_profile.dart';
import 'package:marketplace_app/data/providers/cart_providers.dart';
import 'package:marketplace_app/data/providers/checkout_providers.dart';
import 'package:marketplace_app/data/providers/network_delay.dart';
import 'package:marketplace_app/data/repositories/cart_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_cart_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_order_repository.dart';
import 'package:marketplace_app/data/repositories/mock/mock_user_profile_repository.dart';
import 'package:marketplace_app/data/repositories/order_repository.dart';
import 'package:marketplace_app/data/repositories/repository_providers.dart';
import 'package:marketplace_app/features/cart/cart_logic.dart';
import 'package:marketplace_app/features/checkout/checkout_logic.dart';
import 'package:marketplace_app/features/checkout/checkout_screen.dart';
import 'package:marketplace_app/features/checkout/order_confirmation_screen.dart';
import 'package:shopscroll_shared/widgets/app_button.dart';
import 'package:marketplace_app/shared/widgets/shipping_items_section.dart';

/// An order repository that counts calls and can fail or wait.
class _Orders extends MockOrderRepository {
  _Orders({super.cart, this.failWith});

  final PlaceOrderFailure? failWith;
  int calls = 0;

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async {
    calls++;
    if (failWith != null) throw PlaceOrderException(failWith!);
    return super.placeOrder(request);
  }
}

class _Profiles extends MockUserProfileRepository {
  _Profiles(this.profile);

  final UserProfile profile;

  @override
  Future<UserProfile?> getUserProfileById(String id) async => profile;
}

/// A cart that starts empty.
class _EmptyCart extends MockCartRepository {
  @override
  Future<List<Never>> getCartItems() async => const [];
}

void main() {
  const contact = ContactInfo(
    name: 'Moetez ben attia',
    email: 'moetez@example.com',
    phone: '+21650460604',
  );
  const address = ShippingAddress(
    city: 'menzah V',
    address: '18 rue des bonbons',
    zip: '0000',
    note: 'Next to the bank',
  );

  Future<GoRouter> open(
    WidgetTester tester, {
    CartRepository? cartRepo,
    OrderRepository Function(CartRepository cart)? orders,
    String? signedInUserId,
    UserProfile? profile,
  }) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final theCart = cartRepo ?? MockCartRepository();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home page')),
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const Scaffold(body: Text('Cart page')),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) =>
              CheckoutScreen(signedInUserId: signedInUserId),
        ),
        GoRoute(
          path: '/order-confirmation/:id',
          builder: (context, state) =>
              OrderConfirmationScreen(orderId: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartRepositoryProvider.overrideWithValue(theCart),
          orderRepositoryProvider.overrideWithValue(
            orders?.call(theCart) ?? MockOrderRepository(cart: theCart),
          ),
          if (profile != null)
            userProfileRepositoryProvider.overrideWithValue(_Profiles(profile)),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump(mockNetworkDelay);
    await tester.pump();
    return router;
  }

  CheckoutDraftNotifier draft(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(CheckoutScreen)),
  ).read(checkoutDraftProvider.notifier);

  void fillDraft(WidgetTester tester, {PaymentMethod? payment}) {
    draft(tester)
      ..setContact(contact)
      ..setAddress(address)
      ..setDeliveryMethod(DeliveryMethod.standard)
      ..setPaymentMethod(payment ?? PaymentMethod.cashOnDelivery);
  }

  /// Lets the mock repositories' delays run: an order takes several in a row.
  Future<void> waitForBackend(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(mockNetworkDelay);
    }
    await tester.pump();
  }

  /// The widget a screen reader would announce with this label. Matches the
  /// Semantics widgets directly, so it does not need the semantics tree on.
  Finder labelled(String label) => find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );

  /// The text fields inside the open sheet, not the discount field behind it.
  Finder sheetFields() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(TextField),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  bool placeOrderEnabled(WidgetTester tester) => tester
      .widget<AppButton>(find.widgetWithText(AppButton, 'Place order'))
      .enabled;

  final subtotal = cartTotal(mockCartItems);

  testWidgets('shows the six sections in order, and Place order is disabled '
      '(AC-2, AC-10)', (tester) async {
    await open(tester);

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.byType(ShippingItemsSection), findsOneWidget);
    for (final title in [
      'Contact information',
      'Delivery address',
      'Delivery Method',
      'Order Summary',
      'Payment method',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    final positions = [
      'Shipping items',
      'Contact information',
      'Delivery address',
      'Delivery Method',
      'Order Summary',
      'Payment method',
    ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
    expect(positions, orderedEquals([...positions]..sort()));

    expect(find.text('Add your contact info'), findsOneWidget);
    expect(find.text('Add your address'), findsOneWidget);
    expect(placeOrderEnabled(tester), isFalse);
  });

  testWidgets('Shipping items starts expanded and lists the cart lines '
      '(AC-2)', (tester) async {
    await open(tester);

    expect(find.text('x1'), findsWidgets);
    expect(find.text(mockCartItems.first.product.title), findsOneWidget);
  });

  testWidgets('the contact sheet checks the fields, then fills the section '
      '(AC-3, AC-4)', (tester) async {
    await open(tester);

    await tester.tap(find.text('Add your contact info'));
    await settle(tester);
    expect(find.text('Enter your full name'), findsOneWidget);

    // Empty fields: messages under them and the sheet stays open.
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Please enter your full name.'), findsOneWidget);
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Please enter a valid phone number.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    final fields = sheetFields();
    await tester.enterText(fields.at(0), 'Moetez ben attia');
    await tester.enterText(fields.at(1), 'moetez@example.com');
    await tester.enterText(fields.at(2), '50460604');
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('Enter your full name'), findsNothing);
    expect(find.text('Moetez ben attia'), findsOneWidget);
    expect(find.text('moetez@example.com'), findsOneWidget);
    expect(find.text('+21650460604'), findsOneWidget);
    expect(find.text('Add your contact info'), findsNothing);

    // The pencil reopens the sheet holding the values.
    await tester.tap(labelled('Edit contact information'));
    await settle(tester);
    expect(find.text('Moetez ben attia'), findsWidgets);
    expect(find.text('50460604'), findsOneWidget);
  });

  testWidgets('closing the contact sheet keeps the old values (AC-4)', (
    tester,
  ) async {
    await open(tester);
    draft(tester).setContact(contact);
    await tester.pump();

    await tester.tap(labelled('Edit contact information'));
    await settle(tester);
    await tester.enterText(sheetFields().at(0), 'Someone else');
    // The sheet's own close button, not the page's X behind it.
    await tester.tap(labelled('Close').last);
    await settle(tester);

    expect(find.text('Moetez ben attia'), findsOneWidget);
    expect(find.text('Someone else'), findsNothing);
  });

  testWidgets('the address sheet checks the fields, then fills the section '
      '(AC-6)', (tester) async {
    await open(tester);

    await tester.tap(find.text('Add your address'));
    await settle(tester);
    expect(find.text('Add current location'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Please enter your city.'), findsOneWidget);
    expect(find.text('Please enter your address.'), findsOneWidget);
    expect(find.text('Please enter a valid zip code.'), findsOneWidget);

    final fields = sheetFields();
    await tester.enterText(fields.at(0), 'menzah V');
    await tester.enterText(fields.at(1), '18 rue des bonbons');
    await tester.enterText(fields.at(2), '0000');
    await tester.enterText(fields.at(3), 'Next to the bank');
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('Tunisia'), findsOneWidget);
    expect(find.text('18 rue des bonbons, menzah V, 0000'), findsOneWidget);
    expect(find.text('Next to the bank'), findsOneWidget);
    expect(find.text('Add your address'), findsNothing);
  });

  testWidgets('Add current location looks disabled and does nothing (AC-6)', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Add your address'));
    await settle(tester);

    await tester.tap(find.text('Add current location'));
    await tester.pump();

    expect(find.text('Shipping address'), findsOneWidget);
    expect(find.text('Enter your city'), findsOneWidget);
  });

  testWidgets('choosing a delivery type fills Delivery and Price to pay '
      '(AC-7, AC-8)', (tester) async {
    await open(tester);

    // Nothing chosen: the subtotal alone.
    expect(find.text('Not chosen'), findsOneWidget);
    expect(find.text(moneyLabel(subtotal)), findsNWidgets(2));

    await tester.tap(find.textContaining('Standard Delivery'));
    await tester.pump();
    expect(find.text(r'$10'), findsNWidgets(2));
    expect(find.text(moneyLabel(subtotal + 10)), findsOneWidget);

    await tester.tap(find.textContaining('Exclusive delivery'));
    await tester.pump();
    expect(find.text(moneyLabel(subtotal + 16)), findsOneWidget);
    expect(find.text('Not chosen'), findsNothing);
  });

  testWidgets('the discount field takes text but Apply does nothing (AC-8)', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Discount code'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, ''), 'SAVE15');
    final apply = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Apply'),
    );
    expect(apply.enabled, isFalse);
    await tester.tap(find.text('Apply'));
    await tester.pump();

    expect(find.textContaining('Discount from'), findsNothing);
    expect(find.text(moneyLabel(subtotal)), findsNWidgets(2));
  });

  testWidgets('payment shows both options and the card logos, none chosen '
      '(AC-9)', (tester) async {
    await open(tester);

    expect(find.text('Pay by Credit Card'), findsOneWidget);
    expect(find.text('Pay on delivery'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('card_'),
      ),
      findsNWidgets(4),
    );
    // No card fields anywhere (AC-24).
    expect(find.textContaining('Card number'), findsNothing);
    expect(find.textContaining('CVV'), findsNothing);
  });

  testWidgets('Place order turns on only when all four parts are set '
      '(AC-10)', (tester) async {
    await open(tester);

    draft(tester).setContact(contact);
    await tester.pump();
    expect(placeOrderEnabled(tester), isFalse);
    draft(tester).setAddress(address);
    draft(tester).setDeliveryMethod(DeliveryMethod.exclusive);
    await tester.pump();
    expect(placeOrderEnabled(tester), isFalse);
    draft(tester).setPaymentMethod(PaymentMethod.cashOnDelivery);
    await tester.pump();

    expect(placeOrderEnabled(tester), isTrue);
  });

  testWidgets('card chosen: Place order says coming soon and creates nothing '
      '(AC-11)', (tester) async {
    late _Orders orders;
    await open(tester, orders: (cart) => orders = _Orders(cart: cart));
    fillDraft(tester, payment: PaymentMethod.card);
    await tester.pump();

    await tester.tap(find.text('Place order'));
    await tester.pump();

    expect(find.text('Card payment is coming soon'), findsOneWidget);
    expect(orders.calls, 0);
    expect(find.text('Order Confirmation'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Pay on delivery places one order, opens the confirmation and '
      'empties the cart (AC-12, AC-16)', (tester) async {
    late _Orders orders;
    await open(tester, orders: (cart) => orders = _Orders(cart: cart));
    fillDraft(tester);
    await tester.pump();

    // Five quick taps make one order.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Place order'), warnIfMissed: false);
    }
    await tester.pump();
    expect(find.text('Placing order'), findsOneWidget);
    await waitForBackend(tester);

    expect(orders.calls, 1);
    expect(find.text('Order Confirmation'), findsOneWidget);
    expect(find.text('Order#000001 is confirmed'), findsOneWidget);
    expect(find.text('Thank you for your order, Moetez!'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);

    // The cart provider was reloaded and is now empty.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OrderConfirmationScreen)),
    );
    await waitForBackend(tester, 3);
    expect(container.read(cartItemsProvider).value, isEmpty);
  });

  testWidgets('a failed order keeps the form and the cart, and the button '
      'works again (AC-13)', (tester) async {
    late _Orders orders;
    await open(
      tester,
      orders: (cart) =>
          orders = _Orders(cart: cart, failWith: PlaceOrderFailure.failed),
    );
    fillDraft(tester);
    await tester.pump();

    await tester.tap(find.text('Place order'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't place your order. Try again."), findsOneWidget);
    expect(find.text('Moetez ben attia'), findsOneWidget);
    expect(find.text('Checkout'), findsOneWidget);
    expect(placeOrderEnabled(tester), isTrue);
    expect(orders.calls, 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('changed items say so and reload the cart (AC-13)', (
    tester,
  ) async {
    await open(
      tester,
      orders: (cart) =>
          _Orders(cart: cart, failWith: PlaceOrderFailure.itemsChanged),
    );
    fillDraft(tester);
    await tester.pump();

    await tester.tap(find.text('Place order'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Some items changed. Check your cart.'), findsOneWidget);
    await waitForBackend(tester, 2);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('X with nothing entered goes back at once (AC-14)', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(labelled('Close'));
    await settle(tester);

    expect(find.text('Discard your details?'), findsNothing);
    expect(find.text('Cart page'), findsOneWidget);
  });

  testWidgets('X with something entered asks first (AC-14)', (tester) async {
    await open(tester);
    draft(tester).setDeliveryMethod(DeliveryMethod.standard);
    await tester.pump();

    await tester.tap(labelled('Close'));
    await settle(tester);
    expect(find.text('Discard your details?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.text('Discard your details?'), findsNothing);
    expect(find.text('Checkout'), findsOneWidget);

    await tester.tap(labelled('Close'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.text('Cart page'), findsOneWidget);
  });

  testWidgets('an empty cart shows the empty page and no form (AC-1)', (
    tester,
  ) async {
    await open(tester, cartRepo: _EmptyCart());

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Place order'), findsNothing);
    expect(find.text('Contact information'), findsNothing);

    await tester.tap(find.text('Back to cart'));
    await settle(tester);
    expect(find.text('Cart page'), findsOneWidget);
  });

  testWidgets('a signed in buyer with a full profile starts with the contact '
      'filled, and it is not counted as entered (AC-5, AC-14)', (tester) async {
    await open(
      tester,
      signedInUserId: 'user-1',
      profile: const UserProfile(
        id: 'user-1',
        name: 'Sara Ben Ali',
        username: 'sara',
        role: UserRole.buyer,
        email: 'sara@example.com',
        phone: '+21650460604',
      ),
    );
    await waitForBackend(tester, 2);

    expect(find.text('Sara Ben Ali'), findsOneWidget);
    expect(find.text('sara@example.com'), findsOneWidget);
    expect(find.text('Add your contact info'), findsNothing);
    // The address is never prefilled.
    expect(find.text('Add your address'), findsOneWidget);

    // Prefilled contact alone does not make the X ask.
    await tester.tap(labelled('Close'));
    await settle(tester);
    expect(find.text('Discard your details?'), findsNothing);
  });

  testWidgets('a signed in buyer with a partial profile gets the fields '
      'filled but the section stays empty (AC-5)', (tester) async {
    await open(
      tester,
      signedInUserId: 'user-1',
      profile: const UserProfile(
        id: 'user-1',
        name: 'Sara Ben Ali',
        username: 'sara',
        role: UserRole.buyer,
      ),
    );
    await waitForBackend(tester, 2);

    expect(find.text('Add your contact info'), findsOneWidget);
    await tester.tap(find.text('Add your contact info'));
    await settle(tester);

    expect(find.text('Sara Ben Ali'), findsOneWidget);
  });

  testWidgets('a signed out buyer starts empty (AC-5)', (tester) async {
    await open(tester);

    expect(find.text('Add your contact info'), findsOneWidget);
  });
}
