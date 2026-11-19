part of '../main.dart';

class _ProductBulkImportDialog extends StatefulWidget {
  final String apiToken;
  const _ProductBulkImportDialog({required this.apiToken});

  @override
  State<_ProductBulkImportDialog> createState() =>
      _ProductBulkImportDialogState();
}

class _ProductBulkImportDialogState extends State<_ProductBulkImportDialog> {
  static const _apiBase = 'https://api.oyudent.com/admin/api/v1';
  static const _importPath = '/product/excel';
  PlatformFile? workbook;
  PlatformFile? images;
  late final tokenController = TextEditingController(text: widget.apiToken);
  bool importing = false;
  bool upsert = false;
  bool dryRun = false;
  String? result;
  bool? succeeded;

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }

  Future<PlatformFile?> _pickFile(List<String> extensions) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    return selection?.files.single;
  }

  Future<void> _import() async {
    final excel = workbook;
    if (excel == null || excel.bytes == null) return;
    final token = tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        result =
            'Enter an API access token to sign in to the product import API.';
        succeeded = false;
      });
      return;
    }
    setState(() {
      importing = true;
      result = null;
      succeeded = null;
    });
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_apiBase$_importPath'))
            ..headers['Authorization'] = 'Bearer $token'
            ..fields['upsert'] = '$upsert'
            ..fields['dry_run'] = '$dryRun';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          excel.bytes!,
          filename: excel.name,
        ),
      );
      final zip = images;
      if (zip?.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images_zip',
            zip!.bytes!,
            filename: zip.name,
          ),
        );
      }
      final response = await request.send().timeout(const Duration(minutes: 3));
      final body = await response.stream.bytesToString();
      if (!mounted) return;
      setState(() {
        succeeded = response.statusCode >= 200 && response.statusCode < 300;
        result = succeeded!
            ? 'Import completed. ${body.isEmpty ? '' : body}'
            : 'Import failed (${response.statusCode}). ${body.isEmpty ? 'Check your token, files, and API access.' : body}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        succeeded = false;
        result = 'Could not reach the Oyudent API: $error';
      });
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import products'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Import products from the Oyudent bulk product files.'),
            const SizedBox(height: 6),
            const Text(
              'The workbook includes Products and Variants sheets; the ZIP can provide product and variant images.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('1) Excel workbook (.xlsx)'),
            const SizedBox(height: 7),
            _FilePickerRow(
              buttonText: 'Choose Excel',
              filename: workbook?.name ?? 'No workbook selected',
              onPressed: importing
                  ? null
                  : () async {
                      final file = await _pickFile(['xlsx']);
                      if (file != null) setState(() => workbook = file);
                    },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Update existing products',
                style: TextStyle(fontSize: 12),
              ),
              subtitle: const Text(
                'upsert',
                style: TextStyle(color: muted, fontSize: 10),
              ),
              value: upsert,
              onChanged: importing
                  ? null
                  : (value) => setState(() => upsert = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Preview only (dry run)',
                style: TextStyle(fontSize: 12),
              ),
              subtitle: const Text(
                'Do not change products in the account',
                style: TextStyle(color: muted, fontSize: 10),
              ),
              value: dryRun,
              onChanged: importing
                  ? null
                  : (value) => setState(() => dryRun = value),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('2) Product images (.zip, optional)'),
            const SizedBox(height: 7),
            _FilePickerRow(
              buttonText: 'Choose ZIP',
              filename: images?.name ?? 'No image archive selected',
              onPressed: importing
                  ? null
                  : () async {
                      final file = await _pickFile(['zip']);
                      if (file != null) setState(() => images = file);
                    },
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Oyudent API access token'),
            const SizedBox(height: 7),
            TextField(
              controller: tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Paste your bearer token',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your token is used for this request only and is not saved.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            if (result != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: succeeded == true
                      ? const Color(0xFFE8F5EC)
                      : const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  result!,
                  style: TextStyle(
                    color: succeeded == true
                        ? const Color(0xFF176B4B)
                        : const Color(0xFF9E3128),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: importing ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: importing || workbook == null ? null : _import,
        icon: importing
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_upload_outlined, size: 17),
        label: Text(importing ? 'Importing…' : 'Start import'),
        style: FilledButton.styleFrom(backgroundColor: green),
      ),
    ],
  );
}

class _FilePickerRow extends StatelessWidget {
  final String buttonText;
  final String filename;
  final VoidCallback? onPressed;
  const _FilePickerRow({
    required this.buttonText,
    required this.filename,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ),
    ],
  );
}

class _NewExpenseDialog extends StatefulWidget {
  const _NewExpenseDialog();
  @override
  State<_NewExpenseDialog> createState() => _NewExpenseDialogState();
}

class _NewExpenseDialogState extends State<_NewExpenseDialog> {
  String category = 'Supplies';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add expense'),
    content: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Description'),
          const SizedBox(height: 6),
          const TextField(
            decoration: InputDecoration(hintText: 'e.g. Coffee beans'),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Amount (₮)'),
          const SizedBox(height: 6),
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: '0'),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Category'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: category,
            items: [
              'Supplies',
              'Rent',
              'Utilities',
              'Other',
            ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setState(() => category = v ?? category),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        style: FilledButton.styleFrom(backgroundColor: green),
        child: const Text('Save expense'),
      ),
    ],
  );
}
