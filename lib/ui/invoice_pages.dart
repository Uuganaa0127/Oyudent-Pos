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
    'ORDER_STATUS_PENDING': 'Хүлээгдэж буй',
    'ORDER_STATUS_PROCESSING': 'Бэлтгэж байна',
    'ORDER_STATUS_SHIPPING': 'Хүргэлтэд гарсан',
    'ORDER_STATUS_DELIVERED': 'Хүргэгдсэн',
    'ORDER_STATUS_CANCELLED': 'Цуцлагдсан',
    'ORDER_STATUS_RETURNED': 'Буцаагдсан',
    'ORDER_STATUS_FAILED_DELIVERY': 'Хүргэлт амжилтгүй',
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
      if (saved == true && mounted)
        _notice(context, 'Захиалгын өөрчлөлтийг хадгаллаа.');
      if (mounted &&
          (saved == true || data['status_code'] != order['status_code']))
        await _loadOrders();
    } catch (exception) {
      if (mounted)
        _notice(context, 'Захиалгыг нээж чадсангүй: $exception', failed: true);
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
      if (mounted) _notice(context, 'Хүргэлтийн төлөв шинэчлэгдлээ.');
      await _loadOrders();
    } catch (exception) {
      if (mounted) {
        _notice(
          context,
          'Хүргэлтийн төлөв шинэчлэгдсэнгүй: $exception',
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
      helpText: 'Зарлагын баримтын огноо сонгох',
    );
    if (date == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Зарлагын баримт үүсгэх үү?'),
        content: const Text(
          'Энэ захиалгын дагуу агуулахаас бараа гаргасныг бүртгэнэ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Хүргэлт бүртгэх'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busyOrderIds.add(id));
    try {
      await api.post('/order/$id/ship', {'invoiceDate': _isoDateTime(date)});
      if (mounted) _notice(context, 'Зарлагын баримт үүслээ.');
      await _loadOrders();
    } catch (exception) {
      if (mounted) {
        _notice(
          context,
          'Зарлагын баримт үүсгэж чадсангүй: $exception',
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
        title: 'Зарлагын баримтууд',
        subtitle: 'Захиалга ба хүргэлтийн төлөв',
        trailing: IconButton.filledTonal(
          tooltip: 'Баримтуудыг шинэчлэх',
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
            hintText: 'Баримтын дугаар эсвэл байгууллагаар хайх…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      Expanded(
        child: loading
            ? const _BusyBar('Захиалгуудыг ачаалж байна…')
            : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, style: const TextStyle(color: muted)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadOrders,
                      child: const Text('Дахин оролдох'),
                    ),
                  ],
                ),
              )
            : filteredOrders.isEmpty
            ? const Center(child: Text('Тохирох баримт олдсонгүй.'))
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
    final statusCode = (order['status_code'] ?? 'Тодорхойгүй').toString();
    final choices = transitions[statusCode] ?? const <String>[];
    final orderId = order['id']?.toString() ?? '';
    final rowBusy = busyOrderIds.contains(orderId);
    final amount = _asInt(
      order['total_gross'] ?? order['total_amount'] ?? order['total'],
    );
    final company = (order['company_name'] ?? 'Байгууллага сонгоогүй')
        .toString();
    final invoiceNumber = (order['invoice_number'] ?? orderId).toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(color: lineColor),
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
                tooltip: 'Хүргэлтийн төлөв солих',
                onSelected: (next) => _changeStatus(order, next),
                itemBuilder: (context) => choices
                    .map(
                      (code) => PopupMenuItem<String>(
                        value: code,
                        child: Text(
                          code == 'ORDER_STATUS_PROCESSING' &&
                                  statusCode == 'ORDER_STATUS_RETURNED'
                              ? 'Бэлтгэлд буцаах'
                              : '${labels[code] ?? code} төлөвт шилжүүлэх',
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
              'Регистр: ${order['company_register_number']}',
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
              _invoiceDatum('Дүн', '₮${_money(amount.toDouble())}'),
              _invoiceDatum(
                'Баримтын огноо',
                _displayApiDate(order['invoice_date']),
              ),
              _invoiceDatum('Төлөх огноо', _displayApiDate(order['due_date'])),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: rowBusy ? null : () => _openOrder(order),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Захиалга харах'),
              ),
              if (statusCode == 'ORDER_STATUS_RETURNED')
                OutlinedButton.icon(
                  onPressed: rowBusy
                      ? null
                      : () => _openOrder(order, edit: true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Буцаагдсан захиалгыг засах'),
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
                label: const Text('Зарлагын баримт үүсгэх'),
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
        title: 'Зарлага',
        subtitle: 'Зардлын бүртгэл',
        trailing: FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _NewExpenseDialog(),
          ),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Зардал бүртгэх'),
          style: FilledButton.styleFrom(
            backgroundColor: green,
            foregroundColor: deepSpace,
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
                    title: 'Нийт зардал',
                    value: '₮ 1,284,500',
                    detail: 'Энэ сар',
                    icon: Icons.payments_outlined,
                    tint: activeSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MetricCard(
                    title: 'Гүйлгээ',
                    value: '24',
                    detail: 'Энэ сар',
                    icon: Icons.receipt_long_outlined,
                    tint: deepSpaceMid,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MetricCard(
                    title: 'Хамгийн их зардалтай ангилал',
                    value: 'Хангамж',
                    detail: '₮ 462,000',
                    icon: Icons.inventory_2_outlined,
                    tint: warningSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                const Text(
                  'Сүүлийн зардлууд',
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
                      hintText: 'Зардал хайх…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: inputSurface,
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
                color: panelColor,
                border: Border.all(color: lineColor),
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
                'Жишээ бүртгэл · Бодит мэдээллийг харахын тулд системд холбогдоно уу',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
