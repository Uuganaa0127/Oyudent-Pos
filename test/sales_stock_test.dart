import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oyudent_pos/main.dart';

void main() {
  testWidgets(
    'One card per product; checkout preserves the selected zero-stock and stocked lines',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1500, 1100);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final posted = <Map<String, dynamic>>[];
      final stock = [
        for (var i = 0; i < 12; i++)
          {
            'product_id': 'p',
            'product_name': 'Ceramic Disc',
            'variant_id': 'variant-$i',
            'barcode': 'SCAN-$i-REF',
            'warehouse_id': 'w-$i',
            'warehouse_name': 'Warehouse $i',
            'unit_price': 100,
            'quantity': i == 1 ? 1 : 0,
            'in_invoice_id': i == 1
                ? 'receipt-1'
                : '00000000-0000-0000-0000-000000000000',
          },
        {
          'product_id': 'different-id',
          'product_name': 'Ceramic Disc',
          'variant_id': 'other',
          'warehouse_id': 'w-1',
          'quantity': 0,
          'in_invoice_id': '00000000-0000-0000-0000-000000000000',
        },
      ];
      for (final lot in ['A', 'B']) {
        stock.add({
          ...stock.first,
          'warehouse_id': 'w-annex',
          'warehouse_name': 'Annex',
          'lot_number': lot,
          'quantity': 1,
          'in_invoice_id': 'receipt-$lot',
        });
      }
      Future<http.Response> respond(http.Request r) async {
        final path = r.url.path.replaceFirst('/admin/api/v1', '');
        if (r.method == 'POST' && path == '/order/') {
          posted.add(jsonDecode(r.body));
          return http.Response(
            '{"status":"success","data":{"invoice_number":"demo"}}',
            200,
          );
        }
        final data = switch (path) {
          '/company/ref' => [
            {'id': 'c', 'name': 'Customer'},
          ],
          '/branch/ref' => [
            {'id': 'b', 'name': 'Branch'},
          ],
          '/ref-data/PRODUCT_CATEGORY' ||
          '/product/list' ||
          '/order/list' => [],
          '/order/get-available-stocks' => stock,
          _ => throw StateError(path),
        };
        return http.Response(jsonEncode({'data': data}), 200);
      }

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: PosShell(initialToken: 'fixture')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 бараа'), findsOneWidget);
        expect(find.text('Ceramic Disc'), findsNWidgets(2));
        expect(find.text('Үлдэгдэл: 3'), findsOneWidget);
        expect(find.text('12 хувилбар · 13 агуулах'), findsOneWidget);
        await tester.tap(find.text('Ceramic Disc').first);
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        await tester.enterText(
          find.descendant(of: dialog, matching: find.byType(TextFormField)),
          'SCAN-0-REF',
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ExpansionTile, 'SCAN-0-REF'),
          findsOneWidget,
        );
        if (find.text('Warehouse 0').evaluate().isEmpty) {
          await tester.tap(find.widgetWithText(ListTile, 'SCAN-0-REF'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Warehouse 0'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();

        final search = find.widgetWithText(TextField, 'Бараа хайх…');
        await tester.enterText(search, 'SCAN-0-REF');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ceramic Disc').first);
        await tester.pumpAndSettle();
        expect(find.text('Annex'), findsOneWidget);
        await tester.tap(find.text('Annex'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Лот: B ·'));
        await tester.pumpAndSettle();
        await tester.enterText(search, 'SCAN-1-REF');
        await tester.pumpAndSettle();
        expect(find.text('1 бараа'), findsOneWidget);
        await tester.tap(find.text('Ceramic Disc').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Төлбөрийн баримт'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(posted, hasLength(1));
        final items = posted.single['items'] as List;
        expect(items, hasLength(3));
        expect(items[1], containsPair('variantId', 'variant-0'));
        expect(items[1], containsPair('warehouseId', 'w-annex'));
        expect(items[1], containsPair('inInvoiceId', 'receipt-B'));
        expect(items.first, containsPair('productId', 'p'));
        expect(items.first, containsPair('variantId', 'variant-0'));
        expect(items.first, containsPair('warehouseId', 'w-0'));
        expect(items.first, containsPair('inInvoiceId', ''));
        expect(items.first, containsPair('quantity', 2));
        expect(items.last, containsPair('inInvoiceId', 'receipt-1'));
        expect(items.last, containsPair('warehouseId', 'w-1'));
      }, () => MockClient(respond));
    },
  );
  testWidgets(
    'A returned order accepts a positive quantity for a zero-stock warehouse variant',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1500, 1100);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final order = {
        'id': 'old',
        'branch_id': 'b',
        'company_id': 'c',
        'status_code': 'ORDER_STATUS_RETURNED',
        'invoice_number': 'original',
        'items': [],
        'total': 0,
        'tax': 0,
        'is_vat': false,
      };
      final posted = <Map<String, dynamic>>[];
      Future<http.Response> respond(http.Request r) async {
        final path = r.url.path.replaceFirst('/admin/api/v1', '');
        if (r.method == 'POST' && path == '/order/') {
          posted.add(jsonDecode(r.body));
          return http.Response('{"status":"success"}', 200);
        }
        final data = switch (path) {
          '/order/list' => [order],
          '/order/detail/old' => order,
          '/order/get-available-stocks' => [
            for (final location in ['w', 'other'])
              {
                'product_id': 'p',
                'variant_id': 'v',
                'warehouse_id': location,
                'warehouse_name': 'Warehouse $location',
                'barcode': 'RETURN-BARCODE',
                'branch_id': 'b',
                'product_name': 'Replacement',
                'quantity': 0,
                'unit_price': 25,
                'in_invoice_id': '00000000-0000-0000-0000-000000000000',
              },
          ],
          _ => throw StateError(path),
        };
        return http.Response(jsonEncode({'data': data}), 200);
      }

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ZarlagaInvoicePage(apiToken: 'fixture')),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Буцаагдсан захиалгыг засах'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Бараа нэмэх'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Replacement'), findsOneWidget);
        expect(find.text('1 хувилбар · 2 агуулах'), findsOneWidget);
        await tester.tap(find.text('Replacement'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('RETURN-BARCODE'), findsOneWidget);
        await tester.tap(find.text('Warehouse w'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final qty = find.widgetWithText(TextFormField, 'Тоо хэмжээ');
        await tester.enterText(qty, '0');
        await tester.tap(find.text('Өөрчлөлт хадгалах'));
        await tester.pump();
        expect(posted, isEmpty);
        await tester.enterText(qty, '4');
        await tester.tap(find.text('Өөрчлөлт хадгалах'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(posted.single['id'], 'old');
        final item = posted.single['items'].single;
        expect(item['quantity'], 4);
        expect(item['inInvoiceId'], '');
        expect(item['warehouseId'], 'w');
        expect(posted.single['total'], 100);
      }, () => MockClient(respond));
    },
  );
}
