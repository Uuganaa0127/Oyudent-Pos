part of '../main.dart';

class ProductsPage extends StatefulWidget {
  final List<_ProductGroup> groups;
  final String warehouse;
  final String apiToken;
  final Future<void> Function() onReload;
  final num Function(Product) stockFor;
  const ProductsPage({
    super.key,
    required this.groups,
    required this.warehouse,
    required this.stockFor,
    required this.apiToken,
    required this.onReload,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.groups
        .where((g) => g.matches(query.toLowerCase()))
        .toList();
    return Column(
      children: [
        _TopBar(
          title: 'Бараа',
          subtitle: widget.warehouse,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: widget.apiToken.isEmpty
                    ? null
                    : () async {
                        final created = await showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              _ProductCreateDialog(apiToken: widget.apiToken),
                        );
                        if (created == true) await widget.onReload();
                      },
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Бараа нэмэх'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      _ProductBulkImportDialog(apiToken: widget.apiToken),
                ),
                icon: const Icon(Icons.upload_file_outlined, size: 17),
                label: const Text('Бараа импортлох'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: deepSpace,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Агуулахын бараа',
                            style: TextStyle(
                              color: ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${filtered.length} бараа',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchController,
                      onChanged: (value) =>
                          setState(() => query = value.trim()),
                      decoration: InputDecoration(
                        hintText: 'Монгол, англи нэр, лавлах дугаар, баркод, үйлдвэрлэгчээр хайх…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Хайлтыг арилгах',
                                onPressed: () {
                                  searchController.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _InventoryHeader(),
                    const Divider(height: 1),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    final group = filtered[index];
                    final product = group.product;
                    return Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: group.multiple
                                ? () => showDialog<Product>(
                                    context: context,
                                    builder: (_) => _StockOptions(
                                      group: group,
                                      query: query,
                                      stockFor: widget.stockFor,
                                      selectable: false,
                                    ),
                                  )
                                : null,
                            child: _InventoryRow(
                              product: product,
                              options: group.lines.length,
                              quantity: product.apiStock == null
                                  ? widget.stockFor(product)
                                  : group.branchQuantity,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Бараа засах',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: product.apiStock == null
                              ? null
                              : () async {
                                  final id =
                                      product.apiStock!['product_id'] ??
                                      product.apiStock!['id'];
                                  if (id == null) return;
                                  if (await showDialog<bool>(
                                        context: context,
                                        builder: (_) => _ProductCreateDialog(
                                          apiToken: widget.apiToken,
                                          editId: id.toString(),
                                        ),
                                      ) ==
                                      true)
                                    await widget.onReload();
                                },
                        ),
                      ],
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: Text(
                      query.isEmpty
                          ? 'Монгол, англи нэр, лавлах дугаар, баркод эсвэл үйлдвэрлэгчээр хайна уу'
                          : '«$query» хайлтаар ${filtered.length} бараа олдлоо',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductCreateDialog extends StatefulWidget {
  final String apiToken;
  final String? editId;
  final String? seedName, seedReference;
  final ValueChanged<String>? onCreated;
  const _ProductCreateDialog({
    required this.apiToken,
    this.editId,
    this.seedName,
    this.seedReference,
    this.onCreated,
  });
  @override
  State<_ProductCreateDialog> createState() => _ProductCreateDialogState();
}

class _ProductCreateDialogState extends State<_ProductCreateDialog> {
  late final OyudentApi api = OyudentApi(widget.apiToken);
  final name = TextEditingController();
  final mongolianName = TextEditingController();
  final code = TextEditingController();
  final description = TextEditingController();
  final productSearch = TextEditingController();
  final variants = <_NewProductVariant>[_NewProductVariant()];
  Map<String, dynamic>? original;
  PlatformFile? productImage;
  List<Map<String, dynamic>> products = [],
      categories = [],
      suppliers = [],
      units = [],
      colors = [],
      sizes = [];
  String? categoryCode, supplierCode;
  String? selectedExistingProductId;
  bool addVariantToExisting = false;
  bool loading = true, saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name.text = widget.seedName ?? '';
    code.text = widget.seedReference ?? '';
    _loadReferences();
  }

  @override
  void dispose() {
    name.dispose();
    mongolianName.dispose();
    code.dispose();
    description.dispose();
    productSearch.dispose();
    for (final v in variants) v.dispose();
    super.dispose();
  }

  Future<PlatformFile?> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      final file = result?.files.single;
      if (file == null) return null;
      if (file.bytes == null || file.bytes!.isEmpty) {
        throw const FormatException('Сонгосон зургийг уншиж чадсангүй.');
      }
      return mounted ? file : null;
    } catch (e) {
      if (mounted) setState(() => error = 'Зураг нээж чадсангүй: $e');
      return null;
    }
  }

  Future<void> _loadReferences() async {
    try {
      final values = await Future.wait([
        api.get('/product/ref'),
        api.get('/ref-data/PRODUCT_CATEGORY'),
        api.get('/partner/list?no_paginate=1'),
        api.get('/ref-data/PRODUCT_UNIT'),
        api.get('/ref-data/PRODUCT_COLOR'),
        api.get('/ref-data/PRODUCT_SIZE'),
      ]);
      if (widget.editId != null) {
        final response = await api.get(
          '/product/${Uri.encodeComponent(widget.editId!)}',
        );
        if (!mounted) return;
        final data = Map<String, dynamic>.from(response['data'] as Map);
        if (data['id']?.toString() != widget.editId)
          throw StateError('Барааг таньж чадсангүй.');
        name.text = data['name'] ?? '';
        mongolianName.text = data['mnName'] ?? '';
        code.text = data['code'] ?? '';
        description.text = data['description'] ?? '';
        categoryCode = data['categoryCode'];
        supplierCode = data['supplierCode'];
        variants.removeLast().dispose();
        for (final row in _asMapList(data['variants'])) {
          final variant = _NewProductVariant()..original = row;
          variant.barcode.text = row['barCode'] ?? '';
          variant.weight.text = (row['weight'] ?? '').toString();
          variant.colorCode = row['colorCode'];
          variant.sizeCode = row['sizeCode'];
          variant.unitCode = row['unitCode'];
          variants.add(variant);
        }
        original = data;
      }
      if (!mounted) return;
      setState(() {
        products = _asMapList(values[0]['data']);
        categories = _asMapList(values[1]['data']);
        suppliers = _asMapList(values[2]);
        units = _asMapList(values[3]['data']);
        colors = _asMapList(values[4]['data']);
        sizes = _asMapList(values[5]['data']);
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  String _codeOf(Map<String, dynamic> item) =>
      (item['code'] ?? item['id'] ?? '').toString();
  String _nameOf(Map<String, dynamic> item) =>
      (item['mn_name'] ??
              item['mnName'] ??
              item['name'] ??
              item['title'] ??
              _codeOf(item))
          .toString();

  List<Map<String, dynamic>> get _filteredProducts {
    final query = productSearch.text.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products
        .where((product) => _searchableValues(product).contains(query))
        .toList();
  }

  String _searchableValues(Map<String, dynamic> item) => [
    item['name'],
    item['mn_name'],
    item['mnName'],
    item['english_name'],
    item['en_name'],
    item['name_en'],
    item['product_name'],
    item['product_display_name'],
    item['code'],
    item['sku'],
    item['barcode'],
    item['reference'],
    item['register_number'],
    item['id'],
  ].whereType<Object>().join(' ').toLowerCase();

  Widget _picker(
    String label,
    List<Map<String, dynamic>> options,
    String? selected,
    ValueChanged<String?> select,
  ) {
    final current = options
        .where((item) => _codeOf(item) == selected)
        .firstOrNull;
    String nameOf(Map<String, dynamic> item) =>
        [
              item['mn_name'],
              item['mnName'],
              item['name'],
              item['title'],
              item['english_name'],
            ]
            .whereType<String>()
            .where((name) => name.trim().isNotEmpty)
            .firstOrNull ??
        '';
    return Autocomplete<Map<String, dynamic>>(
      initialValue: TextEditingValue(
        text: current == null ? '' : nameOf(current),
      ),
      displayStringForOption: nameOf,
      optionsBuilder: (text) => options.where(
        (item) =>
            _codeOf(item).isNotEmpty &&
            nameOf(item).isNotEmpty &&
            [
              nameOf(item),
              item['name'],
              item['mn_name'],
              item['mnName'],
              item['english_name'],
              item['en_name'],
            ].whereType<String>().any(
              (name) =>
                  name.toLowerCase().contains(text.text.trim().toLowerCase()),
            ),
      ),
      onSelected: (item) => select(_codeOf(item)),
      fieldViewBuilder: (context, controller, focus, submit) => TextField(
        controller: controller,
        focusNode: focus,
        enabled: !saving,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Нэрээр хайх',
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: (_) {
          if (selected != null) select(null);
        },
        onSubmitted: (_) => submit(),
      ),
    );
  }

  Future<void> _selectExistingProduct(String? productId) async {
    setState(() {
      selectedExistingProductId = productId;
      categoryCode = null;
      supplierCode = null;
      error = null;
    });
    if (productId == null) return;
    try {
      final response = await api.get('/product/$productId');
      final data = response['data'];
      if (data is Map && mounted) {
        setState(() {
          categoryCode = (data['categoryCode'] ?? data['category_code'])
              ?.toString();
          supplierCode = (data['supplierCode'] ?? data['supplier_code'])
              ?.toString();
        });
      }
    } catch (e) {
      if (mounted)
        setState(() => error = 'Барааны мэдээллийг уншиж чадсангүй: $e');
    }
  }

  Future<void> _generateBarcode(int index) async {
    if ((categoryCode ?? '').isEmpty || (supplierCode ?? '').isEmpty) {
      setState(
        () => error = 'Баркод үүсгэхийн өмнө ангилал, үйлдвэрлэгч сонгоно уу.',
      );
      return;
    }
    try {
      final result = await api.post('/product/variant/barcode/generate', {
        'supplierCode': supplierCode,
        'categoryCode': categoryCode,
      });
      final data = result['data'];
      var barcode = data is Map
          ? (data['barcode'] ?? '').toString()
          : (data ?? '').toString();
      final pieces = barcode.split('-');
      if (pieces.length == 4) {
        final prefix = pieces.take(3).join('-');
        var highest = int.tryParse(pieces.last) ?? 0;
        for (final variant in variants) {
          final existing = variant.barcode.text.trim().split('-');
          if (existing.length == 4 && existing.take(3).join('-') == prefix) {
            final sequence = int.tryParse(existing.last) ?? 0;
            if (sequence > highest) highest = sequence;
          }
        }
        barcode = '$prefix-${(highest + 1).toString().padLeft(5, '0')}';
      }
      if (barcode.isNotEmpty && mounted)
        setState(() => variants[index].barcode.text = barcode);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _save() async {
    if ((!addVariantToExisting && name.text.trim().isEmpty) ||
        (addVariantToExisting && (selectedExistingProductId ?? '').isEmpty) ||
        (categoryCode ?? '').isEmpty ||
        (supplierCode ?? '').isEmpty) {
      setState(
        () => error = addVariantToExisting
            ? 'Хувилбар нэмэхийн өмнө бараа сонгоно уу.'
            : 'Барааны нэр, ангилал, үйлдвэрлэгчийг оруулна уу.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      for (var i = 0; i < variants.length; i++) {
        if (variants[i].barcode.text.trim().isEmpty) await _generateBarcode(i);
        if (variants[i].barcode.text.trim().isEmpty)
          throw Exception('Хадгалахын өмнө хувилбар бүрд баркод үүсгэнэ үү.');
      }
      var productId = selectedExistingProductId;
      if (!addVariantToExisting) {
        final product = await api.post('/product/', {
          ...?original,
          'id': widget.editId ?? '',
          'name': name.text.trim(),
          'mnName': mongolianName.text.trim(),
          'code': code.text.trim(),
          'description': description.text.trim(),
          'categoryCode': categoryCode,
          'supplierCode': supplierCode,
          if (original == null) 'countryCode': '',
          if (original == null) 'isShowLanding': false,
          if (original == null) 'isPopular': false,
          if (original == null) 'onSale': false,
          if (original == null) 'orderMinimum': 0,
          if (original == null) 'quantityMinimum': 0,
          if (original == null) 'stockQuantity': 0,
          if (original == null) 'endDate': null,
        });
        final data = product['data'];
        productId =
            widget.editId ??
            (data is Map ? data['id']?.toString() : data?.toString());
      }
      if (productId == null || productId.isEmpty)
        throw Exception('Бараа үүссэн боловч системээс дугаар нь ирсэнгүй.');
      if (!addVariantToExisting && productImage != null) {
        await api.uploadImage(
          '/product/image',
          fields: {'productId': productId},
          image: productImage!,
        );
      }
      for (final variant in variants) {
        final variantResponse = await api.post('/product/variant/', {
          ...?variant.original,
          'productId': productId,
          'id': variant.original?['id'] ?? '',
          'barCode': variant.barcode.text.trim(),
          'weight': variant.weight.text.trim(),
          'colorCode': variant.colorCode ?? '',
          'sizeCode': variant.sizeCode ?? '',
          'unitCode': variant.unitCode ?? '',
          'warehouseStock': variant.original?['warehouseStock'] ?? [],
        });
        final variantData = variantResponse['data'];
        final variantId =
            variant.original?['id']?.toString() ??
            (variantData is Map
                ? variantData['id']?.toString()
                : variantData?.toString());
        if (variant.image != null &&
            variantId != null &&
            variantId.isNotEmpty) {
          await api.uploadImage(
            '/product/variant/image',
            fields: {'productId': productId, 'productVariantId': variantId},
            image: variant.image!,
          );
        }
      }
      widget.onCreated?.call(productId);
      if (mounted) {
        _notice(context, 'Бараа, хувилбарууд хадгалагдлаа.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
        _notice(context, 'Хадгалж чадсангүй: $e', failed: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    title: Text(
      widget.editId == null ? 'Бараа, хувилбар нэмэх' : 'Бараа, хувилбар засах',
    ),
    content: SizedBox(
      width: 720,
      child: loading
          ? const SizedBox(
              height: 180,
              child: _BusyBar('Барааны мэдээллийг ачаалж байна…'),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.editId == null && widget.onCreated == null)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Шинэ бараа үүсгэх'),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Бүртгэлтэй бараанд хувилбар нэмэх'),
                        ),
                      ],
                      selected: {addVariantToExisting},
                      onSelectionChanged: saving
                          ? null
                          : (value) => setState(() {
                              addVariantToExisting = value.first;
                              error = null;
                            }),
                    ),
                  const SizedBox(height: 14),
                  if (addVariantToExisting)
                    Column(
                      children: [
                        TextField(
                          controller: productSearch,
                          decoration: const InputDecoration(
                            labelText:
                                'Барааны нэр эсвэл лавлах дугаараар хайх',
                          ),
                          onChanged: (_) => setState(() {
                            selectedExistingProductId = null;
                            categoryCode = null;
                            supplierCode = null;
                          }),
                        ),
                        _ReferenceDropdown(
                          key: ValueKey(productSearch.text),
                          initialValue: selectedExistingProductId,
                          decoration: const InputDecoration(
                            labelText: 'Бүртгэлтэй бараа *',
                          ),
                          items: _filteredProducts
                              .map(
                                (p) => DropdownMenuItem(
                                  value: (p['id'] ?? p['product_id'])
                                      ?.toString(),
                                  child: Text(
                                    '${_nameOf(p)} · ${p['code'] ?? p['id'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: saving ? null : _selectExistingProduct,
                        ),
                      ],
                    )
                  else ...[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Барааны нэр *',
                      ),
                    ),
                    TextField(
                      controller: mongolianName,
                      decoration: const InputDecoration(
                        labelText: 'Монгол нэр',
                      ),
                    ),
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Лавлах дугаар (заавал биш)',
                      ),
                    ),
                    TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Тайлбар'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final file = await _pickImage();
                                if (file != null)
                                  setState(() => productImage = file);
                              },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          productImage?.name ?? 'Барааны зураг сонгох',
                        ),
                      ),
                    ),
                    if (productImage?.bytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              productImage!.bytes!,
                              width: 86,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    _picker(
                      'Ангилал',
                      categories,
                      categoryCode,
                      (v) => setState(() => categoryCode = v),
                    ),
                    _picker(
                      'Үйлдвэрлэгч',
                      suppliers,
                      supplierCode,
                      (v) => setState(() => supplierCode = v),
                    ),
                  ],
                  if (addVariantToExisting && selectedExistingProductId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Баркод үүсгэхэд шаардлагатай ангилал, үйлдвэрлэгчийн мэдээлэл бэлэн.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ...variants.asMap().entries.map((entry) {
                    final i = entry.key;
                    final variant = entry.value;
                    return Card(
                      key: ObjectKey(variant),
                      color: inputSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Хувилбар ${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      variant.original != null ||
                                          variants.length <= 1
                                      ? null
                                      : () => setState(
                                          () => variants.removeAt(i).dispose(),
                                        ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            _ProductFields(
                              children: [
                                TextField(
                                  controller: variant.barcode,
                                  decoration: InputDecoration(
                                    labelText: 'Хувилбарын баркод',
                                    suffixIcon: IconButton(
                                      onPressed: saving
                                          ? null
                                          : () => _generateBarcode(i),
                                      icon: const Icon(Icons.qr_code_2),
                                    ),
                                  ),
                                ),
                                TextField(
                                  controller: variant.weight,
                                  decoration: const InputDecoration(
                                    labelText: 'Хэмжээ / жин',
                                  ),
                                ),
                              ],
                            ),
                            if (variant.image?.bytes != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    variant.image!.bytes!,
                                    width: 72,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final file = await _pickImage();
                                        if (file != null) {
                                          setState(() => variant.image = file);
                                        }
                                      },
                                icon: const Icon(Icons.image_outlined),
                                label: Text(
                                  variant.image?.name ??
                                      'Хувилбарын зураг сонгох',
                                ),
                              ),
                            ),
                            _ProductFields(
                              children: [
                                _picker(
                                  'Нэгж',
                                  units,
                                  variant.unitCode,
                                  (v) => setState(() => variant.unitCode = v),
                                ),
                                _picker(
                                  'Өнгө',
                                  colors,
                                  variant.colorCode,
                                  (v) => setState(() => variant.colorCode = v),
                                ),
                                _picker(
                                  'Барааны хэмжээ',
                                  sizes,
                                  variant.sizeCode,
                                  (v) => setState(() => variant.sizeCode = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => variants.add(_NewProductVariant())),
                      icon: const Icon(Icons.add),
                      label: const Text('Хувилбар нэмэх'),
                    ),
                  ),
                  if (error != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: const TextStyle(color: errorInk),
                      ),
                    ),
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context, false),
        child: const Text('Болих'),
      ),
      FilledButton(
        onPressed:
            saving || loading || (widget.editId != null && original == null)
            ? null
            : _save,
        child: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Бараа хадгалах'),
      ),
    ],
  );
}

class _NewProductVariant {
  Map<String, dynamic>? original;
  final barcode = TextEditingController(), weight = TextEditingController();
  String? unitCode, colorCode, sizeCode;
  PlatformFile? image;
  void dispose() {
    barcode.dispose();
    weight.dispose();
  }
}

class _ProductFields extends StatelessWidget {
  final List<Widget> children;
  const _ProductFields({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = ((bounds.maxWidth + 12) / 218).floor().clamp(
        1,
        children.length,
      );
      final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
