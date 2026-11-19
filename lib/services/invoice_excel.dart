import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

bool isReadyInvoiceExcel(Uint8List bytes) {
  final entry = ZipDecoder().decodeBytes(bytes).findFile('xl/workbook.xml');
  if (entry == null || entry.size > 1024 * 1024) return false;
  final names = XmlDocument.parse(utf8.decode(entry.content as List<int>))
      .findAllElements('sheet')
      .map((s) => s.getAttribute('name'))
      .toSet();
  return names.containsAll(['Invoice', 'Items']);
}

/// Reads the two-sheet invoice workbook written by the offline converter.
/// Resolve relationships by name so moving a worksheet tab in Excel is safe.
Map<String, dynamic> readInvoiceExcel(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  XmlDocument document(String path) {
    final entry = archive.findFile(path);
    if (entry == null || entry.size > 48 * 1024 * 1024) {
      throw const FormatException(
        'Excel файлын бүтэц эсвэл хэмжээ тохирохгүй байна.',
      );
    }
    return XmlDocument.parse(utf8.decode(entry.content as List<int>));
  }

  final workbook = document('xl/workbook.xml');
  final relations = {
    for (final r in document(
      'xl/_rels/workbook.xml.rels',
    ).findAllElements('Relationship'))
      r.getAttribute('Id'): r.getAttribute('Target'),
  };
  final strings = [
    if (archive.findFile('xl/sharedStrings.xml') != null)
      for (final s in document('xl/sharedStrings.xml').findAllElements('si'))
        s.findAllElements('t').map((t) => t.innerText).join(),
  ];
  List<Map<String, String>> sheet(String name) {
    final tag = workbook
        .findAllElements('sheet')
        .where((s) => s.getAttribute('name') == name)
        .firstOrNull;
    final target = relations[tag?.getAttribute('r:id')];
    if (target == null)
      throw FormatException(
        '$name хуудас олдсонгүй. Excel хөрвүүлэгчээс орлогын загварыг сонгоно уу.',
      );
    final path = Uri.parse('/xl/workbook.xml')
        .resolve(target)
        .path
        .substring(1);
    final rows = <Map<String, String>>[];
    final headers = <String, String>{};
    var first = true;
    for (final row in document(path).findAllElements('row')) {
      final record = <String, String>{};
      for (final cell in row.findElements('c')) {
        final col = (cell.getAttribute('r') ?? '').replaceAll(
          RegExp('[0-9]'),
          '',
        );
        final value = cell.getElement('v')?.innerText ?? '';
        final text = switch (cell.getAttribute('t')) {
          's' => strings[int.parse(value)],
          'inlineStr' =>
            cell.findAllElements('t').map((n) => n.innerText).join(),
          _ => value,
        };
        if (first) {
          headers[col] = text;
        } else if (headers.containsKey(col) && text.trim().isNotEmpty) {
          record[headers[col]!] = text.trim();
        }
      }
      if (!first && record.isNotEmpty) rows.add(record);
      first = false;
    }
    return rows;
  }

  final meta = sheet('Invoice').singleOrNull;
  if (meta == null || !RegExp(r'^[A-Z]{3}$').hasMatch(meta['currency'] ?? ''))
    throw const FormatException('Нэхэмжлэхийн валют дутуу байна.');
  final items = sheet('Items');
  if (items.isEmpty)
    throw const FormatException('Нэхэмжлэхэд барааны мөр байхгүй.');
  for (final (i, r) in items.indexed) {
    final q = double.tryParse(r['quantity'] ?? ''),
        p = double.tryParse(r['unit_cost'] ?? '');
    if ((r['name'] ?? '').isEmpty ||
        q == null ||
        !q.isFinite ||
        q <= 0 ||
        p == null ||
        !p.isFinite ||
        p < 0)
      throw FormatException(
        '${i + 2}-р мөрийн нэр, тоо хэмжээ, нэгж үнийг шалгана уу.',
      );
  }
  return {...meta, 'items': items};
}
