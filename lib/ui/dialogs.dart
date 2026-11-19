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
        result = 'Бараа импортлохын тулд API хандалтын токеноо оруулна уу.';
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
            ? 'Импорт дууслаа. ${body.isEmpty ? '' : body}'
            : 'Импорт амжилтгүй (${response.statusCode}). ${body.isEmpty ? 'Токен, файл болон хандалтын эрхээ шалгана уу.' : body}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        succeeded = false;
        result = 'Оюудентийн системтэй холбогдож чадсангүй: $error';
      });
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Бараа импортлох'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Оюудентийн загвар файлаас бараа оруулна.'),
            const SizedBox(height: 6),
            const Text(
              'Excel файл Products болон Variants хуудастай байна. Бараа, хувилбарын зургийг ZIP файлаар хавсаргаж болно.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 20),
            _SaveConverterButton(enabled: !importing),
            const SizedBox(height: 12),
            const _FieldLabel('1. Excel файл (.xlsx)'),
            const SizedBox(height: 7),
            _FilePickerRow(
              buttonText: 'Excel файл сонгох',
              filename: workbook?.name ?? 'Excel файл сонгоогүй',
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
                'Бүртгэлтэй барааг шинэчлэх',
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
                'Урьдчилан шалгах',
                style: TextStyle(fontSize: 12),
              ),
              subtitle: const Text(
                'Барааны бүртгэлд өөрчлөлт оруулахгүй',
                style: TextStyle(color: muted, fontSize: 10),
              ),
              value: dryRun,
              onChanged: importing
                  ? null
                  : (value) => setState(() => dryRun = value),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('2. Барааны зураг (.zip, заавал биш)'),
            const SizedBox(height: 7),
            _FilePickerRow(
              buttonText: 'ZIP файл сонгох',
              filename: images?.name ?? 'Зургийн файл сонгоогүй',
              onPressed: importing
                  ? null
                  : () async {
                      final file = await _pickFile(['zip']);
                      if (file != null) setState(() => images = file);
                    },
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Оюудентийн API хандалтын токен'),
            const SizedBox(height: 7),
            TextField(
              controller: tokenController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Хандалтын токеноо оруулна уу',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Токеныг зөвхөн энэ хүсэлтэд ашиглана.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
            if (result != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: succeeded == true ? activeSurface : errorSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  result!,
                  style: TextStyle(
                    color: succeeded == true ? green : errorInk,
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
        child: const Text('Хаах'),
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
        label: Text(importing ? 'Импортолж байна…' : 'Импортлох'),
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
  String category = 'Хангамж';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Зардал бүртгэх'),
    content: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Тайлбар'),
          const SizedBox(height: 6),
          const TextField(
            decoration: InputDecoration(hintText: 'Жишээ нь: кофены үр'),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Дүн (₮)'),
          const SizedBox(height: 6),
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: '0'),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Ангилал'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: category,
            items: [
              'Хангамж',
              'Түрээс',
              'Ашиглалтын зардал',
              'Бусад',
            ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setState(() => category = v ?? category),
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
        onPressed: () => Navigator.pop(context),
        style: FilledButton.styleFrom(backgroundColor: green),
        child: const Text('Зардал хадгалах'),
      ),
    ],
  );
}
