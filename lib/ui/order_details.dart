part of '../main.dart';

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress(this.status);
  final String status;
  static const stages = [
    'Pending',
    'Preparing',
    'Out for delivery',
    'Delivered',
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
        'ORDER_STATUS_RETURNED' => 'Returned · Review and correct the order before sending it back to preparation.',
        'ORDER_STATUS_FAILED_DELIVERY' =>
          'Delivery failed · Retry delivery or cancel the order.',
        'ORDER_STATUS_CANCELLED' => 'Cancelled · Delivery stopped.',
        _ => 'Delivery status unavailable',
      };
      return Text(message, style: const TextStyle(fontWeight: FontWeight.w600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${stage + 1} of 4 · ${stages[stage]}${stage < 3 ? '  →  Next: ${stages[stage + 1]}' : ''}',
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (stage + 1) / 4,
          semanticsLabel: 'Delivery stage',
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

class _OrderDetailsState extends State<_OrderDetails> {
  late bool editing = widget.startEditing;
  late final order = widget.order;
  late final lines = List<Map<String, dynamic>>.from(order['items']);
  late final quantities = lines.map((l) => l['quantity'].toString()).toList();
  late final prices = lines.map((l) => l['unit_price'].toString()).toList();
  late String note = order['note']?.toString() ?? '';
  bool saving = false;
  String? error;
  final form = GlobalKey<FormState>();
  String get status => order['status_code']?.toString() ?? '';
  double get total {
    var result = _orderNumber(order['total_gross'] ?? order['total']);
    for (var i = 0; i < lines.length; i++) {
      result +=
          _orderNumber(quantities[i]) * _orderNumber(prices[i]) -
          _orderNumber(lines[i]['quantity']) *
              _orderNumber(lines[i]['unit_price']);
    }
    return result;
  }

  Future<void> save() async {
    if (saving ||
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
          'This order changed. Close and reopen it to review the latest version.',
        );
      }
      final items = <Map<String, dynamic>>[];
      var tax = _orderNumber(order['tax']);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final qty = double.parse(quantities[i]);
        final gross = double.parse(prices[i]);
        final originalGross =
            _orderNumber(line['unit_price']) * _orderNumber(line['quantity']);
        final oldTax = _orderNumber(line['tax']);
        final newTax = originalGross > 0
            ? double.parse(
                (qty * gross * oldTax / originalGross).toStringAsFixed(2),
              )
            : oldTax;
        tax += newTax - oldTax;
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
      initialValue: price ? prices[i] : quantities[i],
      enabled: !saving,
      decoration: InputDecoration(
        labelText: price ? 'Unit price (₮)' : 'Quantity',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (text) {
        final n = double.tryParse(text ?? '');
        if (n == null || !n.isFinite || n < 0 || (!price && n == 0))
          return 'Enter a valid amount';
        return null;
      },
      onChanged: (v) => setState(() => (price ? prices : quantities)[i] = v),
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${editing ? 'Edit returned order' : 'Order details'} · ${order['invoice_number'] ?? widget.id}',
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
                'Invoice ${_displayApiDate(order['invoice_date'])}   Due ${_displayApiDate(order['due_date'])}',
              ),
              if (lines.isEmpty) const Text('No order items.'),
              for (var i = 0; i < lines.length; i++) ...[
                const Divider(height: 24),
                Text(
                  (lines[i]['product_name'] ?? lines[i]['name'] ?? 'Product')
                      .toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  [
                    lines[i]['variant_name'],
                    lines[i]['variant_code'],
                    lines[i]['warehouse_name'],
                    if (lines[i]['lot_no'] != null) 'Lot ${lines[i]['lot_no']}',
                    if (lines[i]['expiration_date'] != null)
                      'Expires ${_displayApiDate(lines[i]['expiration_date'])}',
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                ),
                if (editing)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      numberField(i, price: false),
                      numberField(i, price: true),
                    ],
                  )
                else
                  Text(
                    '${quantities[i]} × ${_orderMoney(_orderNumber(prices[i]))}',
                  ),
              ],
              const Divider(height: 24),
              if (editing)
                TextFormField(
                  initialValue: note,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Order note'),
                  onChanged: (v) => note = v,
                )
              else if (note.isNotEmpty)
                Text(note),
              const SizedBox(height: 12),
              Text(
                'Order total  ${_orderMoney(total)}',
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
        child: Text(editing ? 'Cancel' : 'Close'),
      ),
      if (status == 'ORDER_STATUS_RETURNED')
        FilledButton(
          onPressed: saving
              ? null
              : editing
              ? save
              : () => setState(() => editing = true),
          child: Text(editing ? 'Save changes' : 'Edit returned order'),
        ),
    ],
  );
}
