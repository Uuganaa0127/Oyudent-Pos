part of '../main.dart';

class _WarehouseSearch extends StatefulWidget {
  final String token, query, maker;
  final List<Map<String, dynamic>>? cachedStocks, knownProducts;
  final ValueChanged<List<Map<String, dynamic>>>? onLoaded;
  final bool selectable;
  const _WarehouseSearch(
    this.token, {
    this.query = '',
    this.maker = '',
    this.selectable = false,
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
  List<Map<String, dynamic>> stocks = [];
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
      stocks = widget.cachedStocks!;
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
        setState(() => stocks = groups.expand((g) => g).toList());
        widget.onLoaded?.call(stocks);
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
    final matches = <({int score, Map<String, dynamic> row})>[];
    for (final row in stocks) {
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
          row['barcode'],
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
        row: row,
      ));
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
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
              if (widget.selectable)
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
                        itemCount: matches.length,
                        itemBuilder: (_, i) {
                          final r = matches[i].row;
                          return ListTile(
                            title: Text(
                              [
                                r['product_name'],
                                r['product_mn_name'],
                              ].whereType<String>().join(' · '),
                            ),
                            subtitle: Text(
                              [
                                    r['supplier_name'],
                                    r['size_name'],
                                    r['color_name'],
                                    r['barcode'],
                                    r['scope'],
                                    r['warehouse_name'],
                                  ]
                                  .whereType<String>()
                                  .where((v) => v.isNotEmpty)
                                  .join(' · '),
                            ),
                            trailing: Text('Үлдэгдэл: ${r['quantity']}'),
                            onTap: widget.selectable
                                ? () => Navigator.pop(context, r)
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
