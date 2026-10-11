import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/data/models/store_report.dart';
import 'package:marketplace_app/data/repositories/mock/mock_store_activity_repository.dart';
import 'package:marketplace_app/data/repositories/store_activity_repository.dart';

// The mock must filter, search and page like `store_reports_list` and resolve
// like `resolve_report` (spec 0018, AC-15), so both backends behave the same to
// the screens.
void main() {
  late MockStoreActivityRepository repo;
  setUp(() => repo = MockStoreActivityRepository(now: DateTime.now()));

  test(
    'lists newest first, 20 at a time, with no repeat across pages',
    () async {
      final first = await repo.listReports();
      expect(first, hasLength(20));
      final second = await repo.listReports(after: first.last.cursor);
      expect(second, hasLength(5));
      expect([...first, ...second].map((r) => r.id).toSet(), hasLength(25));
      expect(first.first.reportNumber, greaterThan(first.last.reportNumber));
    },
  );

  test(
    'a row carries the first product and how many products there are',
    () async {
      final rows = await repo.listReports();
      expect(rows.first.firstItemTitle, 'SoundPro Wireless Earbuds');
      expect(rows.first.itemCount, 1);
      expect(rows[1].itemCount, 3); // every third report holds three products
    },
  );

  test('a status keeps only that status', () async {
    final rows = await repo.listReports(status: StoreReportStatus.resolved);
    expect(rows, hasLength(6));
    expect(rows.every((r) => r.status == StoreReportStatus.resolved), isTrue);
  });

  test('search finds a report number with or without leading zeros', () async {
    final bare = await repo.listReports(search: '2589');
    final padded = await repo.listReports(search: '  02589 ');
    expect(bare.map((r) => r.id), contains('mock-report-2589'));
    expect(padded.map((r) => r.id), contains('mock-report-2589'));
  });

  test(
    'search by name or title ignores case, and never matches a missing name',
    () async {
      expect(await repo.listReports(search: 'EMILY'), isNotEmpty);
      expect(await repo.listReports(search: 'quality'), hasLength(20));
      expect(await repo.listReports(search: 'customer'), isEmpty);
      expect(await repo.listReports(search: '%'), isEmpty);
    },
  );

  test('the summary counts the reports and the returned orders', () async {
    final summary = await repo.reportsSummary();
    expect(summary.total, 25);
    expect(summary.unresolved, 19);
    expect(summary.returnedOrders, 3);
  });

  test(
    'resolving changes the row, the detail and the summary, and a repeat is a no op',
    () async {
      await repo.resolveReport('mock-report-2589');
      await repo.resolveReport('mock-report-2589');
      final row = (await repo.listReports()).first;
      expect(row.status, StoreReportStatus.resolved);
      final detail = await repo.reportDetail('mock-report-2589');
      expect(detail.status, StoreReportStatus.resolved);
      expect((await repo.reportsSummary()).unresolved, 18);
    },
  );

  test(
    'an unknown report is not_found for the detail and for resolve',
    () async {
      await expectLater(
        repo.reportDetail('nope'),
        throwsA(
          isA<StoreActivityException>().having(
            (e) => e.code,
            'code',
            'not_found',
          ),
        ),
      );
      await expectLater(
        repo.resolveReport('nope'),
        throwsA(
          isA<StoreActivityException>().having(
            (e) => e.code,
            'code',
            'not_found',
          ),
        ),
      );
    },
  );

  test('attachments get one link per path', () async {
    final detail = await repo.reportDetail('mock-report-2589');
    expect(detail.attachmentPaths, hasLength(2));
    expect(await repo.attachmentUrls(detail.attachmentPaths), hasLength(2));
    expect(await repo.attachmentUrls(const []), isEmpty);
  });
}
