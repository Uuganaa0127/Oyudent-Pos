part of '../main.dart';

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress(this.status);
  final String status;
  static const stages = [
    'Хүлээгдэж буй',
    'Бэлтгэж байна',
    'Хүргэлтэд гарсан',
    'Хүргэгдсэн',
  ];
  static const codes = [
    'ORDER_STATUS_PENDING',
    'ORDER_STATUS_PROCESSING',
    'ORDER_STATUS_SHIPPING',
    'ORDER_STATUS_DELIVERED',
  ];

  @override
  Widget build(BuildContext context) {
    final stage = codes.indexOf(status);
    if (stage < 0) {
      final message = switch (status) {
        'ORDER_STATUS_RETURNED' =>
          'Буцаагдсан · Захиалгаа шалгаж засаад дахин бэлтгэлд шилжүүлнэ үү.',
        'ORDER_STATUS_FAILED_DELIVERY' =>
          'Хүргэлт амжилтгүй · Дахин хүргэх эсвэл захиалгыг цуцална уу.',
        'ORDER_STATUS_CANCELLED' => 'Цуцлагдсан · Хүргэлт зогссон.',
        _ => 'Хүргэлтийн төлөв тодорхойгүй',
      };
      return Row(
        children: [
          Icon(
            status == 'ORDER_STATUS_RETURNED'
                ? Icons.assignment_return_outlined
                : Icons.info_outline,
            color: warningInk,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: warningInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '4 үе шатны ${stage + 1} · ${stages[stage]}${stage < 3 ? '  →  Дараагийн шат: ${stages[stage + 1]}' : ''}',
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Хүргэлтийн 4 үе шатны ${stage + 1}',
          child: Row(
            children: List.generate(
              stages.length,
              (i) => Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(
                    right: i == stages.length - 1 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: i < stage
                        ? aquaGlow
                        : i == stage
                        ? green
                        : lineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

double _orderNumber(dynamic value) => double.tryParse('$value') ?? 0;
String _orderMoney(double value) => '₮${value.toStringAsFixed(2)}';

class _OrderDetails extends StatefulWidget {
  const _OrderDetails({
    required this.api,
    required this.id,
    required this.order,
    required this.startEditing,
  });
  final OyudentApi api;
  final String id;
  final Map<String, dynamic> order;
  final bool startEditing;

  @override
  State<_OrderDetails> createState() => _OrderDetailsState();
}

class _ReturnLine {
  _ReturnLine(this.stock, this.quantity, this.price, this.taxShare);
  factory _ReturnLine.fromOrder(Map<String, dynamic> row, bool vat) {
    final gross =
        _orderNumber(row['unit_price']) * _orderNumber(row['quantity']);
    final share = gross > 0
        ? _orderNumber(row['tax']) / gross
        : (vat ? 1 / 11 : 0.0);
    return _ReturnLine(
      row,
      row['quantity'].toString(),
      row['unit_price'].toString(),
      share,
    );
  }
  final Map<String, dynamic> stock;
  String quantity, price;
  final double taxShare;
  double? available;
  int revision = 0;
  double get gross => _orderNumber(quantity) * _orderNumber(price);
  double get tax => double.parse((gross * taxShare).toStringAsFixed(2));
}

class _OrderDetailsState extends State<_OrderDetails> {
  late bool editing = widget.startEditing;
  late final order = widget.order;
  late final original = List<Map<String, dynamic>>.from(order['items']);
  late final vat =
      _orderNumber(order['tax']) > 0 ||
      ['true', '1'].contains(order['is_vat'].toString().toLowerCase());
  late final lines = original
      .map((r) => _ReturnLine.fromOrder(r, vat))
      .toList();
  bool loadingStock = false;
  late String note = order['note']?.toString() ?? '';
  bool saving = false;
  String? error;
  final form = GlobalKey<FormState>();
  String get status => order['status_code']?.toString() ?? '';
  double get total {
    var result = _orderNumber(order['total_gross'] ?? order['total']);
    for (final row in original) {
      result -= _orderNumber(row['quantity']) * _orderNumber(row['unit_price']);
    }
    return lines.fold(result, (sum, l) => sum + l.gross);
  }

  Future<void> addProduct() async {
    final branch = order['branch_id']?.toString() ?? '';
    if (loadingStock || saving || branch.isEmpty) return;
    setState(() {
      loadingStock = true;
      error = null;
    });
    try {
      final response = await widget.api.get(
        '/order/get-available-stocks?branch_id=${Uri.encodeQueryComponent(branch)}',
      );
      if (!mounted) return;
      final stocks = _asMapList(response)
          .where((r) => _orderNumber(r['quantity']) > 0)
          .toList();
      setState(() => loadingStock = false);
      final stock = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _WarehouseSearch(
          widget.api.token,
          cachedStocks: stocks,
          selectable: true,
          orderBranchOnly: true,
        ),
      );
      if (stock == null || !mounted) return;
      final key = _stockLineKey(stock);
      final existing = lines
          .where((l) => _stockLineKey(l.stock) == key)
          .firstOrNull;
      final available = _orderNumber(stock['quantity']);
      final next = existing == null ? 1.0 : _orderNumber(existing.quantity) + 1;
      if (next > available)
        throw Exception('Сонгосон лотын үлдэгдэл хүрэлцэхгүй.');
      setState(() {
        if (existing != null) {
          existing.quantity = next.toString();
          existing.available = available;
          existing.revision++;
        } else {
          final net = _orderNumber(
            stock['unit_price'] ?? stock['base_unit_price'] ?? stock['price'],
          );
          final gross = vat ? net * 1.1 : net;
          lines.add(
            _ReturnLine(
              {
                ...stock,
                'product_name': Product.fromApi(stock).name,
                'lot_no': stock['lot_no'] ?? stock['lot_number'],
                'variant_code': stock['barcode'] ?? stock['variant_code'],
                'discount': 0,
                'note': '',
              },
              '1',
              gross.toStringAsFixed(2),
              vat ? 1 / 11 : 0,
            )..available = available,
          );
        }
      });
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loadingStock = false);
    }
  }

  Future<void> save() async {
    if (saving ||
        lines.isEmpty ||
        loadingStock ||
        status != 'ORDER_STATUS_RETURNED' ||
        !form.currentState!.validate())
      return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final fresh = await widget.api.orderDetails(widget.id);
      if (fresh['status_code'] != status ||
          jsonEncode(fresh) != jsonEncode(order)) {
        throw Exception(
          'Захиалга өөрчлөгдсөн байна. Хаагаад дахин нээж шинэ мэдээллийг шалгана уу.',
        );
      }
      final items = <Map<String, dynamic>>[];
      var tax = _orderNumber(order['tax']);
      for (final row in original) {
        tax -= _orderNumber(row['tax']);
      }
      for (final draft in lines) {
        final line = draft.stock;
        final qty = double.parse(draft.quantity);
        final gross = double.parse(draft.price);
        final newTax = draft.tax;
        tax += newTax;
        items.add({
          'productId': line['product_id'],
          'variantId': line['variant_id'],
          'warehouseId': line['warehouse_id'],
          'inInvoiceId': line['in_invoice_id'],
          'quantity': qty,
          'grossUnitPrice': gross,
          'netUnitPrice': gross - newTax / qty,
          'tax': newTax,
          'discount': line['discount'] ?? 0,
          'note': line['note'] ?? '',
        });
      }
      await widget.api.post('/order/', {
        'id': widget.id,
        'branchId': order['branch_id'],
        'companyId': order['company_id'],
        'invoiceNumber': order['invoice_number'],
        'invoiceDate': order['invoice_date'],
        'dueDate': order['due_date'],
        'isVat': order['is_vat'] ?? (_orderNumber(order['tax']) > 0),
        'discount': order['discount'] ?? 0,
        'tax': double.parse(tax.toStringAsFixed(2)),
        'total': double.parse(total.toStringAsFixed(2)),
        'items': items,
        'note': note,
        'vatBankAccountNumber': order['vat_bank_account_number'] ?? '',
        'noVatBankAccountNumber': order['no_vat_bank_account_number'] ?? '',
        'isLoan': order['is_loan'] ?? false,
        'loanMonths': order['loan_months'] ?? 0,
        'loanStart': order['loan_start'] ?? '',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          saving = false;
        });
    }
  }

  Widget numberField(int i, {required bool price}) => SizedBox(
    width: 150,
    child: TextFormField(
      key: ValueKey((lines[i], price, price ? 0 : lines[i].revision)),
      initialValue: price ? lines[i].price : lines[i].quantity,
      enabled: !saving,
      decoration: InputDecoration(
        labelText: price
            ? (vat ? 'НӨАТ-тай нэгж үнэ (₮)' : 'Нэгж үнэ (₮)')
            : 'Тоо хэмжээ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (text) {
        final n = double.tryParse(text ?? '');
        if (n == null || !n.isFinite || n < 0 || (!price && n == 0))
          return 'Зөв тоон утга оруулна уу';
        if (!price && lines[i].available != null && n > lines[i].available!)
          return 'Үлдэгдэл: ${lines[i].available}';
        return null;
      },
      onChanged: (v) => setState(() {
        if (price) {
          lines[i].price = v;
        } else {
          lines[i].quantity = v;
        }
      }),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${editing ? 'Буцаагдсан захиалгыг засах' : 'Захиалгын дэлгэрэнгүй'} · ${order['invoice_number'] ?? widget.id}',
    ),
    content: SizedBox(
      width: 640,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DeliveryProgress(status),
              const Divider(height: 24),
              Text(
                [
                  order['company_name'],
                  order['branch_name'],
                ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              ),
              Text(
                'Баримтын огноо: ${_displayApiDate(order['invoice_date'])}   Төлөх огноо: ${_displayApiDate(order['due_date'])}',
              ),
              if (editing)
                OutlinedButton.icon(
                  onPressed:
                      saving || loadingStock || order['branch_id'] == null
                      ? null
                      : addProduct,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Бараа нэмэх'),
                ),
              if (loadingStock) const LinearProgressIndicator(),
              if (lines.isEmpty) const Text('Захиалгад бараа байхгүй.'),
              for (var i = 0; i < lines.length; i++) ...[
                const Divider(height: 24),
                Text(
                  (lines[i].stock['product_name'] ??
                          lines[i].stock['name'] ??
                          'Бараа')
                      .toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  [
                    lines[i].stock['variant_name'],
                    lines[i].stock['variant_code'],
                    lines[i].stock['warehouse_name'],
                    if (lines[i].stock['lot_no'] != null)
                      'Лот: ${lines[i].stock['lot_no']}',
                    if (lines[i].stock['expiration_date'] != null)
                      'Дуусах: ${_displayApiDate(lines[i].stock['expiration_date'])}',
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                ),
                if (editing)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      numberField(i, price: false),
                      numberField(i, price: true),
                      TextButton.icon(
                        onPressed: saving || loadingStock
                            ? null
                            : () => setState(() => lines.removeAt(i)),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Мөр хасах'),
                      ),
                    ],
                  )
                else
                  Text(
                    '${lines[i].quantity} × ${_orderMoney(_orderNumber(lines[i].price))}',
                  ),
              ],
              const Divider(height: 24),
              if (editing)
                TextFormField(
                  initialValue: note,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Захиалгын тэмдэглэл',
                  ),
                  onChanged: (v) => note = v,
                )
              else if (note.isNotEmpty)
                Text(note),
              const SizedBox(height: 12),
              Text(
                'Захиалгын нийт дүн  ${_orderMoney(total)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(editing ? 'Болих' : 'Хаах'),
      ),
      if (status == 'ORDER_STATUS_RETURNED')
        FilledButton(
          onPressed: saving || loadingStock || (editing && lines.isEmpty)
              ? null
              : editing
              ? save
              : () => setState(() => editing = true),
          child: Text(
            editing ? 'Өөрчлөлт хадгалах' : 'Буцаагдсан захиалгыг засах',
          ),
        ),
    ],
  );
}
