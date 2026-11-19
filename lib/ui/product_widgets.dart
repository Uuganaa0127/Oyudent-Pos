part of '../main.dart';

class _ProductCard extends StatelessWidget {
  final Product product;
  final int stock;
  final VoidCallback onTap;
  const _ProductCard({
    required this.product,
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
              [product.reference, product.lotNumber]
                      .where((value) => value.trim().isNotEmpty)
                      .join(' · ')
                      .isEmpty
                  ? product.categoryName
                  : [
                      product.reference,
                      product.lotNumber,
                    ].where((value) => value.trim().isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              'Үлдэгдэл: $stock',
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
                    product.detail,
                    style: const TextStyle(color: muted, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  stock <= 0 && product.apiStock == null
                      ? 'Энэ салбарт үлдэгдэлгүй'
                      : '₮${_money(product.price.toDouble())}',
                  style: TextStyle(
                    color: stock <= 0 && product.apiStock == null
                        ? warningInk
                        : green,
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
  final double price;
  final VoidCallback? editPrice;
  final VoidCallback onMinus, onPlus;
  final String note;
  final ValueChanged<String> onNoteChanged;
  const _CartLine({
    required this.product,
    required this.quantity,
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
            key: ValueKey(
              '${product.barcode}:${product.apiStock?['variant_id']}',
            ),
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
  final Product product;
  final int quantity;
  const _InventoryRow({required this.product, required this.quantity});
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
                product.detail,
                style: const TextStyle(color: muted, fontSize: 9),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            product.reference,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            product.lotNumber,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            '$quantity',
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
