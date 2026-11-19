part of '../main.dart';

class ZarlagaInvoicePage extends StatefulWidget {
  final String apiToken;
  const ZarlagaInvoicePage({super.key, required this.apiToken});

  @override
  State<ZarlagaInvoicePage> createState() => _ZarlagaInvoicePageState();
}

class _ZarlagaInvoicePageState extends State<ZarlagaInvoicePage> {
  OyudentApi get api => OyudentApi(widget.apiToken);
  static const labels = <String, String>{
    'ORDER_STATUS_PENDING': 'Pending',
    'ORDER_STATUS_PROCESSING': 'Preparing',
    'ORDER_STATUS_SHIPPING': 'Out for delivery',
    'ORDER_STATUS_DELIVERED': 'Delivered',
    'ORDER_STATUS_CANCELLED': 'Cancelled',
    'ORDER_STATUS_RETURNED': 'Returned',
    'ORDER_STATUS_FAILED_DELIVERY': 'Delivery failed',
  };
  static const transitions = <String, List<String>>{
    'ORDER_STATUS_PENDING': [
      'ORDER_STATUS_PROCESSING',
      'ORDER_STATUS_CANCELLED',
    ],
    'ORDER_STATUS_PROCESSING': [
      'ORDER_STATUS_SHIPPING',
      'ORDER_STATUS_CANCELLED',
    ],
    'ORDER_STATUS_SHIPPING': [
      'ORDER_STATUS_DELIVERED',
      'ORDER_STATUS_FAILED_DELIVERY',
      'ORDER_STATUS_RETURNED',
    ],
    'ORDER_STATUS_FAILED_DELIVERY': [
      'ORDER_STATUS_SHIPPING',
      'ORDER_STATUS_CANCELLED',
    ],
    'ORDER_STATUS_DELIVERED': [],
    'ORDER_STATUS_CANCELLED': ['ORDER_STATUS_PROCESSING'],
    'ORDER_STATUS_RETURNED': ['ORDER_STATUS_PROCESSING'],
  };

