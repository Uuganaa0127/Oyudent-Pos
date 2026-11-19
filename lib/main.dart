import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show compute;
import 'services/invoice_excel.dart';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'services/oyudent_api.dart';
import 'services/kimi_pi.dart';
import 'services/timed_http.dart';
part 'ui/pi_review.dart';
part 'ui/pi_import_panel.dart';
part 'ui/warehouse_search.dart';

part 'ui/app_theme.dart';
part 'ui/design_tokens.dart';
part 'ui/identity.dart';
part 'ui/reference_page.dart';
part 'ui/login_page.dart';
part 'ui/pos_shell.dart';
part 'ui/invoice_pages.dart';
part 'ui/order_details.dart';
part 'ui/product_pages.dart';
part 'ui/incoming_invoice_page.dart';
part 'ui/shipment_pricing.dart';
part 'ui/dialogs.dart';
part 'ui/shared_widgets.dart';
part 'models/product.dart';
part 'ui/product_widgets.dart';
part 'models/expense.dart';
part 'ui/expense_widgets.dart';

void main() => runApp(const OyudentPosApp());
