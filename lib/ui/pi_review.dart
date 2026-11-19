part of '../main.dart';

const _piFieldNames = {
  'manufacturer': 'Үйлдвэрлэгч',
  'specification': 'Үзүүлэлт',
  'purchase_unit': 'Худалдан авах нэгж',
  'pieces_per_unit': 'Нэгж дэх ширхэг',
  'reference': 'Лавлах дугаар',
  'barcode': 'Баркод',
  'quantity': 'Тоо хэмжээ',
  'unit_cost': 'Нэгж өртөг',
  'lot': 'Лот дугаар',
  'expiry': 'Дуусах огноо',
};

class _PiReview extends StatefulWidget {
  final String token;
  final String? branch;
  final Future<void> Function() reload;
  const _PiReview({
    required this.token,
    required this.branch,
    required this.reload,
  });
  @override
  State<_PiReview> createState() => _PiReviewState();
}

class _PiReviewState extends State<_PiReview> {
  final secret = TextEditingController(
    text: Platform.environment['MOONSHOT_API_KEY'] ?? '',
  );
  final paste = TextEditingController();
  PlatformFile? file;
  bool converted = false;
  bool busy = false;
  String stage = '';
  double? progress;
  int run = 0;
  void report(String label, [double? fraction]) {
    if (mounted && busy)
      setState(() {
        stage = label;
        progress = fraction;
      });
  }

  String? error;
  Map<String, dynamic>? draft;
  List<Map<String, dynamic>> items = [], catalog = [];
  List<Map<String, dynamic>> variantCatalog = [];
  final pricingLines = <_IncomingLine>[];
  var terms = _ShipmentTerms();
  bool priceStep = false;
  int get variantCount =>
      items.where((r) => r['chosen_variant'] != null).length;
  List<Map<String, dynamic>>? warehouseCache;
  String brandKey(Object? v) {
    final n = norm(v);
    return RegExp(r'\b(besmile|bsm)\b').hasMatch(n) ? 'bsm' : n;
  }

  String? appliedSignature;
  String get pricingSignature => jsonEncode([
    terms.inputs,
    terms.freightBasis,
    terms.vat,
    for (final l in pricingLines)
      [l.sourcePrice, l.pricePerPiece, l.pieces, l.quantity.text],
  ]);
  final selected = <int, String>{};
  @override
  void dispose() {
    for (final l in pricingLines) l.dispose();
    secret.dispose();
    paste.dispose();
    super.dispose();
  }

