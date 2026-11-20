part of '../main.dart';

class _WarehouseSearch extends StatefulWidget {
  final String token, query, maker;
  final List<Map<String, dynamic>>? cachedStocks, knownProducts;
  final ValueChanged<List<Map<String, dynamic>>>? onLoaded;
  final bool selectable;
  final bool orderBranchOnly;
  const _WarehouseSearch(
    this.token, {
    this.query = '',
    this.maker = '',
    this.selectable = false,
    this.orderBranchOnly = false,
    this.cachedStocks,
    this.knownProducts,
    this.onLoaded,
  });
  @override
  State<_WarehouseSearch> createState() => _WarehouseSearchState();
}

class _WarehouseSearchState extends State<_WarehouseSearch> {
  late String query = widget.query, maker = widget.maker;
  String scope = 'Хоёулаа';
  bool loading = true;
  String? error;
  List<Product> stocks = [];
  String norm(dynamic v) => (v ?? '')
      .toString()
      .toLowerCase()
      .replaceAll('besmile', 'bsm')
      .replaceAll('циркон', 'zirconia')
      .replaceAll('0m', 'om');
  @override
  void initState() {
    super.initState();
    if (widget.cachedStocks != null) {
      stocks = widget.cachedStocks!.map(Product.fromApi).toList();
      loading = false;
    } else {
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = OyudentApi(widget.token);
      final refs = await Future.wait([
        api.get('/branch/ref'),
        if (widget.knownProducts == null)
          api.get('/product/list?no_paginate=1'),
      ]);
      final catalog = {
        for (final p in widget.knownProducts ?? _asMapList(refs[1])) p['id']: p,
      };
      final groups = await Future.wait(
        _asMapList(refs[0])
            .where(
              (b) => [
                'оюудент',
                'сэнтех',
                'oyudent',
                'centech',
              ].contains(norm(b['name']).trim()),
            )
            .map((b) async {
              final data = await api.get(
                '/order/get-available-stocks?branch_id=${Uri.encodeQueryComponent(b['id'].toString())}',
              );
              return _asMapList(data)
                  .where((r) => (num.tryParse('${r['quantity']}') ?? 0) > 0)
                  .map(
                    (r) => <String, dynamic>{
                      ...?catalog[r['product_id']],
                      ...r,
                      'scope':
                          ['сэнтех', 'centech'].contains(norm(b['name']).trim())
                          ? 'Centech'
                          : 'Oyudent',
                    },
                  )
                  .toList();
            }),
      );
      if (mounted) {
        final rows = groups.expand((g) => g).toList();
        setState(() => stocks = rows.map(Product.fromApi).toList());
        widget.onLoaded?.call(rows);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = norm(query)
        .split(RegExp(r'[^a-zа-яёөү0-9]+'))
        .where((x) => x.isNotEmpty)
        .toSet();
    final matches = <({int score, Product product})>[];
    for (final product in stocks) {
      final row = product.apiStock!;
      if (scope != 'Хоёулаа' && scope != row['scope']) continue;
      final brand = norm(row['supplier_name']).trim();
      final preferred =
          brand.isNotEmpty &&
          maker.trim().isNotEmpty &&
          (norm(maker).contains(brand) || brand.contains(norm(maker).trim()));
      if (maker.trim().isNotEmpty && !preferred) continue;
      final text = norm(
        [
          row['product_name'],
          row['product_mn_name'],
          row['size_name'],
          row['color_name'],
          row['sku'],
          row['product_code'],
          row['reference'],
          row['lot_number'],
          row['lot_no'],
          row['barcode'],
          row['warehouse_name'],
          brand,
        ].join(' '),
      );
      final count = words.where(text.contains).length;
      if (words.isNotEmpty && count == 0 && !preferred) continue;
      if (words.isEmpty && maker.trim().isNotEmpty && !preferred) continue;
      matches.add((
        score:
            (preferred ? 10000 : 0) +
            count * 10 +
            (query.trim().isNotEmpty && text.contains(norm(query).trim())
                ? 5
                : 0),
        product: product,
      ));
    }
    if (words.isNotEmpty) matches.sort((a, b) => b.score.compareTo(a.score));
    final groups = _ProductGroup.byProduct(matches.map((m) => m.product));
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Агуулахын үлдэгдэл хайх',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (!widget.orderBranchOnly)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in ['Хоёулаа', 'Centech', 'Oyudent'])
                      ChoiceChip(
                        label: Text(s),
                        selected: scope == s,
                        onSelected: (_) => setState(() => scope = s),
                      ),
                  ],
                ),
              TextFormField(
                initialValue: maker,
                decoration: const InputDecoration(labelText: 'Үйлдвэрлэгч'),
                onChanged: (s) => setState(() => maker = s),
              ),
              TextFormField(
                initialValue: query,
                decoration: const InputDecoration(
                  labelText: 'Барааны нэр, лавлах дугаар, хэмжээ эсвэл өнгө',
                ),
                onChanged: (s) => setState(() => query = s),
              ),
              if (widget.selectable && !widget.orderBranchOnly)
                TextButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Тохирох үлдэгдэл алга уу? Каталогоос хувилбар сонгох',
                  ),
                  onPressed: () =>
                      Navigator.pop(context, {'browse_catalog': true}),
                ),
              Expanded(
                child: loading
                    ? const _BusyBar('Агуулахын үлдэгдлийг ачаалж байна…')
                    : error != null
                    ? Center(
                        child: TextButton(
                          onPressed: load,
                          child: Text('$error · Дахин оролдох'),
                        ),
                      )
                    : matches.isEmpty
                    ? const Center(
                        child: Text(
                          'Хайлтанд тохирох үлдэгдэлтэй бараа олдсонгүй.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (_, i) {
                          final group = groups[i];
                          final p = group.product;
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                              group.multiple
                                  ? group.optionsLabel
                                  : [
                                      p.apiStock?['scope'],
                                      _optionDescription(p),
                                    ].whereType<String>().join(' · '),
                            ),
                            trailing: Text(
                              'Үлдэгдэл: ${_stockText(group.branchQuantity)}',
                            ),
                            onTap: group.multiple || widget.selectable
                                ? () async {
                                    final choice = group.multiple
                                        ? await showDialog<Product>(
                                            context: context,
                                            builder: (_) => _StockOptions(
                                              group: group,
                                              query: '',
                                              stockFor: (p) => p.oyudentStock,
                                              selectable: widget.selectable,
                                            ),
                                          )
                                        : p;
                                    if (mounted &&
                                        widget.selectable &&
                                        choice != null)
                                      Navigator.pop(context, choice.apiStock);
                                  }
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
