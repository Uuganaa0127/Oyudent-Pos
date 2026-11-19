part of '../main.dart';

class _ShipmentTerms {
  final inputs = <String, String>{
    'Exchange rate · ₮ per ¥': '',
    'Freight': '0',
    'Customs %': '0',
    'Other costs · ₮': '0',
    'Other costs %': '0',
    'Gross margin %': '0',
    'VAT %': '10',
  };
  String freightBasis = 'JPY';
  bool vat = true;
  String currency = 'JPY';
}

class _ShipmentPricing extends StatefulWidget {
  final List<_IncomingLine> lines;
  final List<Map<String, dynamic>> products;
  final _ShipmentTerms terms;
  final VoidCallback onApply;
  final bool expanded;
  const _ShipmentPricing({
    this.expanded = false,
    required this.lines,
    required this.products,
    required this.terms,
    required this.onApply,
  });
  @override
  State<_ShipmentPricing> createState() => _ShipmentPricingState();
}

class _ShipmentPricingState extends State<_ShipmentPricing> {
  double? number(String s) {
    final n = double.tryParse(s.trim());
    return n != null && n.isFinite && n >= 0 ? n : null;
  }

  Widget field(String label, String value, ValueChanged<String> change) =>
      TextFormField(
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (s) => setState(() => change(s)),
      );
  @override
  Widget build(BuildContext context) {
    final t = widget.terms;
    final values = t.inputs.map((k, v) => MapEntry(k, number(v)));
    final fx = values['Exchange rate · ₮ per ¥'] ?? 0;
    final margin = values['Gross margin %'] ?? 0,
        vat = t.vat ? (values['VAT %'] ?? 0) : 0;
    var valid =
        fx > 0 &&
        margin < 100 &&
        values.entries.every(
          (e) => e.value != null || (!t.vat && e.key == 'VAT %'),
        );
    final costs = <double>[], quantities = <double>[];
    for (final l in widget.lines) {
      final q = number(l.quantity.text),
          p = number(l.sourcePrice),
          pieces = number(l.pieces);
      if (q == null ||
          q <= 0 ||
          p == null ||
          pieces == null ||
          pieces < 1 ||
          pieces != pieces.truncateToDouble())
        valid = false;
      quantities.add(q ?? 0);
      costs.add((p ?? 0) * fx * (l.pricePerPiece ? (pieces ?? 0) : 1));
    }
    double goods = 0;
    for (var i = 0; i < costs.length; i++) {
      goods += costs[i] * quantities[i];
    }
    final freight =
        (values['Freight'] ?? 0) *
        switch (t.freightBasis) {
          'JPY' => fx,
          '%' => goods / 100,
          _ => 1.0,
        };
    final base = goods + freight;
    final landed =
        base *
            (1 +
                ((values['Customs %'] ?? 0) + (values['Other costs %'] ?? 0)) /
                    100) +
        (values['Other costs · ₮'] ?? 0);
    final net = landed / (1 - margin / 100), gross = net * (1 + vat / 100);
    valid = valid && goods > 0 && gross.isFinite;
    String amount(double v) => valid ? '₮${_money(v)}' : '—';
    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: widget.expanded,
        collapsedBackgroundColor: deepSpace,
        backgroundColor: deepSpaceMid,
        textColor: Colors.white,
        collapsedTextColor: Colors.white,
        iconColor: aquaGlow,
        collapsedIconColor: aquaGlow,
        leading: const Icon(Icons.calculate_outlined, color: aquaGlow),
        title: const Text(
          'Shipment pricing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${t.currency} → MNT   ·   Freight, margin and VAT',
          style: TextStyle(color: aquaGlow),
        ),
        children: [
          ColoredBox(
            color: canvas,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Freight basis'),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'JPY', label: Text(t.currency)),
                          ButtonSegment(value: 'MNT', label: Text('₮')),
                          ButtonSegment(value: '%', label: Text('% of goods')),
                        ],
                        selected: {t.freightBasis},
                        onSelectionChanged: (s) =>
                            setState(() => t.freightBasis = s.first),
                      ),
                      FilterChip(
                        label: const Text('Include VAT'),
                        selected: t.vat,
                        onSelected: (v) => setState(() => t.vat = v),
                      ),
                    ],
                  ),
                  _ProductFields(
                    children: [
                      for (final e in t.inputs.entries)
                        if (t.vat || e.key != 'VAT %')
                          field(
                            e.key.startsWith('Exchange rate')
                                ? '₮ per 1 ${t.currency}'
                                : e.key,
                            e.value,
                            (s) => t.inputs[e.key] = s,
                          ),
                    ],
                  ),
                  for (final pair in widget.lines.indexed)
                    Builder(
                      key: ObjectKey(pair.$2),
                      builder: (_) {
                        final (i, l) = pair;
                        final product = widget.products
                            .where(
                              (p) =>
                                  (p['id'] ?? p['code']).toString() ==
                                  l.productId,
                            )
                            .firstOrNull;
                        final unit = valid ? costs[i] * landed / goods : 0.0;
                        final sale =
                            unit / (1 - margin / 100) * (1 + vat / 100);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                Text(
                                  'Line ${i + 1} · ${product?['name'] ?? product?['mn_name'] ?? l.sourceName ?? "Product"}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                _ProductFields(
                                  children: [
                                    field(
                                      'Supplier price · ${t.currency}',
                                      l.sourcePrice,
                                      (s) => l.sourcePrice = s,
                                    ),
                                    field(
                                      'Pieces / purchase unit',
                                      l.pieces,
                                      (s) => l.pieces = s,
                                    ),
                                    FilterChip(
                                      label: Text(
                                        l.pricePerPiece
                                            ? 'Price per piece'
                                            : 'Price per purchase unit',
                                      ),
                                      selected: l.pricePerPiece,
                                      onSelected: (v) =>
                                          setState(() => l.pricePerPiece = v),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Landed ${amount(unit)}   ·   Selling / unit ${amount(sale)}   ·   Selling / piece ${amount(valid ? sale / number(l.pieces)! : 0)}',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  Text(
                    'Landed ${amount(landed)}   ·   Before VAT ${amount(net)}   ·   VAT ${amount(gross - net)}   ·   Total ${amount(gross)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Customs and percentage costs apply to goods plus freight. Costs are allocated by goods value. Selling price = landed cost ÷ (1 − margin), plus the selected VAT.',
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Apply prices to invoice lines'),
                    onPressed: !valid
                        ? null
                        : () {
                            for (var i = 0; i < costs.length; i++) {
                              final l = widget.lines[i],
                                  unit = costs[i] * landed / goods,
                                  sell = unit / (1 - margin / 100);
                              l.unitCost.text = unit.toStringAsFixed(2);
                              l.netPrice.text = sell.toStringAsFixed(2);
                              l.grossPrice.text = (sell * (1 + vat / 100))
                                  .toStringAsFixed(2);
                            }
                            widget.onApply();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Prices applied to this invoice draft.',
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