  String norm(dynamic value) => (value ?? '').toString().trim().toLowerCase();
  String id(Map row) => (row['id'] ?? row['product_id'] ?? '').toString();
  Future<List<Map<String, dynamic>>> products() async => _asMapList(
    await OyudentApi(widget.token).get(
      '/product/list?no_paginate=1',
      stage: 'Оюудентийн барааны каталогийг ачаалж байна',
      limit: const Duration(minutes: 1),
    ),
  ).where((r) => id(r).isNotEmpty).toList();
  Future<void> analyze() async {
    if (busy) return;
    final active = ++run;
    setState(() {
      stage = 'Оюудентийн барааг ачаалж байна…';
      progress = null;
      busy = true;
      error = null;
    });
    try {
      final refs = await importStep(
        'Оюудентийн барааг ачаалж байна',
        (_) => products(),
        report: report,
        active: () => mounted,
      );
      if (!mounted) return;

      final variants = _asMapList(
        await importStep(
          'Барааны хувилбаруудыг ачаалж байна',
          (_) => OyudentApi(widget.token).get(
            '/product/variant/list?no_paginate=1',
            stage: 'Барааны хувилбаруудыг ачаалж байна',
            limit: const Duration(minutes: 1),
          ),
          report: report,
          active: () => mounted,
        ),
      );
      if (!mounted) return;
      final byId = {for (final p in refs) id(p): p};
      Map<String, List<Map<String, dynamic>>> index(
        List<Map<String, dynamic>> records,
        List<String> columns,
      ) {
        final out = <String, List<Map<String, dynamic>>>{};
        for (final record in records) {
          for (final key
              in columns
                  .map((col) => norm(record[col]))
                  .where((v) => v.isNotEmpty)
                  .toSet()) {
            (out[key] ??= []).add(record);
          }
        }
        return out;
      }

      final variantKeys = index(variants, ['sku', 'barcode']);
      final productKeys = index(refs, ['code', 'sku', 'barcode']);
      final productNames = index(refs, ['name', 'mn_name', 'english_name']);

      final result = converted
          ? await compute(readInvoiceExcel, file!.bytes!)
          : await KimiPi.read(
              secret.text.trim(),
              file,
              paste.text.trim(),
              active: () => mounted && active == run,
              onStage: (label) {
                if (active == run) report(label);
              },
            );
      final rows = _asMapList(result['items']);
      if (!mounted) return;
      final matches = <int, String>{};
      for (var i = 0; i < rows.length; i++) {
        if (i % 8 == 0) {
          report(
            'Каталогтой тулгаж байна · ${rows.length} мөрөөс $i',
            i / rows.length,
          );
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
        }
        final r = rows[i];
        final sources = [
          r['manufacturer'],
          result['manufacturer'],
        ].where((v) => norm(v).isNotEmpty);
        final maker = brandKey(
          sources.firstOrNull ??
              (brandKey(result['supplier']) == 'bsm' ? 'BSM' : ''),
        );
        r['review_brand'] = maker;
        final rawName = norm(r['name']);
        final generic = RegExp(
          r'^dental (?:porcelain|procelain|porcelin)(?: powder)?$',
        );
        if (generic.hasMatch(rawName)) {
          r['category'] = r['name'];
          r['name'] = r['specification'] ?? r['reference'];
        }
        bool makerFits(Map? p) {
          final brand = brandKey(p?['supplier_name']);
          return maker.isEmpty || brand == maker;
        }

        final keys = [
          r['reference'],
          r['barcode'],
        ].map(norm).where((s) => s.isNotEmpty).toSet();
        final variantHits = {for (final key in keys) ...?variantKeys[key]}
            .where((v) => makerFits(byId[v['product_id']?.toString()]))
            .toList();
        if (variantHits.isNotEmpty) {
          final parents = variantHits
              .map((v) => v['product_id'].toString())
              .toSet();
          if (variantHits.length == 1) {
            r['chosen_variant'] = variantHits.single['id']?.toString();
            r['chosen_label'] = variantLabel(variantHits.single);
          }
          if (parents.length == 1 && byId.containsKey(parents.single))
            matches[i] = parents.single;
          continue;
        }
        var hits = {for (final key in keys) ...?productKeys[key]}
            .where(makerFits)
            .toList();
        if (hits.isEmpty)
          hits = productNames[norm(r['name'])]?.where(makerFits).toList() ?? [];
        if (hits.length == 1) matches[i] = id(hits.single);
      }
      setState(() {
        draft = result;
        items = rows;
        catalog = refs;
        warehouseCache = null;
        priceStep = false;
        variantCatalog = [
          for (final v in variants)
            {
              ...v,
              'supplier_name':
                  byId[v['product_id']?.toString()]?['supplier_name'],
              'search_text': norm(variantLabel(v)),
            },
        ];
        for (final l in pricingLines) l.dispose();
        pricingLines.clear();
        appliedSignature = null;
        terms = _ShipmentTerms()
          ..currency = (result['currency'] ?? 'нийлүүлэгчийн валют')
              .toString()
              .toUpperCase();
        if (terms.currency == 'MNT') terms.inputs['Валютын ханш · ₮/¥'] = '1';
        for (final r in rows) {
          pricingLines.add(
            _IncomingLine()
              ..sourceName = r['name']?.toString()
              ..quantity.text = (r['quantity'] ?? '').toString()
              ..sourcePrice = (r['unit_cost'] ?? '').toString()
              ..pieces = (r['pieces_per_unit'] ?? 1).toString()
              ..pricePerPiece = (r['price_basis'] == 'piece'),
          );
        }
        selected
          ..clear()
          ..addAll(matches);
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create(int i) async {
    final row = items[i];
    String? created;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _ProductCreateDialog(
          apiToken: widget.token,
          seedName: row['name']?.toString(),
          seedReference: row['reference']?.toString(),
          onCreated: (v) => created = v,
        ),
      );
      if (saved != true || created == null || !mounted) return;
      // Keep the confirmed ID even if a subsequent catalog refresh fails.
      setState(() {
        catalog.add({
          'id': created,
          'name': row['name'],
          'code': row['reference'],
        });
        selected[i] = created!;
        for (var j = 0; j < items.length; j++) {
          if (norm(row['reference']).isNotEmpty &&
              norm(items[j]['reference']) == norm(row['reference']))
            selected.putIfAbsent(j, () => created!);
        }
      });
      final added = _asMapList(
        await OyudentApi(widget.token).get(
          '/product/variant/list?no_paginate=1&product_id=${Uri.encodeQueryComponent(created!)}',
        ),
      );
      final detail = await OyudentApi(widget.token)
          .get('/product/${Uri.encodeComponent(created!)}');
      if (!mounted) return;
      final data = detail['data'];
      final supplier = data is Map
          ? data['supplierName'] ?? data['supplier_name']
          : null;
      setState(() {
        variantCatalog.addAll(
          added.map(
            (v) => {...v, 'supplier_name': supplier ?? row['review_brand']},
          ),
        );
        if (added.length == 1) {
          row['chosen_variant'] = id(added.single);
          row['chosen_label'] = variantLabel(added.single);
        }
      });
      await widget.reload();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  String variantLabel(Map v) => [
    v['product_name'],
    v['product_mn_name'],
    v['size_name'],
    v['color_name'],
    v['unit_name'],
    v['barcode'],
    v['sku'],
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
  Future<void> chooseVariant(int i) async {
    var query =
        (items[i]['specification'] ??
                items[i]['reference'] ??
                items[i]['name'] ??
                '')
            .toString();
    var maker = brandKey(items[i]['review_brand']);
    final brands =
        variantCatalog
            .map((v) => brandKey(v['supplier_name']))
            .where((b) => b.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (maker.isNotEmpty && !brands.contains(maker)) brands.add(maker);
    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          final brand = maker;
          final words = norm(query)
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty);
          final options = variantCatalog.where((v) {
            final b = brandKey(v['supplier_name']);
            return (brand.isEmpty || brand == b) &&
                words.every(
                  ((v['search_text'] as String?) ?? norm(variantLabel(v)))
                      .contains,
                );
          }).toList();
          options.sort(
            (a, b) => (b['product_id'] == selected[i] ? 1 : 0).compareTo(
              a['product_id'] == selected[i] ? 1 : 0,
            ),
          );
          return AlertDialog(
            title: const Text('Каталогоос хувилбар сонгох'),
            content: SizedBox(
              width: 620,
              height: 440,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: maker,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Үйлдвэрлэгч'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Бүх үйлдвэрлэгч'),
                      ),
                      for (final b in brands)
                        DropdownMenuItem(
                          value: b,
                          child: Text(b.toUpperCase()),
                        ),
                    ],
                    onChanged: (b) => refresh(() => maker = b ?? ''),
                  ),
                  TextFormField(
                    initialValue: query,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Нэр, хэмжээ, өнгө, баркод эсвэл SKU-аар хайх',
                    ),
                    onChanged: (v) => refresh(() => query = v),
                  ),
                  Expanded(
                    child: options.isEmpty
                        ? const Center(
                            child: Text(
                              'Хувилбар олдсонгүй. Хайлт эсвэл үйлдвэрлэгчээ солино уу.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: options.length,
                            itemBuilder: (_, j) => ListTile(
                              title: Text(variantLabel(options[j])),
                              subtitle: Text(
                                (options[j]['supplier_name'] ?? '').toString(),
                              ),
                              onTap: () => Navigator.pop(ctx, options[j]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Болих'),
              ),
            ],
          );
        },
      ),
    );
    if (choice != null && mounted)
      setState(() {
        items[i].remove('chosen_warehouse');
        items[i].remove('chosen_branch');
        items[i]['review_brand'] = brandKey(choice['supplier_name']);
        selected[i] = choice['product_id'].toString();
        items[i]['chosen_variant'] = choice['id'].toString();
        items[i]['chosen_label'] = variantLabel(choice);
      });
  }

  Future<void> review() async {
    if (appliedSignature != null && appliedSignature != pricingSignature) {
      _notice(
        context,
        'Үнэ өөрчлөгдсөн байна. Үргэлжлүүлэхийн өмнө шинэ үнийг мөрүүдэд оруулна уу.',
        failed: true,
      );
      return;
    }
    final saved = await showDialog<_IncomingReceipt>(
      barrierDismissible: false,
      context: context,
      builder: (_) => _IncomingInvoiceDialog(
        apiToken: widget.token,
        initialBranchId: widget.branch,
        onProductSaved: widget.reload,
        pi: {
          ...draft!,
          'pricing_terms': terms,
          'review_products': catalog,
          'review_variants': variantCatalog,
          'items': [
            for (var i = 0; i < items.length; i++)
              {
                ...items[i],
                'product_id': selected[i],
                'source_price': pricingLines[i].sourcePrice,
                'pieces_per_unit': pricingLines[i].pieces,
                'price_basis': pricingLines[i].pricePerPiece
                    ? 'piece'
                    : 'purchase_unit',
                if (appliedSignature == pricingSignature) ...{
                  'applied_cost': pricingLines[i].unitCost.text,
                  'applied_net': pricingLines[i].netPrice.text,
                  'applied_gross': pricingLines[i].grossPrice.text,
                },
              },
          ],
        },
      ),
    );
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Урьдчилсан нэхэмжлэх импортлох')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (draft == null) ...[
              _PiImportPanel(
                secret: secret,
                paste: paste,
                file: file,
                busy: busy,
                stage: stage,
                progress: progress,
                retry: error != null,
                converted: converted,
                onFile: (f, ready) => setState(() {
                  converted = ready;
                  file = f;
                  error = null;
                }),
                onError: (e) => setState(() => error = e),
                onImport: analyze,
              ),
            ] else ...[
              Text(
                'Нэхэмжлэх шалгах · ${draft!['invoice_number'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${items.length} мөр · Валют: ${draft!['currency'] ?? "тодорхойгүй"}',
              ),
              const SizedBox(height: 12),
              Text('${items.length} мөрөөс $variantCount хувилбар сонгосон'),
              LinearProgressIndicator(
                value: items.isEmpty ? 0 : variantCount / items.length,
                semanticsLabel: 'Каталогоос сонгосон бараа',
              ),
              const SizedBox(height: 12),
              if (!priceStep) ...[
                for (var i = 0; i < items.length; i++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${i + 1}. ${items[i]['name'] ?? items[i]['reference'] ?? items[i]['barcode']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            [
                              for (final k in [
                                'manufacturer',
                                'specification',
                                'purchase_unit',
                                'pieces_per_unit',
                                'reference',
                                'barcode',
                                'quantity',
                                'unit_cost',
                                'lot',
                                'expiry',
                              ])
                                if (items[i][k] != null)
                                  '${_piFieldNames[k] ?? k}: ${items[i][k]}',
                            ].join(' · '),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: const Icon(Icons.warehouse_outlined),
                              label: const Text(
                                'Агуулахаас төстэй хувилбар хайх',
                              ),
                              onPressed: () async {
                                final row = items[i];
                                final choice =
                                    await showDialog<Map<String, dynamic>>(
                                      context: context,
                                      builder: (_) => _WarehouseSearch(
                                        widget.token,
                                        selectable: true,
                                        cachedStocks: warehouseCache,
                                        onLoaded: (v) => warehouseCache = v,
                                        knownProducts: catalog,
                                        query:
                                            (row['specification'] ??
                                                    row['name'] ??
                                                    '')
                                                .toString(),
                                        maker:
                                            row['review_brand']?.toString() ??
                                            '',
                                      ),
                                    );
                                if (choice == null || !mounted) return;
                                if (choice['browse_catalog'] == true) {
                                  await chooseVariant(i);
                                  return;
                                }
                                setState(() {
                                  selected[i] = choice['product_id'].toString();
                                  row['chosen_branch'] = choice['branch_id'];
                                  row['chosen_warehouse'] =
                                      choice['warehouse_id'];
                                  row['chosen_variant'] = choice['variant_id']
                                      ?.toString();
                                  row['chosen_label'] = [
                                    choice['product_name'],
                                    choice['size_name'],
                                    choice['color_name'],
                                    choice['scope'],
                                    choice['warehouse_name'],
                                  ].whereType<String>().join(' · ');
                                });
                              },
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.search),
                            label: const Text(
                              'Бүрэн каталогоос хувилбар сонгох',
                            ),
                            onPressed: () => chooseVariant(i),
                          ),
                          if (items[i]['chosen_label'] != null)
                            Text(items[i]['chosen_label'].toString()),
                          if (items[i]['chosen_variant'] == null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add),
                                onPressed: () => create(i),
                                label: const Text(
                                  'Бүртгэлгүй барааг шалгаж нэмэх',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: variantCount == items.length
                      ? () => setState(() {
                          priceStep = true;
                          for (var i = 0; i < items.length; i++) {
                            pricingLines[i].sourceName =
                                items[i]['chosen_label']?.toString();
                          }
                        })
                      : null,
                  child: const Text('Хувилбараа баталгаажуулж үнэ сонгох'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => setState(() => priceStep = false),
                  child: const Text('Хувилбар сонголт руу буцах'),
                ),
                _ShipmentPricing(
                  expanded: true,
                  lines: pricingLines,
                  products: catalog,
                  terms: terms,
                  onApply: () =>
                      setState(() => appliedSignature = pricingSignature),
                ),
                FilledButton(
                  onPressed: appliedSignature == null ? null : review,
                  child: const Text('Үнэ тооцсон орлогын баримтыг шалгах'),
                ),
              ],
              TextButton(
                onPressed: () => setState(() {
                  draft = null;
                  error = null;
                }),
                child: const Text('Өөр нэхэмжлэх сонгох'),
              ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
  );
}
