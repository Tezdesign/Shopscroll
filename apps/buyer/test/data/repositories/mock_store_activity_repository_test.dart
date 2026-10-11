import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/store_order.dart';
import 'package:marketplace_app/data/repositories/mock/mock_store_activity_repository.dart';
import 'package:marketplace_app/data/repositories/store_activity_repository.dart';

// The mock must filter, search and page like `store_orders_list` (spec 0018,
// AC-15), so both backends behave the same to the screens.
void main() {
  late MockStoreActivityRepository repo;
  setUp(
    () => repo = MockStoreActivityRepository(now: DateTime.utc(2026, 5, 1)),
  );

  test(
    'lists newest first, 20 at a time, with no repeat across pages',
    () async {
      final first = await repo.listOrders();
      expect(first, hasLength(20));
      final second = await repo.listOrders(after: first.last.cursor);
      expect(second, hasLength(10));
      final ids = [...first, ...second].map((o) => o.orderId).toSet();
      expect(ids, hasLength(30));
      expect(first.first.orderNumber, greaterThan(first.last.orderNumber));
    },
  );

  test('a status chip keeps only that status', () async {
    final rows = await repo.listOrders(status: StoreOrderStatus.canceled);
    expect(rows, isNotEmpty);
    expect(rows.every((o) => o.status == StoreOrderStatus.canceled), isTrue);
  });

  test('search finds an order number with or without leading zeros', () async {
    final bare = await repo.listOrders(search: '2545');
    final padded = await repo.listOrders(search: '  002545 ');
    expect(bare.map((o) => o.orderId), contains('mock-order-002545'));
    expect(padded.map((o) => o.orderId), contains('mock-order-002545'));
  });

  test(
    'search by name ignores case and never matches a missing name',
    () async {
      final rows = await repo.listOrders(search: 'AMEL');
      expect(rows, isNotEmpty);
      expect(rows.every((o) => o.customerName == 'Amel Trabelsi'), isTrue);
      expect(await repo.listOrders(search: 'customer'), isEmpty);
    },
  );

  test('a percent sign is a plain character', () async {
    expect(await repo.listOrders(search: '%'), isEmpty);
  });

  test(
    'the detail agrees with the list and has no fee or whole total',
    () async {
      final row = (await repo.listOrders()).first;
      final detail = await repo.orderDetail(row.orderId);
      expect(detail.subtotal, row.total);
      expect(
        detail.lines.fold<double>(0, (sum, l) => sum + l.total),
        detail.subtotal,
      );
      expect(detail.customerName, row.customerName);
      expect(detail.deliveryMethod, 'standard');
    },
  );

  test('an order with no contact has no contact or delivery fields', () async {
    final rows = await repo.listOrders(limit: 50);
    final old = rows.firstWhere((o) => o.customerName == null);
    final detail = await repo.orderDetail(old.orderId);
    expect(detail.customerEmail, isNull);
    expect(detail.address, isNull);
    expect(detail.paymentMethod, isNull);
  });

  test('an unknown id is not_found', () async {
    expect(
      repo.orderDetail('nope'),
      throwsA(
        isA<StoreActivityException>().having(
          (e) => e.code,
          'code',
          'not_found',
        ),
      ),
    );
  });
}
