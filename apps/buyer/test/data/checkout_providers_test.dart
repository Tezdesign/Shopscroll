import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopscroll_shared/models/contact_info.dart';
import 'package:marketplace_app/data/models/place_order_request.dart';
import 'package:shopscroll_shared/models/shipping_address.dart';
import 'package:marketplace_app/data/providers/checkout_providers.dart';

void main() {
  const contact = ContactInfo(
    name: 'Sara Ben Ali',
    email: 'sara@example.com',
    phone: '+21650460604',
  );
  const address = ShippingAddress(
    city: 'Tunis',
    address: '13 Bahloul Street',
    zip: '1000',
  );

  ProviderContainer container() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Keep the auto disposed provider alive for the test.
    container.listen(checkoutDraftProvider, (previous, next) {});
    return container;
  }

  test('starts empty, untouched and incomplete', () {
    final draft = container().read(checkoutDraftProvider);

    expect(draft.contact, isNull);
    expect(draft.touched, isFalse);
    expect(draft.isComplete, isFalse);
  });

  test('is complete only with all four parts (AC-10)', () {
    final c = container();
    final notifier = c.read(checkoutDraftProvider.notifier);

    notifier.setContact(contact);
    notifier.setAddress(address);
    notifier.setDeliveryMethod(DeliveryMethod.standard);
    expect(c.read(checkoutDraftProvider).isComplete, isFalse);
    notifier.setPaymentMethod(PaymentMethod.cashOnDelivery);

    expect(c.read(checkoutDraftProvider).isComplete, isTrue);
    expect(c.read(checkoutDraftProvider).touched, isTrue);
  });

  test('a prefilled contact does not count as touched (AC-14)', () {
    final c = container();
    c.read(checkoutDraftProvider.notifier).prefillContact(contact);

    expect(c.read(checkoutDraftProvider).contact, contact);
    expect(c.read(checkoutDraftProvider).touched, isFalse);
  });

  test('a prefill never replaces a contact the buyer typed', () {
    final c = container();
    final notifier = c.read(checkoutDraftProvider.notifier);
    final typed = contact.copyWith(name: 'Typed Name');

    notifier.setContact(typed);
    notifier.prefillContact(contact);

    expect(c.read(checkoutDraftProvider).contact, typed);
  });

  test('the order id stays the same within one checkout (AC-12)', () {
    final c = container();
    final notifier = c.read(checkoutDraftProvider.notifier);
    final first = notifier.orderId;

    notifier.setContact(contact);

    expect(notifier.orderId, first);
    expect(first, isNotEmpty);
  });

  test('a new checkout starts clean with a new order id', () {
    final first = ProviderContainer();
    final second = ProviderContainer();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    first.listen(checkoutDraftProvider, (previous, next) {});
    second.listen(checkoutDraftProvider, (previous, next) {});

    first.read(checkoutDraftProvider.notifier).setContact(contact);

    expect(second.read(checkoutDraftProvider).contact, isNull);
    expect(
      second.read(checkoutDraftProvider.notifier).orderId,
      isNot(first.read(checkoutDraftProvider.notifier).orderId),
    );
  });
}
