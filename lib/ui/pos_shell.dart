part of '../main.dart';

class PosShell extends StatefulWidget {
  final String initialToken;
  final String userName;
  const PosShell({
    super.key,
    this.initialToken = '',
    this.userName = 'Оюудентийн хэрэглэгч',
  });
  @override
  State<PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<PosShell> {
  static const lowStockThreshold = 5;
  OyudentApi get _api => OyudentApi(apiToken);
  int page = 0;
  String selectedCompany = 'Oyudent';
  String selectedCategory = 'Бүх бараа';
  String searchQuery = '';
  bool withVat = true;
  bool apiBusy = false;
  String apiToken = '';
  late String userName = widget.userName;
  String? selectedBranchId;
  int branchPickerRevision = 0;
  String? selectedApiCompanyId;
  String? apiError;
  List<Map<String, dynamic>> apiBranches = [];
  List<Map<String, dynamic>> apiCompanies = [];
  List<Map<String, dynamic>> apiCategories = [];
  List<Map<String, dynamic>> apiCatalog = [];
  List<Map<String, dynamic>> apiStockRows = [];
  List<Product>? apiProducts;
  final noteController = TextEditingController();
  final searchController = TextEditingController();
  final Map<int, int> cart = {};
  final Map<int, String> lineNotes = {};
  final Map<int, double> salePrices = {};

  double _salePrice(int index) =>
      salePrices[index] ?? products[index].price.toDouble();

  void _clearCart() {
    cart.clear();
    lineNotes.clear();
    salePrices.clear();
  }

  Future<void> _editSalePrice(int index) async {
    final product = products[index];
    final price = await showDialog<double>(
      context: context,
      builder: (_) =>
          _SalePriceDialog(product: product, price: _salePrice(index)),
    );
    if (price == null ||
        !mounted ||
        !cart.containsKey(index) ||
        !identical(product, products[index]))
      return;
    setState(() => salePrices[index] = price);
  }

  final vatAccountController = TextEditingController();
  final noVatAccountController = TextEditingController();
  DateTime invoiceDate = DateTime.now();
  final Map<String, Map<int, int>> stockAdjustments = {
    'Oyudent': {},
    'Centech': {},
  };

  @override
  void initState() {
    super.initState();
    apiToken = widget.initialToken;
    if (apiToken.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connectApi(apiToken);
      });
    }
  }

  final demoProducts = const [
    Product(
      'Americano',
      'Кофе · Халуун',
      6500,
      '☕',
      warningSurface,
      reference: 'REF-10001',
      lotNumber: 'LOT-2611-01',
      barcode: '10001001',
      oyudentStock: 4,
      centechStock: 18,
    ),
    Product(
      'Cappuccino',
      'Кофе · Халуун',
      8500,
      '🥛',
      deepSpaceMid,
      reference: 'REF-10002',
      lotNumber: 'LOT-2611-02',
      barcode: '10001002',
      oyudentStock: 24,
      centechStock: 3,
    ),
    Product(
      'Iced latte',
      'Кофе · Хүйтэн',
      9500,
      '🧋',
      deepSpaceMid,
      reference: 'REF-10003',
      lotNumber: 'LOT-2611-03',
      barcode: '10001003',
      oyudentStock: 12,
      centechStock: 16,
    ),
    Product(
      'Blueberry muffin',
      'Нарийн боов',
      7000,
      '🫐',
      errorSurface,
      reference: 'REF-20001',
      lotNumber: 'LOT-2611-04',
      barcode: '20001001',
      oyudentStock: 2,
      centechStock: 7,
    ),
    Product(
      'Matcha latte',
      'Цай · Хүйтэн',
      11000,
      '🍵',
      activeSurface,
      reference: 'REF-30001',
      lotNumber: 'LOT-2611-05',
      barcode: '30001001',
      oyudentStock: 9,
      centechStock: 1,
    ),
    Product(
      'Butter croissant',
      'Нарийн боов',
      7500,
      '🥐',
      warningSurface,
      reference: 'REF-20002',
      lotNumber: 'LOT-2611-06',
      barcode: '20001002',
      oyudentStock: 7,
      centechStock: 13,
    ),
    Product(
      'Flat white',
      'Кофе · Халуун',
      8000,
      '☕',
      deepSpaceMid,
      reference: 'REF-10004',
      lotNumber: 'LOT-2611-07',
      barcode: '10001004',
      oyudentStock: 3,
      centechStock: 22,
    ),
    Product(
      'Lemon tea',
      'Цай · Халуун',
      6000,
      '🍋',
      activeSurface,
      reference: 'REF-30002',
      lotNumber: 'LOT-2611-08',
      barcode: '30001002',
      oyudentStock: 15,
      centechStock: 4,
    ),
  ];
  List<Product> get products => apiProducts ?? demoProducts;
  List<MapEntry<String, String>> get categoryOptions {
    if (apiProducts == null) {
      return const [
        MapEntry('Бүх бараа', 'Бүх бараа'),
        MapEntry('Кофе', 'Кофе'),
        MapEntry('Цай', 'Цай'),
        MapEntry('Нарийн боов', 'Нарийн боов'),
      ];
    }
    final options = <MapEntry<String, String>>[];
    for (final category in apiCategories) {
      final code = (category['code'] ?? category['id'] ?? '').toString();
      final name =
          (category['name'] ??
                  category['mn_name'] ??
                  category['additional'] ??
                  '')
              .toString();
      if (name.trim().isNotEmpty)
        options.add(MapEntry(code.isEmpty ? name : code, name));
    }
    if (options.isEmpty) {
      final seen = <String>{};
      for (final product in products) {
        final name = product.categoryName.trim();
        if (name.isNotEmpty &&
            seen.add(
              product.categoryCode.isEmpty ? name : product.categoryCode,
            )) {
          options.add(
            MapEntry(
              product.categoryCode.isEmpty ? name : product.categoryCode,
              name,
            ),
          );
        }
      }
    }
    return [const MapEntry('Бүх бараа', 'Бүх бараа'), ...options];
  }

  double get total =>
      cart.entries.fold(0, (sum, e) => sum + _salePrice(e.key) * e.value);
  double _lineVat(int index, int quantity) =>
      double.parse((_salePrice(index) * quantity * .1).toStringAsFixed(2));
  double _taxFor(bool includeVat) => includeVat
      ? cart.entries.fold<double>(0, (sum, e) => sum + _lineVat(e.key, e.value))
      : 0;
  double get vat => _taxFor(withVat);
  String get currentWarehouse {
    final branch = apiBranches.cast<Map<String, dynamic>?>().firstWhere(
      (b) => b?['id']?.toString() == selectedBranchId,
      orElse: () => null,
    );
    if (branch != null) return _refName(branch);
    return selectedCompany == 'Centech'
        ? 'Сентекийн төв агуулах'
        : 'Оюудентийн үндсэн агуулах';
  }

  String get currentBusinessName {
    final branch = apiBranches.cast<Map<String, dynamic>?>().firstWhere(
      (b) => b?['id']?.toString() == selectedBranchId,
      orElse: () => null,
    );
    final nestedCompany = branch?['company'];
    if (nestedCompany is Map)
      return _refName(Map<String, dynamic>.from(nestedCompany));
    return (branch?['company_name'] ??
            branch?['companyName'] ??
            selectedCompany)
        .toString();
  }

  bool get isApiConnected => apiToken.isNotEmpty && apiProducts != null;
  int _stockFor(Product product) {
    if (product.apiStock != null) {
      return _asInt(product.apiStock!['quantity']);
    }
    if (apiProducts != null) return 0;
    final index = products.indexOf(product);
    final baseStock = selectedCompany == 'Centech'
        ? product.centechStock
        : product.oyudentStock;
    return baseStock + (stockAdjustments[selectedCompany]?[index] ?? 0);
  }

  List<Product> get lowStockProducts => products
      .where(
        (product) =>
            (apiProducts == null || product.apiStock != null) &&
            _stockFor(product) <= lowStockThreshold,
      )
      .toList();

  void _selectCompany(String? company) {
    if (company == null) return;
    setState(() => selectedCompany = company);
  }

  Future<void> _showApiConnection() async {
    final controller = TextEditingController(text: apiToken);
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Оюудентийн системд холбогдох'),
        content: SizedBox(
          width: 410,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Салбар, байгууллага, үлдэгдэл, үнийг ачаалахын тулд хандалтын токеноо оруулна уу.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API хандалтын токен',
                  hintText: 'Хандалтын токен',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Токен зөвхөн апп нээлттэй үед санах ойд байна.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: green),
            child: const Text('Холбогдох'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.isEmpty) return;
    await _connectApi(token);
  }

  Future<void> _connectApi(String token) async {
    setState(() {
      apiToken = token;
      apiProducts = null;
      apiBranches = [];
      apiCompanies = [];
      apiCategories = [];
      apiCatalog = [];
      apiStockRows = [];
      selectedBranchId = null;
      selectedApiCompanyId = null;
      apiBusy = true;
      apiError = null;
    });
    try {
      final responses = await Future.wait([
        _apiGet('/company/ref'),
        _apiGet('/branch/ref'),
        _apiGet('/ref-data/PRODUCT_CATEGORY'),
        _apiGet('/product/list?no_paginate=1&sort=-created_at,-id'),
      ]);
      apiCompanies = _asMapList(responses[0]['data']);
      apiBranches = _asMapList(responses[1]['data']);
      apiCategories = _asMapList(responses[2]['data']);
      apiCatalog = _asMapList(responses[3]);
      selectedApiCompanyId ??= apiCompanies.isEmpty
          ? null
          : apiCompanies.first['id']?.toString();
      selectedBranchId ??= apiBranches.isEmpty
          ? null
          : apiBranches.first['id']?.toString();
      selectedCategory = 'Бүх бараа';
      if (selectedBranchId != null) await _loadApiStock();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() => apiError = '$error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Оюудентийн системд холбогдож чадсангүй: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => apiBusy = false);
    }
  }

  Widget _profileMenu({required Widget child}) => PopupMenuButton<String>(
    tooltip: 'Хэрэглэгчийн мэдээлэл',
    onSelected: (value) {
      if (value == 'sign_out') _signOut();
    },
    itemBuilder: (context) => [
      PopupMenuItem<String>(
        enabled: false,
        child: Text('Нэвтэрсэн хэрэглэгч: $userName'),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'sign_out',
        child: Row(
          children: [
            Icon(Icons.logout, size: 18),
            SizedBox(width: 10),
            Text('Гарах'),
          ],
        ),
      ),
    ],
    child: child,
  );

  void _signOut() {
    apiToken = '';
    apiProducts = null;
    apiBranches.clear();
    apiCompanies.clear();
    apiCategories.clear();
    apiCatalog.clear();
    apiStockRows.clear();
    _clearCart();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<Map<String, dynamic>> _apiGet(String path) => _api.get(path);

  Future<void> _loadApiStock() async {
    if (selectedBranchId == null) return;
    final response = await _apiGet(
      '/order/get-available-stocks?branch_id=$selectedBranchId',
    );
    apiStockRows = _asMapList(response['data']);
    _rebuildApiProducts();
    _clearCart();
  }

  void _rebuildApiProducts() {
    final catalogById = <String, Map<String, dynamic>>{};
    for (final item in apiCatalog) {
      final id = (item['id'] ?? item['product_id'] ?? '').toString();
      if (id.isNotEmpty) catalogById[id] = item;
    }
    final productsWithStock = <Product>[];
    final stockedIds = <String>{};
    for (final stock in apiStockRows) {
      final productId = (stock['product_id'] ?? stock['id'] ?? '').toString();
      final catalog = catalogById[productId];
      if (productId.isNotEmpty) stockedIds.add(productId);
      productsWithStock.add(Product.fromApi({...?catalog, ...stock}));
    }
    for (final catalog in apiCatalog) {
      final id = (catalog['id'] ?? catalog['product_id'] ?? '').toString();
      if (id.isEmpty || !stockedIds.contains(id)) {
        productsWithStock.add(Product.fromCatalog(catalog));
      }
    }
    apiProducts = productsWithStock;
  }

  Future<void> _refreshProductsWithoutClearingCart() async {
    if (apiToken.isEmpty) return;
    final branch = selectedBranchId;
    final token = apiToken;
    final results = await Future.wait([
      _apiGet('/product/list?no_paginate=1&sort=-created_at,-id'),
      if (selectedBranchId != null)
        _apiGet('/order/get-available-stocks?branch_id=$selectedBranchId'),
    ]);
    if (!mounted || selectedBranchId != branch || apiToken != token) return;
    final previous = <String, int>{};
    final previousNotes = <String, String>{};
    final previousPrices = <String, double>{};
    for (final entry in cart.entries) {
      final product = products[entry.key];
      final key = _stockLineKey(product.apiStock ?? {});
      previous[key] = entry.value;
      final price = salePrices[entry.key];
      if (price != null) previousPrices[key] = price;
      final note = lineNotes[entry.key];
      if (note != null) previousNotes[key] = note;
    }
    apiCatalog = _asMapList(results.first);
    if (selectedBranchId != null && results.length > 1) {
      apiStockRows = _asMapList(results[1]['data']);
    }
    _rebuildApiProducts();
    _clearCart();
    for (var index = 0; index < products.length; index++) {
      final product = products[index];
      final key = _stockLineKey(product.apiStock ?? {});
      final quantity = previous[key];
      if (quantity != null) {
        cart[index] = quantity;
        final price = previousPrices[key];
        if (price != null) salePrices[index] = price;
        final note = previousNotes[key];
        if (note != null) lineNotes[index] = note;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectApiBranch(String? id) async {
    if (id == null || id == selectedBranchId || apiBusy) return;
    final previousBranchId = selectedBranchId;
    if (count > 0) {
      final clearCurrentOrder = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Салбар солих уу?'),
          content: const Text(
            'Өөр агуулахын бараа холилдохоос сэргийлж одоогийн захиалгыг цэвэрлэнэ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Захиалгаа үргэлжлүүлэх'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Салбар солих'),
            ),
          ],
        ),
      );
      if (clearCurrentOrder != true || !mounted) {
        if (mounted) setState(() => branchPickerRevision++);
        return;
      }
    }
    setState(() {
      selectedBranchId = id;
      apiBusy = true;
      apiError = null;
    });
    try {
      await _loadApiStock();
    } catch (error) {
      if (mounted) {
        setState(() {
          selectedBranchId = previousBranchId;
          apiError = '$error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Салбарын мэдээллийг ачаалж чадсангүй: $error'),
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        apiBusy = false;
        if (selectedBranchId == id) lineNotes.clear();
      });
    }
  }

  Future<void> _pickInvoiceDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(
        () => invoiceDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
          invoiceDate.hour,
          invoiceDate.minute,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _submitApiOrder({
    required bool includeVat,
  }) async {
    if (selectedBranchId == null || selectedApiCompanyId == null) {
      throw Exception(
        'Захиалгаа хадгалахаас өмнө салбар, байгууллага сонгоно уу.',
      );
    }
    final items = cart.entries.map((entry) {
      final product = products[entry.key];
      final stock = product.apiStock;
      if (stock == null)
        throw Exception('Захиалга өгөхийн өмнө үлдэгдлийг шинэчилнэ үү.');
      final netPrice = _salePrice(entry.key);
      final lineVat = includeVat ? _lineVat(entry.key, entry.value) : 0.0;
      return {
        'productId': stock['product_id'],
        'variantId': stock['variant_id'],
        'warehouseId': stock['warehouse_id'],
        'inInvoiceId': stock['in_invoice_id'],
        'netUnitPrice': netPrice,
        'grossUnitPrice': netPrice + (includeVat ? netPrice * .1 : 0),
        'quantity': entry.value,
        'discount': 0,
        'tax': lineVat,
        'note': lineNotes[entry.key] ?? '',
      };
    }).toList();
    final invoiceTax = _taxFor(includeVat);
    final generatedInvoiceNumber = await _nextOutgoingInvoiceNumber(
      invoiceDate,
    );
    final orderBody = {
      'branchId': selectedBranchId,
      'id': '',
      'invoiceNumber': generatedInvoiceNumber,
      'companyId': selectedApiCompanyId,
      'isVat': includeVat,
      'tax': invoiceTax,
      'discount': 0,
      'invoiceDate': _formatInvoiceDate(invoiceDate),
      'dueDate': _formatInvoiceDate(invoiceDate).substring(0, 10),
      'total': total + invoiceTax,
      'note': noteController.text.trim(),
      'items': items,
      'vatBankAccountNumber': vatAccountController.text.trim(),
      'noVatBankAccountNumber': noVatAccountController.text.trim(),
      'isLoan': false,
      'loanMonths': 0,
      'loanStart': '',
    };
    final decoded = await _api.post('/order/', orderBody);
    decoded['_generatedInvoiceNumber'] = generatedInvoiceNumber;
    setState(() {
      _clearCart();
      noteController.clear();
    });
    try {
      await _loadApiStock();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Баримт хадгалагдсан боловч үлдэгдлийг шинэчилж чадсангүй: $error',
            ),
          ),
        );
      }
    }
    if (mounted) setState(() {});
    return decoded;
  }

  Future<String> _nextOutgoingInvoiceNumber(DateTime date) async {
    String two(int value) => value.toString().padLeft(2, '0');
    final datePrefix = '${date.year}${two(date.month)}${two(date.day)}';
    final pattern = RegExp('^${RegExp.escape(datePrefix)}-001/(\\d+)/01\$');
    final response = await _apiGet(
      '/order/list?no_paginate=1&sort=-created_at,-id',
    );
    var highest = 0;
    for (final order in _asMapList(response)) {
      final number = (order['invoice_number'] ?? order['invoiceNumber'] ?? '')
          .toString();
      final match = pattern.firstMatch(number);
      final sequence = match == null ? null : int.tryParse(match.group(1)!);
      if (sequence != null && sequence > highest) highest = sequence;
    }
    final serial = (highest + 1).toString().padLeft(3, '0');
    return '$datePrefix-001/$serial/01';
  }

  Future<void> _showAddCompanyDialog() async {
    final registerController = TextEditingController();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    var isPerson = false;
    var allowLoan = true;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Байгууллага нэмэх'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: registerController,
                    decoration: const InputDecoration(
                      labelText: 'Регистрийн дугаар',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Байгууллагын нэр *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Хаяг'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Утас'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Цахим шуудан (заавал биш)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Хувь хүн'),
                    value: isPerson,
                    onChanged: (value) =>
                        setDialogState(() => isPerson = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Зээлээр борлуулахыг зөвшөөрөх'),
                    value: allowLoan,
                    onChanged: (value) =>
                        setDialogState(() => allowLoan = value ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Байгууллагын нэрийг оруулна уу.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'register_number': registerController.text.trim(),
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'contact_phone_number': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                  'is_person': isPerson,
                  'is_loan': allowLoan,
                });
              },
              style: FilledButton.styleFrom(backgroundColor: green),
              child: const Text('Байгууллага хадгалах'),
            ),
          ],
        ),
      ),
    );
    registerController.dispose();
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    if (values == null || !mounted) return;

    setState(() => apiBusy = true);
    try {
      final decoded = await _api.post('/company', values);
      final companyResponse = await _apiGet('/company/ref');
      final companies = _asMapList(companyResponse['data']);
      final created = decoded['data'];
      final createdId = created is Map ? created['id']?.toString() : null;
      final companyName = values['name']?.toString();
      final match = companies.where((company) {
        return company['id']?.toString() == createdId ||
            _refName(company).toLowerCase() == companyName?.toLowerCase();
      }).firstOrNull;
      if (mounted) {
        setState(() {
          apiCompanies = companies;
          selectedApiCompanyId = match?['id']?.toString() ?? createdId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«$companyName» байгууллагыг нэмлээ.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Байгууллага нэмж чадсангүй: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => apiBusy = false);
    }
  }

  void _showLowStockDetails() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Үлдэгдэл багатай бараа · $currentWarehouse'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lowStockProducts
                .map(
                  (product) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(product.name)),
                        Text(
                          'Үлдэгдэл: ${_stockFor(product)}',
                          style: const TextStyle(
                            color: warningInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Хаах'),
          ),
        ],
      ),
    );
  }

  List<Product> get visibleProducts => products.where((product) {
    final matchesQuery =
        searchQuery.isEmpty ||
        product.searchText.contains(searchQuery.toLowerCase());
    final matchesCategory =
        selectedCategory == 'Бүх бараа' ||
        product.categoryCode == selectedCategory ||
        product.categoryName.toLowerCase() == selectedCategory.toLowerCase() ||
        (apiProducts == null &&
            product.detail.toLowerCase().contains(
              selectedCategory.toLowerCase(),
            ));
    return matchesQuery && matchesCategory;
  }).toList();
  int get count => cart.values.fold(0, (a, b) => a + b);

  void _addToCart(Product product) {
    final productIndex = products.indexOf(product);
    final alreadyInCart = cart[productIndex] ?? 0;
    if (alreadyInCart >= _stockFor(product)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$currentWarehouse агуулахад ${product.name} барааны нэмэлт үлдэгдэл алга.',
          ),
        ),
      );
      return;
    }
    setState(() => cart[productIndex] = alreadyInCart + 1);
  }

  @override
  void dispose() {
    searchController.dispose();
    noteController.dispose();
    vatAccountController.dispose();
    noVatAccountController.dispose();
    super.dispose();
  }

  Widget _sidebar(BuildContext context, {required bool drawer}) {
    void selectPage(int next) {
      if (drawer) Navigator.pop(context);
      setState(() => page = next);
    }

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deepSpace, deepSpaceMid, inputSurface],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x220A1424),
            blurRadius: 24,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 16, 34),
            child: _Brand(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (apiBranches.isEmpty) ...[
                  const Text(
                    'БАЙГУУЛЛАГА',
                    style: TextStyle(
                      color: aquaGlow,
                      fontSize: 9,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ReferenceDropdown(
                    initialValue: selectedCompany,
                    dropdownColor: deepSpaceMid,
                    style: const TextStyle(color: ink, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: panelColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: ['Oyudent', 'Centech']
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        )
                        .toList(),
                    onChanged: count == 0 ? _selectCompany : null,
                  ),
                  if (count > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        'Солихын өмнө захиалгаа дуусгана уу',
                        style: TextStyle(color: muted, fontSize: 8),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    currentWarehouse,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 9),
                  ),
                ],
                if (apiBranches.isNotEmpty) ...[
                  const Text(
                    'САЛБАР / АГУУЛАХ',
                    style: TextStyle(
                      color: aquaGlow,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _ReferenceDropdown(
                    key: ValueKey('$selectedBranchId:$branchPickerRevision'),
                    initialValue: selectedBranchId,
                    dropdownColor: deepSpaceMid,
                    style: const TextStyle(color: ink, fontSize: 11),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: panelColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 1,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: apiBranches
                        .map(
                          (branch) => DropdownMenuItem(
                            value: branch['id']?.toString(),
                            child: Text(
                              _refName(branch),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: apiBusy ? null : _selectApiBranch,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentWarehouse,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 0, 12),
            child: Text(
              'ҮНДСЭН ЦЭС',
              style: TextStyle(
                color: aquaGlow,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _NavItem(
            icon: Icons.point_of_sale_outlined,
            label: 'Борлуулалт',
            selected: page == 0,
            onTap: () => selectPage(0),
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Зарлага',
            selected: page == 1,
            onTap: () => selectPage(1),
          ),
          _NavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Бараа',
            selected: page == 2,
            onTap: () => selectPage(2),
          ),
          _NavItem(
            icon: Icons.move_to_inbox_outlined,
            label: 'Орлого',
            selected: page == 3,
            onTap: () => selectPage(3),
          ),
          _NavItem(
            icon: Icons.list_alt,
            label: "Туслах утга",
            selected: page == 4,
            onTap: () => selectPage(4),
          ),
          const Spacer(),
          _profileMenu(
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: aquaGlow,
                    child: Text(
                      'OY',
                      style: TextStyle(
                        color: deepSpace,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          isApiConnected
                              ? currentWarehouse
                              : 'Холбогдож байна…',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1060;
    return Scaffold(
      drawer: compact
          ? Drawer(
              width: 236,
              child: Builder(
                builder: (context) => _sidebar(context, drawer: true),
              ),
            )
          : null,
      appBar: compact ? AppBar(toolbarHeight: 44, title: const _Brand()) : null,
      body: Row(
        children: [
          if (!compact) _sidebar(context, drawer: false),
          Expanded(
            child: Column(
              children: [
                if (lowStockProducts.isNotEmpty)
                  _GlobalStockWarning(
                    company: currentBusinessName,
                    warehouse: currentWarehouse,
                    count: lowStockProducts.length,
                    onTap: _showLowStockDetails,
                  ),
                Expanded(
                  child: page == 0
                      ? _salesPage()
                      : page == 1
                      ? apiToken.isEmpty
                            ? const ExpensePage()
                            : ZarlagaInvoicePage(apiToken: apiToken)
                      : page == 2
                      ? ProductsPage(
                          products: products,
                          warehouse: currentWarehouse,
                          stockFor: _stockFor,
                          apiToken: apiToken,
                          onReload: _refreshProductsWithoutClearingCart,
                        )
                      : page == 4
                      ? _ReferencePage(apiToken: apiToken)
                      : IncomingInvoicesPage(
                          apiToken: apiToken,
                          initialBranchId: selectedBranchId,
                          onReload: _refreshProductsWithoutClearingCart,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesPage() => Column(
    children: [
      _TopBar(
        title: 'Борлуулалт',
        subtitle: currentWarehouse,
        trailing: Row(
          children: [
            _ConnectionPill(
              connected: isApiConnected,
              loading: apiBusy,
              onTap: _showApiConnection,
            ),
            const SizedBox(width: 15),

            _profileMenu(
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: activeSurface,
                child: Text(
                  'O',
                  style: TextStyle(
                    color: green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 23, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 43,
                            decoration: BoxDecoration(
                              color: panelColor,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: TextField(
                              controller: searchController,
                              autofocus: true,
                              onChanged: (value) =>
                                  setState(() => searchQuery = value.trim()),
                              decoration: InputDecoration(
                                hintText: 'Бараа хайх…',
                                prefixIcon: Icon(Icons.search, size: 19),
                                suffixIcon: searchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Хайлтыг арилгах',
                                        onPressed: () {
                                          searchController.clear();
                                          setState(() => searchQuery = '');
                                        },
                                        icon: const Icon(Icons.close, size: 17),
                                      ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(top: 5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _categoryChips(),
                    const SizedBox(height: 21),
                    Row(
                      children: [
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Хайлтын үр дүн'
                              : '$selectedCategory',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${visibleProducts.length} бараа',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: visibleProducts.isEmpty
                          ? const Center(
                              child: Text(
                                'Тохирох бараа олдсонгүй',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                            )
                          : GridView.builder(
                              itemCount: visibleProducts.length,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 230,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 190,
                                  ),
                              itemBuilder: (context, i) => _ProductCard(
                                product: visibleProducts[i],
                                stock: _stockFor(visibleProducts[i]),
                                onTap: () => _addToCart(visibleProducts[i]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 318,
              decoration: const BoxDecoration(
                color: panelColor,
                border: Border(left: BorderSide(color: lineColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Одоогийн захиалга',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: activeSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count ш',
                            style: const TextStyle(
                              color: green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        IconButton(
                          onPressed: () => setState(_clearCart),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: muted,
                            size: 19,
                          ),
                          tooltip: 'Захиалга цэвэрлэх',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _cartContents()),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .48,
                    ),
                    child: SingleChildScrollView(
                      child: Material(color: panelColor, child: _orderTotals()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _categoryChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: categoryOptions
          .map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: option.value,
                active: selectedCategory == option.key,
                onTap: () => setState(() => selectedCategory = option.key),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _cartContents() => cart.isEmpty
      ? const Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 34, color: lineColor),
                SizedBox(height: 12),
                Text(
                  'Захиалга хоосон байна',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'Бараа сонгож захиалгаа эхлүүлнэ үү',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        )
      : ListView(
          padding: const EdgeInsets.all(16),
          children: cart.entries
              .map(
                (e) => _CartLine(
                  product: products[e.key],
                  quantity: e.value,
                  price: _salePrice(e.key),
                  editPrice: apiBusy ? null : () => _editSalePrice(e.key),
                  onMinus: () => setState(() {
                    if (e.value <= 1) {
                      cart.remove(e.key);
                      salePrices.remove(e.key);
                      lineNotes.remove(e.key);
                    } else {
                      cart[e.key] = e.value - 1;
                    }
                  }),
                  onPlus: () => _addToCart(products[e.key]),
                  note: lineNotes[e.key] ?? '',
                  onNoteChanged: (value) =>
                      setState(() => lineNotes[e.key] = value),
                ),
              )
              .toList(),
        );

  Widget _orderTotals() => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        if (apiToken.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Худалдан авагч байгууллага',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
              IconButton(
                tooltip: 'Байгууллага нэмэх',
                visualDensity: VisualDensity.compact,
                onPressed: apiBusy ? null : _showAddCompanyDialog,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (apiCompanies.isNotEmpty)
            _ReferenceDropdown(
              key: ValueKey(selectedApiCompanyId),
              initialValue:
                  apiCompanies.any(
                    (item) => item['id']?.toString() == selectedApiCompanyId,
                  )
                  ? selectedApiCompanyId
                  : null,
              decoration: const InputDecoration(
                hintText: 'Байгууллага сонгох',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              items: apiCompanies
                  .map(
                    (company) => DropdownMenuItem(
                      value: company['id']?.toString(),
                      child: Text(
                        _refName(company),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) => setState(() => selectedApiCompanyId = id),
            )
          else
            const Text('Байгууллага олдсонгүй. + товчоор нэмнэ үү.'),
          const SizedBox(height: 9),
        ],
        TextField(
          controller: noteController,
          minLines: 1,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Захиалгын тэмдэглэл',
            prefixIcon: Icon(Icons.notes_outlined, size: 17),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 9),
        if (isApiConnected)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const Text(
              'Баримтын дэлгэрэнгүй',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            children: [
              TextField(
                readOnly: true,
                onTap: _pickInvoiceDate,
                decoration: InputDecoration(
                  labelText: 'Баримтын огноо',
                  hintText: _formatInvoiceDate(invoiceDate),
                  prefixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: vatAccountController,
                decoration: const InputDecoration(
                  labelText: 'НӨАТ-тай төлбөрийн данс',
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: noVatAccountController,
                decoration: const InputDecoration(
                  labelText: 'НӨАТ-гүй төлбөрийн данс',
                ),
              ),
            ],
          ),
        Row(
          children: [
            const Text(
              'Завсрын дүн',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '₮${_money(total)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'НӨАТ (10%)',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '₮${_money(vat)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 5,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Баримтын төрөл',
              style: TextStyle(color: muted, fontSize: 11),
            ),

            _VatChoice(
              label: 'НӨАТ-тай',
              selected: withVat,
              onTap: () => setState(() => withVat = true),
            ),

            _VatChoice(
              label: 'НӨАТ-гүй',
              selected: !withVat,
              onTap: () => setState(() => withVat = false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Нийт',
              style: TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '₮${_money(total + vat)}',
              style: const TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        SizedBox(
          width: double.infinity,
          height: 43,
          child: FilledButton(
            onPressed: count == 0 || apiBusy
                ? null
                : () => _checkout(
                    context,
                    includeVat: withVat,
                    documentTitle: 'Төлбөрийн баримт',
                  ),
            style: FilledButton.styleFrom(
              backgroundColor: green,
              disabledBackgroundColor: lineColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 17),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Төлбөрийн баримт',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                if (apiBusy)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: count == 0 || apiBusy
                    ? null
                    : () => _checkout(
                        context,
                        includeVat: true,
                        documentTitle: 'НӨАТ-тай нэхэмжлэх',
                      ),
                icon: const Icon(Icons.receipt_outlined, size: 15),
                label: const Text('НӨАТ-тай нэхэмжлэх', maxLines: 1),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: count == 0 || apiBusy
                    ? null
                    : () => _checkout(
                        context,
                        includeVat: false,
                        documentTitle: 'НӨАТ-гүй нэхэмжлэх',
                      ),
                icon: const Icon(Icons.receipt_outlined, size: 15),
                label: const Text('НӨАТ-гүй', maxLines: 1),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _checkout(
    BuildContext context, {
    required bool includeVat,
    required String documentTitle,
  }) async {
    final receiptItems = cart.entries.map((entry) {
      final product = products[entry.key];
      final stock = product.apiStock ?? const <String, dynamic>{};
      return {
        'name': product.name,
        'variant': product.detail,
        'code': product.reference,
        'lot': stock['lot_number'] ?? product.lotNumber,
        'expiry': stock['expiration_date'] ?? '',
        'quantity': entry.value,
        'unitPrice': _salePrice(entry.key),
      };
    }).toList();
    final receiptSubtotal = total;
    final receiptTax = _taxFor(includeVat);
    final receiptTotal = receiptSubtotal + receiptTax;
    final company = apiCompanies.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id']?.toString() == selectedApiCompanyId,
      orElse: () => null,
    );
    final companyName = company == null ? selectedCompany : _refName(company);
    if (isApiConnected) {
      setState(() {
        apiBusy = true;
        apiError = null;
      });
      try {
        final response = await _submitApiOrder(includeVat: includeVat);
        final data = response['data'];
        final serverInvoiceNumber = data is Map
            ? (data['invoice_number'] ?? data['invoiceNumber'])?.toString()
            : null;
        final invoiceNumber =
            (serverInvoiceNumber == null || serverInvoiceNumber.isEmpty)
            ? (response['_generatedInvoiceNumber'] ?? '').toString()
            : serverInvoiceNumber;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$documentTitle хадгалагдлаа.')),
          );
          await _showPaymentReceipt(
            documentTitle: documentTitle,
            invoiceNumber: invoiceNumber,
            companyName: companyName,
            items: receiptItems,
            subtotal: receiptSubtotal,
            tax: receiptTax,
            total: receiptTotal,
            includeVat: includeVat,
          );
        }
      } catch (error) {
        if (mounted) {
          setState(() => apiError = '$error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Захиалга хадгалагдсангүй: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => apiBusy = false);
      }
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$documentTitle (туршилт)'),
        content: Text(
          'Завсрын дүн: ₮${_money(receiptSubtotal)}\nНӨАТ: ₮${_money(receiptTax)}\nНийт: ₮${_money(receiptTotal)}\nГүйлгээг бүртгэхийн тулд системд холбогдоно уу.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                final adjustments = stockAdjustments[selectedCompany]!;
                for (final entry in cart.entries) {
                  adjustments[entry.key] =
                      (adjustments[entry.key] ?? 0) - entry.value;
                }
                _clearCart();
              });
            },
            child: const Text('Дуусгах'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentReceipt({
    required String documentTitle,
    required String invoiceNumber,
    required String companyName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double total,
    required bool includeVat,
  }) async {
    final dateLabel =
        '${invoiceDate.year} оны ${invoiceDate.month} сарын ${invoiceDate.day} өдөр';
    var landscape = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog.fullscreen(
            backgroundColor: panelColor,
            child: Column(
              children: [
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Зарлагын баримт',
                    style: TextStyle(
                      color: ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1, color: lineColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: landscape ? 1320 : 1120,
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(40, 34, 40, 38),
                        color: Colors.white,
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Color(0xff171717),
                            fontSize: 14,
                            height: 1.3,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Сангийн сайдын 2017 оны 12 дугаар сарын\n05 өдрийн 347 тоот тушаалын хавсралт',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ЗАРЛАГЫН БАРИМТ № ${invoiceNumber.isEmpty ? '—' : invoiceNumber}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentBusinessName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Text(
                                          '/байгууллагын нэр/',
                                          style: TextStyle(
                                            color: Color(0xff666666),
                                          ),
                                        ),
                                        const Text('Регистрийн №: —'),
                                        Text(dateLabel),
                                        Text(
                                          '${includeVat ? 'НӨАТ-ын данс' : 'НӨАТ-гүй данс'}: ${includeVat ? vatAccountController.text : noVatAccountController.text}'
                                              .trim(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Худалдан авагчийн нэр:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(companyName),
                                        const Text(
                                          'Регистрийн №:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Text('—'),
                                        const Text(
                                          'Төлөөлөгчийн хаяг: —',
                                          style: TextStyle(
                                            color: Color(0xff666666),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _invoiceTable(items, total),
                              Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 360,
                                  child: Column(
                                    children: [
                                      if (includeVat)
                                        _invoiceSummaryRow('НӨАТ', tax),
                                      _invoiceSummaryRow(
                                        'Нийт',
                                        total,
                                        bold: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Хүлээлгэн өгсөн ........................................\nХүлээн авсан .............................................\nШалгасан нягтлан бодогч ............................',
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Хаах'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () =>
                            setDialogState(() => landscape = false),
                        child: const Text('Босоо'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setDialogState(() => landscape = true),
                        child: const Text('Хөндлөн'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'PDF хэвлэх үйлдэл дараагийн шинэчлэлтээр нэмэгдэнэ.',
                                ),
                              ),
                            ),
                        icon: const Icon(Icons.print),
                        label: const Text('Хэвлэх / PDF'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _invoiceTable(List<Map<String, dynamic>> items, double total) {
    const border = BorderSide(color: Color(0xff222222), width: 1);
    Widget cell(
      Widget child, {
      bool header = false,
      Alignment alignment = Alignment.centerLeft,
    }) => Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: header ? const Color(0xfff2f2f2) : Colors.white,
        border: const Border(right: border, bottom: border),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontWeight: header ? FontWeight.bold : FontWeight.normal,
        ),
        child: child,
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: border, top: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                child: cell(
                  const Text('№', textAlign: TextAlign.center),
                  header: true,
                  alignment: Alignment.center,
                ),
              ),
              Expanded(
                child: cell(
                  const Text('Бараа мэдээлэл', textAlign: TextAlign.center),
                  header: true,
                  alignment: Alignment.center,
                ),
              ),
              SizedBox(
                width: 68,
                child: cell(
                  const Text('Тоо', textAlign: TextAlign.center),
                  header: true,
                  alignment: Alignment.center,
                ),
              ),
              SizedBox(
                width: 125,
                child: cell(
                  const Text('Нэгж үнэ', textAlign: TextAlign.center),
                  header: true,
                  alignment: Alignment.center,
                ),
              ),
              SizedBox(
                width: 140,
                child: cell(
                  const Text('Нийт дүн', textAlign: TextAlign.center),
                  header: true,
                  alignment: Alignment.center,
                ),
              ),
            ],
          ),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            final quantity = _asInt(item['quantity']);
            final unitPrice = _orderNumber(item['unitPrice']);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 42,
                    child: cell(
                      Text('${entry.key + 1}'),
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  Expanded(
                    child: cell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if ((item['variant'] ?? '').toString().isNotEmpty)
                            Text('${item['variant']}'),
                          if ((item['code'] ?? '').toString().isNotEmpty)
                            Text('Код савлагаа: ${item['code']}'),
                          if ((item['lot'] ?? '').toString().isNotEmpty)
                            Text('Лот цувралын дугаар: ${item['lot']}'),
                          if ((item['expiry'] ?? '').toString().isNotEmpty)
                            Text('Дуусах: ${item['expiry']}'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 68,
                    child: cell(
                      Text('$quantity'),
                      alignment: Alignment.topRight,
                    ),
                  ),
                  SizedBox(
                    width: 125,
                    child: cell(
                      Text(_money(unitPrice)),
                      alignment: Alignment.topRight,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: cell(
                      Text(_money(unitPrice * quantity)),
                      alignment: Alignment.topRight,
                    ),
                  ),
                ],
              ),
            );
          }),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 193,
                child: cell(
                  const Text('Нийт', textAlign: TextAlign.right),
                  header: true,
                  alignment: Alignment.centerRight,
                ),
              ),
              SizedBox(
                width: 140,
                child: cell(
                  Text(_money(total), textAlign: TextAlign.right),
                  header: true,
                  alignment: Alignment.centerRight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _invoiceSummaryRow(String label, double amount, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            Text(
              _money(amount),
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}
