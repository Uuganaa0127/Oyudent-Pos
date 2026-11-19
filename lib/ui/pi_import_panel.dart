part of '../main.dart';

class _PiImportPanel extends StatefulWidget {
  final TextEditingController secret, paste;
  final PlatformFile? file;
  final bool busy, retry;
  final String stage;
  final double? progress;
  final ValueChanged<PlatformFile?> onFile;
  final ValueChanged<String> onError;
  final VoidCallback onImport;
  const _PiImportPanel({
    required this.secret,
    required this.paste,
    required this.file,
    required this.busy,
    required this.retry,
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
      if (mounted && result != null) widget.onFile(result.files.single);
    } catch (e) {
      if (mounted) widget.onError('Could not open invoice: $e');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.busy || picking;
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
                    'Supplier invoice import',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                TextField(
                  controller: widget.secret,
                  enabled: !locked,
                  obscureText: !reveal,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Kimi API key',
                    hintText: 'Enter your API key',
                    helperText: 'Kept in memory while this page is open.',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      tooltip: reveal ? 'Hide API key' : 'Show API key',
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
                                ? 'Choose invoice file'
                                : 'Replace file',
                          ),
                        ),
                        if (widget.file != null) ...[
                          Text(widget.file!.name),
                          IconButton(
                            tooltip: 'Remove file',
                            onPressed: locked
                                ? null
                                : () => widget.onFile(null),
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
                      labelText: 'Or paste invoice text',
                      alignLabelWithHint: true,
                    ),
                  ),
                if (locked) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      picking ? 'Opening invoice file…' : widget.stage,
                    ),
                  ),
                  LinearProgressIndicator(
                    value: picking ? null : widget.progress,
                    semanticsLabel: picking ? 'Opening file' : widget.stage,
                  ),
                ],
                ListenableBuilder(
                  listenable: Listenable.merge([widget.secret, widget.paste]),
                  builder: (context, _) => FilledButton.icon(
                    onPressed:
                        locked ||
                            widget.secret.text.trim().isEmpty ||
                            (widget.file == null &&
                                widget.paste.text.trim().isEmpty)
                        ? null
                        : widget.onImport,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(
                      widget.busy
                          ? 'Import in progress…'
                          : widget.retry
                          ? 'Retry invoice import'
                          : 'Send to Kimi and check catalog',
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
