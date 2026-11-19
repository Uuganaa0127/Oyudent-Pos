part of '../main.dart';

class _PiImportPanel extends StatefulWidget {
  final TextEditingController secret, paste;
  final PlatformFile? file;
  final bool busy, retry, converted;
  final String stage;
  final double? progress;
  final void Function(PlatformFile?, bool) onFile;
  final ValueChanged<String> onError;
  final VoidCallback onImport;
  const _PiImportPanel({
    required this.secret,
    required this.paste,
    required this.file,
    required this.busy,
    required this.retry,
    required this.converted,
    required this.stage,
    required this.progress,
    required this.onFile,
    required this.onError,
    required this.onImport,
  });
  @override
  State<_PiImportPanel> createState() => _PiImportPanelState();
}

class _PiImportPanelState extends State<_PiImportPanel> {
  bool reveal = false, picking = false;
  Future<void> pick() async {
    setState(() => picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || !mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('Файлыг уншиж чадсангүй.');
      final ready =
          file.name.toLowerCase().endsWith('.xlsx') &&
          await compute(isReadyInvoiceExcel, bytes);
      if (mounted) widget.onFile(file, ready);
    } catch (e) {
      if (mounted) widget.onError('Нэхэмжлэх нээж чадсангүй: $e');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.busy || picking;
    final converted = widget.converted;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [deepSpace, deepSpaceMid]),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  color: aquaGlow,
                  size: 30,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Нийлүүлэгчийн нэхэмжлэх импортлох',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _SaveConverterButton(enabled: !locked),
                const Text(
                  'Хөрвүүлэгчээр бэлтгэсэн .oyupi.xlsx файлыг түлхүүргүй уншина.',
                ),
                if (!converted)
                  TextField(
                    controller: widget.secret,
                    enabled: !locked,
                    obscureText: !reveal,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Kimi API түлхүүр',
                      hintText: 'API түлхүүрээ оруулна уу',
                      helperText: 'Түлхүүр зөвхөн энэ хуудас нээлттэй үед санах ойд байна.',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        tooltip: reveal ? 'Түлхүүр нуух' : 'Түлхүүр харуулах',
                        onPressed: locked
                            ? null
                            : () => setState(() => reveal = !reveal),
                        icon: Icon(
                          reveal
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: canvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: lineColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: locked ? null : pick,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            widget.file == null
                                ? 'Нэхэмжлэхийн файл сонгох'
                                : 'Файл солих',
                          ),
                        ),
                        if (widget.file != null) ...[
                          Text(widget.file!.name),
                          IconButton(
                            tooltip: 'Файл хасах',
                            onPressed: locked
                                ? null
                                : () => widget.onFile(null, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.file == null)
                  TextField(
                    controller: widget.paste,
                    enabled: !locked,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Эсвэл нэхэмжлэхийн текстийг оруулах',
                      alignLabelWithHint: true,
                    ),
                  ),
                if (locked) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      picking ? 'Нэхэмжлэхийн файл нээж байна…' : widget.stage,
                    ),
                  ),
                  LinearProgressIndicator(
                    value: picking ? null : widget.progress,
                    semanticsLabel: picking ? 'Файл нээж байна' : widget.stage,
                  ),
                ],
                ListenableBuilder(
                  listenable: Listenable.merge([widget.secret, widget.paste]),
                  builder: (context, _) => FilledButton.icon(
                    onPressed:
                        locked ||
                            (!converted && widget.secret.text.trim().isEmpty) ||
                            (widget.file == null &&
                                widget.paste.text.trim().isEmpty)
                        ? null
                        : widget.onImport,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(
                      widget.busy
                          ? 'Импортолж байна…'
                          : widget.retry
                          ? 'Импортыг дахин оролдох'
                          : converted
                          ? 'Excel уншиж каталогтой тулгах'
                          : 'Kimi рүү илгээж каталогтой тулгах',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveConverterButton extends StatefulWidget {
  final bool enabled;
  const _SaveConverterButton({required this.enabled});
  @override
  State<_SaveConverterButton> createState() => _SaveConverterButtonState();
}

class _SaveConverterButtonState extends State<_SaveConverterButton> {
  bool saving = false;
  Future<void> save() async {
    setState(() => saving = true);
    try {
      final data = await rootBundle.load('assets/oyudent-excel.html');
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Excel хөрвүүлэгч хадгалах',
        fileName: 'Oyudent-Excel.html',
        type: FileType.custom,
        allowedExtensions: ['html'],
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      if (mounted && path != null)
        _notice(
          context,
          'Хадгалсан Oyudent-Excel.html файлаа хөтөч дээр нээнэ үү.',
        );
    } catch (e) {
      if (mounted)
        _notice(context, 'Хөрвүүлэгчийг хадгалж чадсангүй: $e', failed: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: widget.enabled && !saving ? save : null,
    icon: const Icon(Icons.table_view_outlined),
    label: Text(saving ? 'Хадгалж байна…' : 'Офлайн Excel хөрвүүлэгч хадгалах'),
  );
}
