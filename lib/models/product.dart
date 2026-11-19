part of '../main.dart';

class Product {
  final String name, detail, emoji;
  final String reference, lotNumber, barcode;
  final String categoryCode, categoryName;
  final String? imageUrl;
  final int price, oyudentStock, centechStock;
  final Color tint;
  final Map<String, dynamic>? apiStock;
  String get searchText {
    final source = apiStock ?? const <String, dynamic>{};
    return [
      name,
      detail,
      reference,
      barcode,
      lotNumber,
      categoryName,
      source['name'],
      source['product_name'],
      source['product_display_name'],
      source['product_mn_name'],
      source['mn_name'],
      source['mnName'],
      source['english_name'],
      source['en_name'],
      source['name_en'],
      source['sku'],
      source['code'],
      source['manufacturer_name'],
      source['supplier_name'],
      source['supplier_code'],
      source['partner_name'],
      source['barcode'],
      source['size'],
      source['size_name'],
      source['color'],
      source['color_name'],
      source['unit'],
      source['unit_name'],
      source['unitOfMeasure'],
      source['unit_of_measure'],
      source['variant_size'],
      source['variant_color'],
      source['variant_unit'],
    ].whereType<Object>().join(' ').toLowerCase();
  }

  const Product(
    this.name,
    this.detail,
    this.price,
    this.emoji,
    this.tint, {
    required this.reference,
    required this.lotNumber,
    required this.barcode,
    required this.oyudentStock,
    required this.centechStock,
    this.categoryCode = '',
    this.categoryName = '',
    this.imageUrl,
    this.apiStock,
  });

  factory Product.fromApi(Map<String, dynamic> stock) {
    final name =
        (stock['product_display_name'] ??
                stock['product_name'] ??
                stock['product_mn_name'] ??
                stock['name'] ??
                stock['mn_name'] ??
                'Product')
            .toString();
    final categoryName = (stock['category_name'] ?? stock['category'] ?? '')
        .toString();
    final categoryCode = (stock['category_code'] ?? stock['categoryCode'] ?? '')
        .toString();
    final size = (stock['size_name'] ?? '').toString();
    final unit = (stock['unit_name'] ?? '').toString();
    final warehouse = (stock['warehouse_name'] ?? '').toString();
    final detail = [
      categoryName,
      size,
      unit,
      warehouse,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    return Product(
      name,
      detail.isEmpty ? 'Inventory item' : detail,
      _asInt(stock['unit_price'] ?? stock['base_unit_price'] ?? stock['price']),
      '📦',
      const Color(0xFFE9EFE4),
      reference: (stock['sku'] ?? stock['product_code'] ?? stock['code'] ?? '')
          .toString(),
      lotNumber: (stock['lot_number'] ?? stock['expiration_date'] ?? '')
          .toString(),
      barcode: (stock['barcode'] ?? '').toString(),
      oyudentStock: _asInt(stock['quantity']),
      centechStock: _asInt(stock['quantity']),
      categoryCode: categoryCode,
      categoryName: categoryName,
      imageUrl: _productImageUrl(
        stock['images'] ??
            stock['image'] ??
            stock['image_path'] ??
            stock['main_image'],
      ),
      apiStock: stock,
    );
  }

  factory Product.fromCatalog(Map<String, dynamic> product) {
    final name =
        (product['name'] ??
                product['mn_name'] ??
                product['product_display_name'] ??
                'Product')
            .toString();
    final categoryName = (product['category_name'] ?? '').toString();
    final description = (product['description'] ?? '').toString();
    return Product(
      name,
      description.trim().isEmpty
          ? (categoryName.isEmpty ? 'No stock in this branch' : categoryName)
          : description,
      0,
      '📦',
      const Color(0xFFE9EFE4),
      reference: (product['code'] ?? product['sku'] ?? '').toString(),
      lotNumber: '',
      barcode: '',
      oyudentStock: 0,
      centechStock: 0,
      categoryCode: (product['category_code'] ?? '').toString(),
      categoryName: categoryName,
      imageUrl: _productImageUrl(
        product['images'] ??
            product['image'] ??
            product['image_path'] ??
            product['main_image'],
      ),
      apiStock: product,
    );
  }
}

String? _productImageUrl(dynamic value) {
  if (value is List) {
    for (final image in value) {
      final resolved = _productImageUrl(image);
      if (resolved != null) return resolved;
    }
    return null;
  }
  if (value is Map) {
    return _productImageUrl(
      value['url'] ??
          value['image_url'] ??
          value['imageUrl'] ??
          value['path'] ??
          value['image_path'] ??
          value['src'],
    );
  }
  final path = value?.toString().trim() ?? '';
  if (path.isEmpty) return null;
  if (path.startsWith('https://') || path.startsWith('http://')) return path;
  if (path.startsWith('//')) return 'https:$path';
  return Uri.parse('https://admin.oyudent.com').resolve(path).toString();
}

int _asInt(dynamic value) => value is num
    ? value.toInt()
    : int.tryParse('$value') ?? (double.tryParse('$value')?.round() ?? 0);

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  if (value is Map) {
    for (final key in ['items', 'data', 'rows']) {
      if (value.containsKey(key)) return _asMapList(value[key]);
    }
  }
  return <Map<String, dynamic>>[];
}

Map<String, dynamic> _decodeResponse(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : {'data': decoded};
  } catch (_) {
    return {'message': response.body};
  }
}

String _apiMessage(Map<String, dynamic> body, int statusCode) {
  final errors = body['errors'];
  if (errors is List && errors.isNotEmpty) return errors.first.toString();
  return (body['message'] ??
          body['error'] ??
          'API request failed ($statusCode)')
      .toString();
}

String _refName(Map<String, dynamic> value) =>
    (value['name'] ??
            value['mnName'] ??
            value['mn_name'] ??
            value['title'] ??
            value['code'] ??
            value['id'] ??
            'Option')
        .toString();

String _formatInvoiceDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