  final searchController = TextEditingController();
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? error;
  String search = '';
  final Set<String> busyOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredOrders {
    final query = search.toLowerCase();
    if (query.isEmpty) return orders;
    return orders.where((order) {
      return [
        order['invoice_number'],
        order['company_name'],
        order['company_register_number'],
        labels[order['status_code']?.toString()],
      ].any((value) => (value ?? '').toString().toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final decoded = await api.get(
        '/order/list?no_paginate=1&sort=-created_at,-id',
      );
      if (mounted) setState(() => orders = _asMapList(decoded));
    } catch (exception) {
      if (mounted)
        setState(() => error = '$exception'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openOrder(
    Map<String, dynamic> order, {
    bool edit = false,
  }) async {
    final id = order['id']?.toString() ?? '';
    if (id.isEmpty || busyOrderIds.contains(id)) return;
    setState(() => busyOrderIds.add(id));
    try {
      final data = await api.orderDetails(id);
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _OrderDetails(
          api: api,
          id: id,
          order: data,
          startEditing: edit && data['status_code'] == 'ORDER_STATUS_RETURNED',
        ),
      );
      if (saved == true && mounted) _notice(context, 'Order changes saved.');
      if (mounted &&
          (saved == true || data['status_code'] != order['status_code']))
        await _loadOrders();
    } catch (exception) {
      if (mounted)
        _notice(context, 'Could not open order: $exception', failed: true);
    } finally {
      if (mounted) setState(() => busyOrderIds.remove(id));
    }
  }

  Future<void> _changeStatus(
    Map<String, dynamic> order,
    String statusCode,
  ) async {
    final id = order['id']?.toString();
    if (id == null || id.isEmpty || busyOrderIds.contains(id)) return;
    setState(() => busyOrderIds.add(id));
    try {
      await api.post('/order/change-status', {
        'id': id,
        'statusCode': statusCode,
      });
      if (mounted) _notice(context, 'Delivery status updated.');
      await _loadOrders();
    } catch (exception) {
      if (mounted) {
        _notice(
          context,
          'Could not update delivery status: $exception',
          failed: true,
        );
      }
    } finally {
      if (mounted) setState(() => busyOrderIds.remove(id));
    }
  }

  Future<void> _shipOrder(Map<String, dynamic> order) async {
    final id = order['id']?.toString();
    if (id == null || id.isEmpty || busyOrderIds.contains(id)) return;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Choose delivery invoice date',
    );
    if (date == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create delivery invoice?'),
        content: const Text(
          'This records an outgoing warehouse delivery for this order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create delivery'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busyOrderIds.add(id));
    try {
      await api.post('/order/$id/ship', {'invoiceDate': _isoDateTime(date)});
      if (mounted) _notice(context, 'Delivery invoice created.');
      await _loadOrders();
    } catch (exception) {
      if (mounted) {
        _notice(
          context,
          'Could not create delivery invoice: $exception',
          failed: true,
        );
      }
    } finally {
      if (mounted) setState(() => busyOrderIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TopBar(
        title: 'Zarlaga invoices',
        subtitle: 'Orders and delivery status',
        trailing: IconButton.filledTonal(
          tooltip: 'Refresh invoices',
          onPressed: loading ? null : _loadOrders,
          icon: const Icon(Icons.refresh),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 12),
        child: TextField(
          controller: searchController,
          onChanged: (value) => setState(() => search = value.trim()),
          decoration: const InputDecoration(
            hintText: 'Search invoice number or company...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      Expanded(
        child: loading
            ? const _BusyBar('Loading orders…')
            : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, style: const TextStyle(color: muted)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadOrders,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            : filteredOrders.isEmpty
            ? const Center(child: Text('No matching invoices.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(26, 8, 26, 26),
                itemCount: filteredOrders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _invoiceCard(filteredOrders[index]),
              ),
      ),
    ],
  );

  Widget _invoiceCard(Map<String, dynamic> order) {
    final statusCode = (order['status_code'] ?? 'Unknown').toString();
    final choices = transitions[statusCode] ?? const <String>[];
    final orderId = order['id']?.toString() ?? '';
    final rowBusy = busyOrderIds.contains(orderId);
    final amount = _asInt(
      order['total_gross'] ?? order['total_amount'] ?? order['total'],
    );
    final company = (order['company_name'] ?? 'Company not set').toString();
    final invoiceNumber = (order['invoice_number'] ?? orderId).toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoiceNumber,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                enabled: choices.isNotEmpty && !rowBusy,
                tooltip: 'Change delivery status',
                onSelected: (next) => _changeStatus(order, next),
                itemBuilder: (context) => choices
                    .map(
                      (code) => PopupMenuItem<String>(
                        value: code,
                        child: Text(
                          code == 'ORDER_STATUS_PROCESSING' &&
                                  statusCode == 'ORDER_STATUS_RETURNED'
                              ? 'Send back to preparation'
                              : 'Mark as ${labels[code] ?? code}',
                        ),
                      ),
                    )
                    .toList(),
                child: Chip(
                  avatar: rowBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_shipping_outlined, size: 16),
                  label: Text(
                    '${labels[statusCode] ?? statusCode}${choices.isEmpty ? '' : ' ▾'}',
                  ),

                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(company, style: const TextStyle(color: ink, fontSize: 12)),
          if ((order['company_register_number'] ?? '')
              .toString()
              .isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Register: ${order['company_register_number']}',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
          const SizedBox(height: 12),
          _DeliveryProgress(statusCode),
          const Divider(height: 20),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _invoiceDatum('Amount', '₮${_money(amount.toDouble())}'),
              _invoiceDatum(
                'Invoice date',
                _displayApiDate(order['invoice_date']),
              ),
              _invoiceDatum('Due date', _displayApiDate(order['due_date'])),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: rowBusy ? null : () => _openOrder(order),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View order details'),
              ),
              if (statusCode == 'ORDER_STATUS_RETURNED')
                OutlinedButton.icon(
                  onPressed: rowBusy
                      ? null
                      : () => _openOrder(order, edit: true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit returned order'),
                ),
            ],
          ),
          if (statusCode == 'ORDER_STATUS_PROCESSING') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: rowBusy ? null : () => _shipOrder(order),
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Create delivery invoice'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceDatum(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 9)),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

String _isoDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}T00:00';
}

String _displayApiDate(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return '—';
  return text
      .replaceFirst('T', ' ')
      .substring(0, text.length > 16 ? 16 : text.length);
}

class ExpensePage extends StatelessWidget {
  const ExpensePage({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TopBar(
        title: 'Zarlaga',
        subtitle: 'Expense tracking',
        trailing: FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _NewExpenseDialog(),
          ),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Add expense'),
          style: FilledButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Total expenses',
                    value: '₮ 1,284,500',
                    detail: 'This month',
                    icon: Icons.payments_outlined,
                    tint: const Color(0xFFEAF2EC),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MetricCard(
                    title: 'Transactions',
                    value: '24',
                    detail: 'This month',
                    icon: Icons.receipt_long_outlined,
                    tint: const Color(0xFFEAF0F6),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MetricCard(
                    title: 'Largest category',
                    value: 'Supplies',
                    detail: '₮ 462,000',
                    icon: Icons.inventory_2_outlined,
                    tint: const Color(0xFFF5EFE1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                const Text(
                  'Recent expenses',
                  style: TextStyle(
                    color: ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 235,
                  height: 39,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search expenses...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const _ExpenseHeader(),
                  const Divider(height: 1),
                  ..._demoExpenses.map((e) => _ExpenseRow(expense: e)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Demo records · Connect the Oyudent expense API to load live data',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
