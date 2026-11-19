part of '../main.dart';

typedef _IncomingKey = ({String product, String variant, String warehouse});

_IncomingKey _incomingKey(Map<String, dynamic> r) => (
  product: (r['product_id'] ?? '').toString(),
  variant: (r['variant_id'] ?? r['product_variant_id'] ?? '').toString(),
  warehouse: (r['warehouse_id'] ?? '').toString(),
);

Map<_IncomingKey, num> _availableByLocation(
  Iterable<Map<String, dynamic>> rows,
) {
  final sums = <_IncomingKey, num>{};
  for (final r in rows) {
    final k = _incomingKey(r);
    sums[k] = (sums[k] ?? 0) + (num.tryParse('${r['quantity']}') ?? 0);
  }
  return sums;
}

Future<List<Map<String, dynamic>>> _incomingStocks(
  OyudentApi api,
  String branch, {
  Duration limit = const Duration(seconds: 30),
}) async {
  final result = await api.get(
    '/order/get-available-stocks?branch_id=${Uri.encodeQueryComponent(branch)}',
    limit: limit,
  );
  if (result['data'] is! List && result['items'] is! List)
    throw const FormatException('Үлдэгдлийн мэдээлэл дутуу ирлээ.');
  return _asMapList(result)
      .where(
        (r) => r['branch_id'] == null || r['branch_id'].toString() == branch,
      )
      .toList();
}

class _IncomingReceipt {
  const _IncomingReceipt({
    required this.branch,
    required this.location,
    required this.expected,
    required this.reference,
    this.id,
    this.before,
    this.historical = false,
  });
  final String branch, location, reference;
  final String? id;
  final bool historical;
  final Map<_IncomingKey, num> expected;
  final Map<_IncomingKey, num>? before;

  ({String text, bool confirmed}) check(List<Map<String, dynamic>> stocks) {
    final totals = _availableByLocation(
      stocks.where((r) => id == null || r['in_invoice_id']?.toString() == id),
    );
    if (id == null && before == null)
      return (
        text: 'Баримтыг жагсаалтаас сонгож үлдэгдлийг шалгана уу.',
        confirmed: false,
      );
    num available = 0;
    bool confirmed = expected.isNotEmpty;
    for (final e in expected.entries) {
      final current =
          (totals[e.key] ?? 0) - (id == null ? (before?[e.key] ?? 0) : 0);
      available += current;
      if (current < e.value) confirmed = false;
    }
    final received = expected.values.fold<num>(0, (s, q) => s + q);
    if (historical || id != null) {
      return (
        text: 'Баримтын тоо: $received · Одоо борлуулах үлдэгдэл: $available.',
        confirmed: confirmed,
      );
    }
    return (
      text:
          'Орлогын тоо: $received · Сонгосон бараа, агуулахын үлдэгдлийн өөрчлөлт: $available.',
      confirmed: confirmed,
    );
  }
}
