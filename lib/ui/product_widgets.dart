part of '../main.dart';

class _ProductCard extends StatelessWidget {
  final _ProductGroup group;
  Product get product => group.product;
  final num stock;
  final VoidCallback onTap;
  const _ProductCard({
    required this.group,
    required this.stock,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: panelColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: lineColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: product.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _ProductImage(
                  imageUrl: product.imageUrl,
                  emoji: product.emoji,
                  radius: 10,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              group.multiple
                  ? group.optionsLabel
                  : [
                      product.reference,
                      product.lotNumber,
                    ].where((v) => v.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              'Үлдэгдэл: ${_stockText(stock)}',
              style: TextStyle(
                color: stock <= 5 ? warningInk : muted,
                fontSize: 10,
                fontWeight: stock <= 5 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.multiple
                        ? [
                                product.apiStock?['code'],
                                product.apiStock?['supplier_name'],
                                product.categoryName,
                              ]
                              .whereType<String>()
                              .where((s) => s.trim().isNotEmpty)
                              .join(' · ')
                        : product.detail,
                    style: const TextStyle(color: muted, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  group.multiple
                      ? 'Сонгох'
                      : '₮${_money(product.price.toDouble())}',
                  style: TextStyle(
                    color: green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _stockText(num quantity) => quantity == quantity.truncate()
    ? quantity.truncate().toString()
    : quantity.toString();

String _optionDescription(Product p) {
  final row = p.apiStock;
  if (row == null) return p.detail;
  return [
    row['color_name'],
    row['size_name'],
    row['weight'],
    row['unit_name'],
    row['warehouse_name'],
    if (p.barcode.isNotEmpty) p.barcode,
    if ((row['lot_number'] ?? row['lot_no']) != null)
      'Лот: ${row['lot_number'] ?? row['lot_no']}',
    if (row['expiration_date'] != null)
      'Дуусах: ${_displayApiDate(row['expiration_date'])}',
  ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' · ');
}

class _StockOptions extends StatefulWidget {
  const _StockOptions({
    required this.group,
    required this.query,
    required this.stockFor,
    this.selectable = true,
  });
  final _ProductGroup group;
  final String query;
  final num Function(Product) stockFor;
  final bool selectable;
  @override
  State<_StockOptions> createState() => _StockOptionsState();
}

class _StockOptionsState extends State<_StockOptions> {
  late String query = widget.query;
  @override
  Widget build(BuildContext context) {
    final matches = widget.group.choices(query.trim().toLowerCase());
    final options = [
      ...matches.where((p) => widget.stockFor(p) > 0),
      ...matches.where((p) => widget.stockFor(p) <= 0),
    ];
    final variants = _ProductGroup.groupRows(
      options,
      _ProductGroup.variantKey,
    ).values.toList();
    return AlertDialog(
      title: Text(widget.group.product.name),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          children: [
            TextFormField(
              initialValue: query,
              decoration: const InputDecoration(
                labelText: 'Хувилбар, агуулах, лот, баркодоор хайх',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            Expanded(
              child: options.isEmpty
                  ? const Center(child: Text('Тохирох сонголт олдсонгүй.'))
                  : ListView.separated(
                      itemCount: variants.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) =>
                          variantTile(variants[i], variants.length == 1),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Хаах'),
        ),
      ],
    );
  }

  String stockLabel(Iterable<Product> lines) =>
      'Үлдэгдэл: ${_stockText(lines.fold<num>(0, (s, p) => s + widget.stockFor(p)))}';

  String warehouseLabel(Product p) {
    final row = p.apiStock;
    final name = row?['warehouse_name'] ?? row?['warehouse_id'] ?? 'Агуулах';
    return [
      row?['scope'] ?? row?['branch_name'],
      name,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }

  Widget stockTile(
    Product p,
    String title, {
    bool showWarehouse = false,
    bool showReceipt = false,
  }) {
    final row = p.apiStock;
    final lot = row?['lot_number'] ?? row?['lot_no'];
    final receipt =
        row?['invoice_number'] ?? (row == null ? null : _orderInvoiceId(row));
    final detail = [
      if (showWarehouse) warehouseLabel(p),
      if (lot != null && lot.toString().isNotEmpty) 'Лот: $lot',
      if (row?['expiration_date'] != null)
        'Дуусах: ${_displayApiDate(row?['expiration_date'])}',
      if (showReceipt && receipt != null && receipt.toString().isNotEmpty)
        'Баримт: $receipt',
      '${stockLabel([p])} · ₮${_money(p.price.toDouble())}',
    ].join(' · ');
    return ListTile(
      title: Text(title),
      subtitle: Text(detail),
      onTap: widget.selectable ? () => Navigator.pop(context, p) : null,
    );
  }

  Widget variantTile(List<Product> lines, bool onlyVariant) {
    final p = lines.first;
    final row = p.apiStock;
    final title =
        [
              row?['color_name'],
              row?['size_name'],
              row?['weight'],
              row?['unit_name'],
              p.reference,
              p.barcode,
            ]
            .where((s) => s != null && s.toString().trim().isNotEmpty)
            .toSet()
            .join(' · ');
    final label = title.isEmpty ? p.name : title;
    if (lines.length == 1) return stockTile(p, label, showWarehouse: true);
    final locations = _ProductGroup.groupRows(
      lines,
      _ProductGroup.warehouseKey,
    );
    return ExpansionTile(
      key: PageStorageKey(_ProductGroup.variantKey(p)),
      initiallyExpanded: onlyVariant,
      title: Text(label),
      subtitle: Text('${locations.length} агуулах · ${stockLabel(lines)}'),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: [
        for (final entry in locations.entries)
          if (entry.value.length == 1)
            stockTile(entry.value.single, warehouseLabel(entry.value.single))
          else
            ExpansionTile(
              key: PageStorageKey((_ProductGroup.variantKey(p), entry.key)),
              title: Text(warehouseLabel(entry.value.first)),
              subtitle: Text(
                '${entry.value.length} үлдэгдлийн мөр · ${stockLabel(entry.value)}',
              ),
              childrenPadding: const EdgeInsets.only(left: 12),
              children: [
                for (final line in entry.value)
                  stockTile(
                    line,
                    _orderInvoiceId(line.apiStock!) == ''
                        ? 'Орлогын баримтгүй'
                        : 'Орлогын мөр',
                    showReceipt: true,
                  ),
              ],
            ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  final String emoji;
  final double radius;
  const _ProductImage({
    required this.imageUrl,
    required this.emoji,
    this.radius = 9,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: imageUrl == null
        ? Center(child: Text(emoji, style: const TextStyle(fontSize: 28)))
        : Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
  );
}

class _SalePriceDialog extends StatefulWidget {
  const _SalePriceDialog({required this.product, required this.price});
  final Product product;
  final double price;
  @override
  State<_SalePriceDialog> createState() => _SalePriceDialogState();
}

class _SalePriceDialogState extends State<_SalePriceDialog> {
  final form = GlobalKey<FormState>();
  late String amount = widget.price.toStringAsFixed(2);
  void submit() {
    if (form.currentState!.validate())
      Navigator.pop(context, double.parse(amount));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Борлуулах үнэ засах'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.product.name),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: amount,
            autofocus: true,
            selectAllOnFocus: true,
            decoration: const InputDecoration(
              labelText: 'НӨАТ-гүй нэгж үнэ (₮)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => amount = v.trim(),
            onFieldSubmitted: (_) => submit(),
            validator: (_) =>
                RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount) &&
                    (double.tryParse(amount)?.isFinite ?? false)
                ? null
                : 'Үнийг хоёр хүртэл орны нарийвчлалтай оруулна уу.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Болих'),
      ),
      TextButton(
        onPressed: () =>
            Navigator.pop(context, widget.product.price.toDouble()),
        child: const Text('Үндсэн үнэ'),
      ),
      FilledButton(onPressed: submit, child: const Text('Хэрэглэх')),
    ],
  );
}

class _CartLine extends StatelessWidget {
  final Product product;
  final int quantity;
  final num stock;
  final double price;
  final VoidCallback? editPrice;
  final VoidCallback onMinus, onPlus;
  final String note;
  final ValueChanged<String> onNoteChanged;
  const _CartLine({
    required this.product,
    required this.quantity,
    required this.stock,
    required this.price,
    required this.editPrice,
    required this.onMinus,
    required this.onPlus,
    required this.note,
    required this.onNoteChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: product.tint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: _ProductImage(
                imageUrl: product.imageUrl,
                emoji: product.emoji,
                radius: 9,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  if (product.apiStock != null)
                    Text(
                      _optionDescription(product),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  if (quantity > stock)
                    Text(
                      'Зарлагын дараах үлдэгдэл: ${_stockText(stock - quantity)}',
                      style: const TextStyle(color: warningInk, fontSize: 10),
                    ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: editPrice,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text('₮${_money(price)}'),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMinus,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 25, height: 25),
              icon: const Icon(
                Icons.remove_circle_outline,
                size: 17,
                color: muted,
              ),
            ),
            Text(
              '$quantity',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: onPlus,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 25, height: 25),
              icon: const Icon(
                Icons.add_circle_outline,
                size: 17,
                color: green,
              ),
            ),
          ],
        ),
        if (product.apiStock != null) ...[
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey(_stockLineKey(product.apiStock!)),
            initialValue: note,
            onChanged: onNoteChanged,
            decoration: const InputDecoration(
              hintText: 'Мөрийн тэмдэглэл',
              prefixIcon: Icon(Icons.notes_outlined, size: 15),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ],
      ],
    ),
  );
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      children: [
        Expanded(flex: 4, child: Text('БАРАА', style: _tableHead)),
        Expanded(flex: 2, child: Text('ЛАВЛАХ ДУГААР', style: _tableHead)),
        Expanded(flex: 2, child: Text('ЛОТ ДУГААР', style: _tableHead)),
        SizedBox(
          width: 90,
          child: Text(
            'ҮЛДЭГДЭЛ',
            textAlign: TextAlign.right,
            style: _tableHead,
          ),
        ),
      ],
    ),
  );
}

class _InventoryRow extends StatelessWidget {
  final _ProductGroup group;
  Product get product => group.product;
  final num quantity;
  const _InventoryRow({required this.group, required this.quantity});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 42,
          child: _ProductImage(
            imageUrl: product.imageUrl,
            emoji: product.emoji,
            radius: 6,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                group.multiple ? product.categoryName : product.detail,
                style: const TextStyle(color: muted, fontSize: 9),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            group.multiple
                ? (product.apiStock?['code'] ?? '').toString()
                : product.reference,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            group.multiple ? group.optionsLabel : product.lotNumber,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            _stockText(quantity),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: quantity <= 5 ? warningInk : ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String title, value, detail;
  final IconData icon;
  final Color tint;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tint,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: panelColor,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: green, size: 17),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(detail, style: const TextStyle(color: muted, fontSize: 10)),
      ],
    ),
  );
}
