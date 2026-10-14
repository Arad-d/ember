import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models.dart';
import 'package:ember/transaction_export.dart';
import 'package:ember/transaction_pdf.dart';
import 'package:ember/preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 13);
  final accounts = [
    const Account(id: 'a', name: 'Everyday bank', kind: 'Bank', opening: 0),
    const Account(
      id: 'u',
      name: 'Dollar account',
      kind: 'Bank',
      currency: 'USD',
      opening: 0,
    ),
  ];
  test(
    'PDF embeds Unicode fonts and paginates large reports in both calendars',
    () async {
      final entries = [
        for (var i = 0; i < 125; i++)
          Entry(
            id: 'e$i',
            title: i % 7 == 0 ? 'قهوه صبح ☕' : 'Daily expense $i with details',
            type: i % 9 == 0 ? 'income' : 'expense',
            category: 'Food & drink',
            accountId: i % 5 == 0 ? 'u' : 'a',
            amount: i % 5 == 0 ? 1250 : 120000,
            date: i == 124 ? DateTime(2026, 10, 14) : now,
          ),
      ];
      final snapshot = ExportSnapshot(
        accounts: accounts,
        entries: entries,
        now: now,
        connected: true,
        lastSync: DateTime(2026, 10, 13, 8, 30),
      );
      for (final calendar in AppCalendar.values) {
        final bytes = await buildTransactionPdf(
          snapshot,
          const ExportFilter(),
          calendar,
        );
        expect(bytes.take(4), [37, 80, 68, 70]);
        expect(bytes.length, greaterThan(15000));
        const output = String.fromEnvironment('EXPORT_ARTIFACT_DIR');
        if (output.isNotEmpty) {
          await Directory(output).create(recursive: true);
          await File(
            '$output/transactions-${calendar.name}.pdf',
          ).writeAsBytes(bytes);
        }
      }
    },
  );
  test(
    'Distributed font assets include full license and copyright notices',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(manifest.listAssets(), contains('assets/fonts/NOTO-LICENSE.txt'));
      final license = await rootBundle.loadString(
        'assets/fonts/NOTO-LICENSE.txt',
      );
      expect(license, contains('2017 Google Inc.'));
      expect(license, contains('2019-2021 Google LLC'));
      expect(license, contains('SIL OPEN FONT LICENSE Version 1.1'));
    },
  );
}
