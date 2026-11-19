part of '../main.dart';

class IncomingInvoicesPage extends StatefulWidget {
  final String apiToken;
  final String? initialBranchId;
  final Future<void> Function() onReload;
  final bool Function(String, List<Map<String, dynamic>>) onStock;
  const IncomingInvoicesPage({
    super.key,
    required this.apiToken,
    required this.initialBranchId,
    required this.onReload,
    required this.onStock,
  });
  @override
  State<IncomingInvoicesPage> createState() => _IncomingInvoicesPageState();
}

class _IncomingInvoicesPageState extends State<IncomingInvoicesPage> {
  late final OyudentApi api = OyudentApi(widget.apiToken);
  List<Map<String, dynamic>> invoices = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final body = await api.get(
        '/in-invoice/list?no_paginate=1&sort=-created_at,-id',
      );
      if (mounted) setState(() => invoices = _asMapList(body));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  _IncomingReceipt? lastReceipt;
  String? feedback;
  bool checking = false, warning = false;
  int checkRevision = 0;

  Future<void> _check(_IncomingReceipt receipt) async {
    final revision = ++checkRevision;
    lastReceipt = receipt;
    final title = receipt.historical
        ? 'Баримтын үлдэгдэл'
        : 'Орлогын баримт хадгалагдлаа';
    final prefix =
        '$title · ${receipt.location}${receipt.reference.isEmpty ? '' : ' · ${receipt.reference}'}';
    setState(() {
      checking = true;
      warning = false;
      feedback = '$prefix. Үлдэгдэл шалгаж байна…';
    });
    try {
      final stocks = await _incomingStocks(api, receipt.branch);
      if (!mounted || revision != checkRevision) return;
      final report = receipt.check(stocks);
      final shown = widget.onStock(receipt.branch, stocks);
      setState(() {
        warning = !report.confirmed;
        feedback =
            '$prefix. ${report.text}'
            '${report.confirmed
                ? ''
                : receipt.historical
                ? ' Борлуулалт болон зарлагын хөдөлгөөнийг шалгана уу.'
                : ' Үлдэгдэл бүрэн баталгаажаагүй байна.'}'
            '${shown ? '' : ' Энэ үлдэгдлийг харахын тулд борлуулалтын салбараа сонгоно уу.'}';
      });
    } catch (e) {
      if (mounted && revision == checkRevision)
        setState(() {
          warning = true;
          feedback = '$prefix. Үлдэгдэл шалгаж чадсангүй: $e';
        });
    } finally {
      if (mounted && revision == checkRevision)
        setState(() => checking = false);
    }
  }

  Future<void> _afterSave(_IncomingReceipt receipt) async {
    if (!mounted) return;
    await Future.wait([_check(receipt), _load()]);
  }

  Future<void> _inspect(Map<String, dynamic> invoice) async {
    final revision = ++checkRevision;
    setState(() {
      checking = true;
      warning = false;
      lastReceipt = null;
      feedback = 'Баримтын үлдэгдэл шалгаж байна…';
    });
    try {
      final id = invoice['id'].toString();
      final details = _asMapList(
        await api.get(
          '/in-invoice/stock-detail/list?no_paginate=1&in_invoice_id=${Uri.encodeQueryComponent(id)}',
        ),
      );
      if (!mounted || revision != checkRevision) return;
      if (details.isEmpty) throw Exception('Баримтын барааны мөр олдсонгүй.');
      await _check(
        _IncomingReceipt(
          id: id,
          branch: (invoice['branch_id'] ?? details.first['branch_id'])
              .toString(),
          location: [
            invoice['branch_name'],
            ...details.map((r) => r['warehouse_name']).toSet(),
          ].whereType<String>().join(' · '),
          reference: (invoice['invoice_number'] ?? '').toString(),
          historical: true,
          expected: _availableByLocation(
            details.map(
              (r) => {...r, 'quantity': r['first_quantity'] ?? r['quantity']},
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted && revision == checkRevision)
        setState(() {
          checking = false;
          warning = true;
          feedback = 'Үлдэгдэл шалгаж чадсангүй: $e';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TopBar(
        title: 'Орлогын баримт',
        subtitle: 'Агуулахад бараа хүлээн авч, орлогын баримт бүртгэнэ.',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Хоёр агуулахаас хайх',
              icon: const Icon(Icons.warehouse_outlined),
              onPressed: widget.apiToken.isEmpty
                  ? null
                  : () => showDialog(
                      context: context,
                      builder: (_) => _WarehouseSearch(widget.apiToken),
                    ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('PI импортлох'),
              onPressed: widget.apiToken.isEmpty
                  ? null
                  : () async {
                      final saved = await Navigator.push<_IncomingReceipt>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _PiReview(
                            token: widget.apiToken,
                            branch: widget.initialBranchId,
                            reload: widget.onReload,
                          ),
                        ),
                      );
                      if (saved != null && mounted) await _afterSave(saved);
                    },
            ),
            IconButton(
              onPressed: loading ? null : _load,
              tooltip: 'Шинэчлэх',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.apiToken.isEmpty
                  ? null
                  : () async {
                      final saved = await showDialog<_IncomingReceipt>(
                        barrierDismissible: false,
                        context: context,
                        builder: (_) => _IncomingInvoiceDialog(
                          apiToken: widget.apiToken,
                          initialBranchId: widget.initialBranchId,
                          onProductSaved: widget.onReload,
                        ),
                      );
                      if (saved != null && mounted) await _afterSave(saved);
                    },
              icon: const Icon(Icons.add),
              label: const Text('Орлого нэмэх'),
            ),
          ],
        ),
      ),
      if (feedback != null)
        Material(
          color: warning ? warningSurface : activeSurface,
          child: ListTile(
            leading: Icon(
              warning ? Icons.info_outline : Icons.inventory_2_outlined,
            ),
            title: Text(feedback!),
            trailing: checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : lastReceipt == null
                ? null
                : IconButton(
                    tooltip: 'Үлдэгдэл дахин шалгах',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _check(lastReceipt!),
                  ),
          ),
        ),
      Expanded(
        child: loading
            ? const _BusyBar('Орлогын баримтыг ачаалж байна…')
            : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Орлогын баримтыг ачаалж чадсангүй: $error'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Дахин оролдох'),
                    ),
                  ],
                ),
              )
            : invoices.isEmpty
            ? const Center(child: Text('Орлогын баримт бүртгэгдээгүй байна.'))
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: invoices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panelColor,
                      border: Border.all(color: lineColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Баримтын үлдэгдэл шалгах',
                          onPressed: checking || invoice['id'] == null
                              ? null
                              : () => _inspect(invoice),
                          icon: const Icon(Icons.inventory_outlined),
                        ),
                        IconButton(
                          tooltip: 'Орлогын баримт засах',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: invoice['id'] == null
                              ? null
                              : () async {
                                  final saved =
                                      await showDialog<_IncomingReceipt>(
                                        barrierDismissible: false,
                                        context: context,
                                        builder: (_) => _IncomingInvoiceDialog(
                                          invoice: invoice,
                                          apiToken: widget.apiToken,
                                          initialBranchId:
                                              widget.initialBranchId,
                                          onProductSaved: widget.onReload,
                                        ),
                                      );
                                  if (saved != null && mounted)
                                    await _afterSave(saved);
                                },
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (invoice['invoice_number'] ?? 'Нэхэмжлэх')
                                    .toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${invoice['branch_name'] ?? 'Салбар'} · ${invoice['invoice_date'] ?? ''}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₮${_money(_asInt(invoice['total_gross_amount'] ?? invoice['total']).toDouble())}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

class _IncomingLine {
  String? sourceName;
  String sourcePrice = '', pieces = '1';
  bool pricePerPiece = false;
  String? productId, variantId, warehouseId;
  List<Map<String, dynamic>> variants = [];
  final lotNumber = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unitCost = TextEditingController(text: '0'),
      netPrice = TextEditingController(text: '0'),
      grossPrice = TextEditingController(text: '0');
  DateTime? expirationDate;
  void dispose() {
    lotNumber.dispose();
    quantity.dispose();
    unitCost.dispose();
    netPrice.dispose();
    grossPrice.dispose();
  }
}

class _IncomingInvoiceDialog extends StatefulWidget {
  final String apiToken;
  final String? initialBranchId;
  final Map<String, dynamic>? invoice, pi;
  final Future<void> Function() onProductSaved;
  const _IncomingInvoiceDialog({
    required this.apiToken,
    required this.initialBranchId,
    this.invoice,
    this.pi,
    required this.onProductSaved,
  });
  @override
  State<_IncomingInvoiceDialog> createState() => _IncomingInvoiceDialogState();
}

class _IncomingInvoiceDialogState extends State<_IncomingInvoiceDialog> {
  late final OyudentApi api = OyudentApi(widget.apiToken);
  final invoiceNumber = TextEditingController();
  DateTime invoiceDate = DateTime.now();
  final shipmentTerms = _ShipmentTerms();
  bool detailsReady = false;
  String? branchId;
  List<Map<String, dynamic>> branches = [], warehouses = [], products = [];
  final lines = <_IncomingLine>[_IncomingLine()];
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    branchId = widget.initialBranchId;
    _loadRefs();
  }

  @override
  void dispose() {
    invoiceNumber.dispose();
    for (final line in lines) line.dispose();
    super.dispose();
  }

  Future<void> _loadRefs() async {
    try {
      final values = await Future.wait([
        widget.pi?['review_products'] != null
            ? Future.value(<String, dynamic>{
                'data': widget.pi!['review_products'],
              })
            : api.get('/product/ref'),
        api.get('/branch/list?no_paginate=1'),
        api.get('/warehouse/ref/list'),
      ]);
      if (!mounted) return;
      products = _asMapList(values[0]['data']);
      branches = _asMapList(values[1]);
      warehouses = _asMapList(values[2]['data']);
      branchId ??= branches.isNotEmpty
          ? (branches.first['id'] ?? branches.first['code'])?.toString()
          : null;
      final pi = widget.pi;
      if (pi != null) {
        shipmentTerms.currency = (pi['currency'] ?? 'нийлүүлэгчийн валют')
            .toString()
            .toUpperCase();
        final terms = pi['pricing_terms'];
        if (terms is _ShipmentTerms) {
          shipmentTerms.inputs.addAll(terms.inputs);
          shipmentTerms.freightBasis = terms.freightBasis;
          shipmentTerms.vat = terms.vat;
        }
        invoiceNumber.text = (pi['invoice_number'] ?? '').toString();
        invoiceDate =
            DateTime.tryParse(pi['invoice_date'].toString()) ?? invoiceDate;
        final refs = <String, List<Map<String, dynamic>>>{};
        for (final v in _asMapList(pi['review_variants'])) {
          refs.putIfAbsent(v['product_id'].toString(), () => []).add(v);
        }
        for (final r in _asMapList(pi['items'])) {
          final id = r['product_id'] as String;
          refs[id] ??= _asMapList(
            await api.get(
              '/product/variant/list?no_paginate=1&product_id=${Uri.encodeQueryComponent(id)}',
            ),
          );
          if (!mounted) return;
          final line = _IncomingLine()
            ..productId = id
            ..variants = refs[id]!;
          if (r['chosen_branch']?.toString() == branchId &&
              warehouses.any(
                (w) => _id(w) == r['chosen_warehouse']?.toString(),
              )) {
            line.warehouseId = r['chosen_warehouse'].toString();
          }
          final keys = [r['reference'], r['barcode']]
              .whereType<Object>()
              .map((v) => v.toString().trim().toLowerCase())
              .where((v) => v.isNotEmpty)
              .toSet();
          final matches = line.variants
              .where(
                (v) => [v['sku'], v['barcode'], v['barCode']].any(
                  (code) =>
                      keys.contains(code?.toString().trim().toLowerCase()),
                ),
              )
              .toList();
          final chosen = r['chosen_variant'];
          if (chosen != null) {
            if (line.variants.any((v) => _id(v) == chosen))
              line.variantId = chosen;
          } else if (matches.length == 1)
            line.variantId = _id(matches.single);
          line.sourcePrice = (r['source_price'] ?? r['unit_cost'] ?? '')
              .toString();
          line.pieces = (r['pieces_per_unit'] ?? 1).toString();
          line.pricePerPiece = r['price_basis'] == 'piece';
          line.quantity.text = (r['quantity'] ?? '').toString();
          line.unitCost.text = pi['currency'].toString().toUpperCase() == 'MNT'
              ? (r['unit_cost'] ?? '').toString()
              : '';
          if (r['applied_cost'] != null) {
            line.unitCost.text = r['applied_cost'];
            line.netPrice.text = r['applied_net'];
            line.grossPrice.text = r['applied_gross'];
          }
          line.lotNumber.text = (r['lot'] ?? '').toString();
          line.expirationDate = DateTime.tryParse(r['expiry'].toString());
          lines.add(line);
        }
        if (lines.length > 1) lines.removeAt(0).dispose();
      }
      final invoice = widget.invoice;
      if (invoice != null) {
        final details = _asMapList(
          await api.get(
            '/in-invoice/stock-detail/list?no_paginate=1&in_invoice_id=${Uri.encodeQueryComponent(invoice['id'].toString())}',
          ),
        );
        if (!mounted) return;
        final first = details.firstOrNull;
        branchId = (first?['branch_id'] ?? invoice['branch_id'])?.toString();
        invoiceNumber.text = (invoice['invoice_number'] ?? '').toString();
        invoiceDate = DateTime.parse(
          (invoice['in_invoice_date'] ??
                  invoice['invoice_date'] ??
                  first?['in_invoice_date'] ??
                  first?['invoice_date'])
              .toString(),
        );
        final refs = <String, List<Map<String, dynamic>>>{};
        for (final row in details) {
          final id = row['product_id'].toString();
          refs[id] ??= _asMapList(
            await api.get(
              '/product/variant/list?no_paginate=1&product_id=${Uri.encodeQueryComponent(id)}',
            ),
          );
          if (!mounted) return;
          final line = _IncomingLine()
            ..productId = id
            ..variantId = row['variant_id']?.toString()
            ..variants = refs[id]!
            ..warehouseId = row['warehouse_id']?.toString();
          line.quantity.text = (row['quantity'] ?? 0).toString();
          line.unitCost.text = (row['unit_cost'] ?? 0).toString();
          line.netPrice.text = (row['net_unit_price'] ?? 0).toString();
          line.grossPrice.text = (row['gross_unit_price'] ?? 0).toString();
          line.lotNumber.text = (row['note'] ?? '').toString();
          final date = DateTime.tryParse(row['expiration_date'].toString());
          line.expirationDate = date != null && date.year > 1 ? date : null;
          lines.add(line);
        }
        if (details.isNotEmpty) lines.removeAt(0).dispose();
      }
      detailsReady = true;
      setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  String _label(Map<String, dynamic> m) =>
      ((m['mn_name'] ??
              m['mnName'] ??
              m['name'] ??
              m['title'] ??
              m['barcode'] ??
              '')
          .toString());
  String _id(Map<String, dynamic> m) => (m['id'] ?? m['code'] ?? '').toString();
  Future<void> _loadVariants(int index, String productId) async {
    try {
      final body = await api.get(
        '/product/variant/list?no_paginate=1&product_id=$productId',
      );
      final values = _asMapList(body);
      if (mounted &&
          index < lines.length &&
          lines[index].productId == productId)
        setState(() {
          lines[index].variants = values;
          lines[index].variantId = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  double get _grossTotal => lines.fold(
    0,
    (sum, line) =>
        (sum +
        (double.tryParse(line.grossPrice.text) ?? 0) *
            (double.tryParse(line.quantity.text) ?? 0)),
  );
  List<Map<String, dynamic>> _invoiceItems() {
    final grouped = <String, Map<String, dynamic>>{};
    for (final line in lines) {
      final date = line.expirationDate?.toIso8601String().substring(0, 10);
      final item = <String, dynamic>{
        'branch_id': branchId,
        'product_id': line.productId,
        'product_variant_id': line.variantId,
        'unit_cost': double.tryParse(line.unitCost.text) ?? 0,
        'net_unit_price': double.tryParse(line.netPrice.text) ?? 0,
        'gross_unit_price': double.tryParse(line.grossPrice.text) ?? 0,
        'expiration_date': date == null ? null : '$date 00:00',
      };
      final group = grouped.putIfAbsent(
        jsonEncode(item),
        () => {...item, 'lines': <Map<String, dynamic>>[]},
      );
      (group['lines'] as List).add({
        'warehouse_id': line.warehouseId,
        'quantity': num.parse(line.quantity.text.trim()),
        'note': line.lotNumber.text.trim(),
      });
    }
    return grouped.values.toList();
  }

  Future<void> _save() async {
    if (saving || !detailsReady) return;
    if (branchId == null || branchId!.isEmpty) {
      setState(() => error = 'Салбар сонгоно уу.');
      return;
    }
    if (widget.pi != null &&
        lines.any((line) => double.tryParse(line.unitCost.text) == null)) {
      setState(
        () => error = 'Импортолсон мөр бүрийн нэгж өртгийг төгрөгөөр оруулж баталгаажуулна уу.',
      );
      return;
    }
    for (final (index, line) in lines.indexed) {
      final quantity = num.tryParse(line.quantity.text.trim());
      final missing = <String>[
        if ((line.productId ?? '').isEmpty) 'бараа',
        if ((line.variantId ?? '').isEmpty) 'хувилбар',
        if ((line.warehouseId ?? '').isEmpty) 'агуулах',
        if (quantity == null || !quantity.isFinite || quantity <= 0)
          'эерэг тоо хэмжээ',
      ];
      if (missing.isNotEmpty) {
        setState(
          () => error = '${index + 1}-р мөр: ${missing.join(', ')} оруулна уу.',
        );
        return;
      }
      for (final field in [line.unitCost, line.netPrice, line.grossPrice]) {
        if (field.text.trim().isEmpty) continue;
        final n = num.tryParse(field.text.trim());
        if (n == null || !n.isFinite || n < 0) {
          setState(
            () => error = '${index + 1}-р мөрийн өртөг, үнийг шалгана уу.',
          );
          return;
        }
      }
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final branch = branchId!;
      final expected = _availableByLocation(
        lines.map(
          (l) => <String, dynamic>{
            'product_id': l.productId,
            'variant_id': l.variantId,
            'warehouse_id': l.warehouseId,
            'quantity': l.quantity.text,
          },
        ),
      );
      final names = [
        _label(branches.firstWhere((b) => _id(b) == branch)),
        ...warehouses
            .where((w) => lines.any((l) => l.warehouseId == _id(w)))
            .map(_label),
      ];
      final payload = <String, dynamic>{
        if (widget.invoice != null) 'id': widget.invoice!['id'],
        'branchId': branchId,
        'invoice_number': invoiceNumber.text.trim(),
        'in_invoice_date':
            '${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}-${invoiceDate.day.toString().padLeft(2, '0')}',
        'list': _invoiceItems(),
      };
      Map<_IncomingKey, num>? before;
      if (widget.invoice == null) {
        try {
          before = _availableByLocation(
            await _incomingStocks(
              api,
              branch,
              limit: const Duration(seconds: 8),
            ),
          );
        } catch (_) {
          /* The invoice can still be saved if the stock service is unavailable. */
        }
      }
      if (!mounted) return;
      final response = await api.post('/in-invoice/', payload);
      if (response['status'] != 'success')
        throw const FormatException(
          'Хадгалалт баталгаажаагүй. Дахин илгээхээс өмнө баримтын жагсаалтаа шалгана уу.',
        );
      final data = response['data'];
      final id =
          widget.invoice?['id'] ??
          (data is Map ? (data['in_invoice_id'] ?? data['id']) : null) ??
          response['id'];
      if (mounted)
        Navigator.pop(
          context,
          _IncomingReceipt(
            branch: branch,
            location: names.join(' · '),
            expected: expected,
            reference: payload['invoice_number'].toString(),
            id: id?.toString(),
            before: before,
          ),
        );
    } catch (e) {
      if (mounted) {
        final message =
            e is TimeoutException ||
                e is SocketException ||
                e is http.ClientException
            ? 'Серверийн хариу ирсэнгүй. Дахин хадгалахаас өмнө баримтын жагсаалт, үлдэгдлээ шалгана уу.'
            : e.toString().replaceFirst('Exception: ', '');
        setState(() => error = message);
        _notice(context, message, failed: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Dialog(
      child: SizedBox(
        width: 950,
        height: 750,
        child: loading
            ? const _BusyBar('Орлогын баримтыг ачаалж байна…')
            : AbsorbPointer(
                absorbing: saving,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.invoice == null
                                  ? 'Орлого нэмэх'
                                  : 'Орлого засах',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(22),
                        children: [
                          _ShipmentPricing(
                            lines: lines,
                            terms: shipmentTerms,
                            products: products,
                            onApply: () => setState(() {}),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: invoiceDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (date != null) {
                                      setState(() => invoiceDate = date);
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    'Баримтын огноо · ${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}-${invoiceDate.day.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ReferenceDropdown(
                                  initialValue: branchId,
                                  decoration: const InputDecoration(
                                    labelText: 'Салбар',
                                  ),
                                  items: branches
                                      .map(
                                        (x) => DropdownMenuItem(
                                          value: _id(x),
                                          child: Text(_label(x)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => branchId = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: invoiceNumber,
                                  decoration: const InputDecoration(
                                    labelText: 'Нийлүүлэгчийн нэхэмжлэхийн дугаар (заавал биш)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...lines.asMap().entries.map((entry) {
                            final index = entry.key;
                            final line = entry.value;
                            return Card(
                              color: inputSurface,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Барааны мөр ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Бараа, хувилбар засах',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed:
                                              line.productId == null || saving
                                              ? null
                                              : () async {
                                                  final id = line.productId!;
                                                  final saved =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (_) =>
                                                            _ProductCreateDialog(
                                                              apiToken: widget
                                                                  .apiToken,
                                                              editId: id,
                                                            ),
                                                      );
                                                  if (saved != true || !mounted)
                                                    return;
                                                  try {
                                                    final values =
                                                        await Future.wait([
                                                          api.get(
                                                            '/product/ref',
                                                          ),
                                                          api.get(
                                                            '/product/variant/list?no_paginate=1&product_id=${Uri.encodeQueryComponent(id)}',
                                                          ),
                                                        ]);
                                                    if (!mounted) return;
                                                    setState(() {
                                                      products = _asMapList(
                                                        values.first,
                                                      );
                                                      for (final item
                                                          in lines.where(
                                                            (r) =>
                                                                r.productId ==
                                                                id,
                                                          )) {
                                                        item.variants =
                                                            _asMapList(
                                                              values.last,
                                                            );
                                                      }
                                                    });
                                                    await widget
                                                        .onProductSaved();
                                                  } catch (e) {
                                                    if (mounted)
                                                      setState(
                                                        () => error = e
                                                            .toString(),
                                                      );
                                                  }
                                                },
                                        ),
                                        IconButton(
                                          onPressed: lines.length <= 1
                                              ? null
                                              : () => setState(
                                                  () => lines
                                                      .removeAt(index)
                                                      .dispose(),
                                                ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: _ReferenceDropdown(
                                            initialValue: line.productId,
                                            decoration: const InputDecoration(
                                              labelText: 'Бараа',
                                            ),
                                            items: products
                                                .map(
                                                  (x) => DropdownMenuItem(
                                                    value: _id(x),
                                                    child: Text(
                                                      _label(x),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) {
                                              setState(() {
                                                line.productId = v;
                                                line.variantId = null;
                                                line.variants = [];
                                              });
                                              if (v != null)
                                                _loadVariants(index, v);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 2,
                                          child: _ReferenceDropdown(
                                            initialValue: line.variantId,
                                            decoration: const InputDecoration(
                                              labelText: 'Хувилбар / баркод',
                                            ),
                                            items: line.variants
                                                .map(
                                                  (x) => DropdownMenuItem(
                                                    value: _id(x),
                                                    child: Text(
                                                      [
                                                            x['barcode'] ??
                                                                x['barCode'],
                                                            x['sku'],
                                                            x['size_name'],
                                                            x['color_name'],
                                                            x['unit_name'],
                                                          ]
                                                          .whereType<String>()
                                                          .where(
                                                            (v) => v.isNotEmpty,
                                                          )
                                                          .join(' · '),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) => setState(
                                              () => line.variantId = v,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 2,
                                          child: _ReferenceDropdown(
                                            initialValue: line.warehouseId,
                                            decoration: const InputDecoration(
                                              labelText: 'Агуулах',
                                            ),
                                            items: warehouses
                                                .map(
                                                  (x) => DropdownMenuItem(
                                                    value: _id(x),
                                                    child: Text(
                                                      _label(x),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) => setState(
                                              () => line.warehouseId = v,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                      controller: line.lotNumber,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Агуулахын тэмдэглэл / лот дугаар',
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: line.quantity,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Тоо хэмжээ',
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: line.unitCost,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Нэгж өртөг',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: line.netPrice,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'НӨАТ-гүй үнэ',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: line.grossPrice,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'НӨАТ-тай үнэ',
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  line.expirationDate ??
                                                  DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (d != null)
                                              setState(
                                                () => line.expirationDate = d,
                                              );
                                          },
                                          child: Text(
                                            line.expirationDate == null
                                                ? 'Дуусах огноо'
                                                : '${line.expirationDate!.year}-${line.expirationDate!.month}-${line.expirationDate!.day}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => lines.add(_IncomingLine())),
                                icon: const Icon(Icons.add),
                                label: const Text('Мөр нэмэх'),
                              ),
                              const Spacer(),
                              Text(
                                'Нийт дүн: ₮${_money(_grossTotal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final created = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => _ProductCreateDialog(
                                        apiToken: widget.apiToken,
                                      ),
                                    );
                                    if (created == true) {
                                      await widget.onProductSaved();
                                      final result = await api.get(
                                        '/product/ref',
                                      );
                                      if (mounted)
                                        setState(
                                          () => products = _asMapList(
                                            result['data'],
                                          ),
                                        );
                                    }
                                  },
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Шинэ бараа, хувилбар нэмэх'),
                          ),
                        ],
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: errorInk),
                        ),
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Хаах'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: saving || loading || !detailsReady
                                ? null
                                : _save,
                            child: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Орлогын баримт хадгалах'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
