part of '../main.dart';

class _ReferencePage extends StatefulWidget {
  final String apiToken;
  const _ReferencePage({required this.apiToken});
  @override
  State<_ReferencePage> createState() => _ReferencePageState();
}

class _ReferencePageState extends State<_ReferencePage> {
  static const groups = {
    'COUNTRY': 'Улс',
    'PRODUCT_PARENT_CATEGORY': 'Том ангилал',
    'PRODUCT_CATEGORY': 'Ангилал',
    'PRODUCT_MANUFACTURER': 'Үйлдвэрлэгч',
    'PRODUCT_COLOR': 'Өнгө',
    'PRODUCT_SIZE': 'Хэмжээ',
    'PRODUCT_UNIT': 'Нэгж',
  };
  late final api = OyudentApi(widget.apiToken);
  String group = 'COUNTRY', query = '';
  DateTimeRange? dates;
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final version = ++request;
    setState(() {
      loading = true;
      error = null;
      rows = [];
    });
    try {
      final data = await api.get(
        '/ref-data/ref/list?no_paginate=1&parent_code=$group',
      );
      if (mounted && version == request)
        setState(() => rows = _asMapList(data));
    } catch (e) {
      if (mounted && version == request) setState(() => error = e.toString());
    } finally {
      if (mounted && version == request) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final parent = group;
    try {
      final categories = parent == 'PRODUCT_CATEGORY'
          ? _asMapList(await api.get('/ref-data/PRODUCT_PARENT_CATEGORY'))
          : <Map<String, dynamic>>[];
      if (!mounted || parent != group) return;
      var name = (row?['name'] ?? '').toString(),
          additional = (row?['additional'] ?? '').toString();
      bool saving = false;
      String? issue;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(
                '${groups[parent]} · ${row == null ? "Нэмэх" : "Засах"}',
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (parent == 'PRODUCT_CATEGORY')
                      _ReferenceDropdown(
                        initialValue: additional,
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c['code']?.toString(),
                                child: Text(c['name'].toString()),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Том ангилал',
                        ),
                        onChanged: (v) => update(() => additional = v ?? ''),
                      ),
                    TextFormField(
                      initialValue: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Нэр'),
                      onChanged: (v) => update(() => name = v),
                    ),
                    if (saving) const _BusyBar('Хадгалж байна…'),
                    if (issue != null) Text(issue!),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Хаах'),
                ),
                FilledButton(
                  onPressed: saving || name.trim().isEmpty
                      ? null
                      : () async {
                          update(() => saving = true);
                          try {
                            await api.post('/ref-data/save/ref', {
                              'id': row?['id'] ?? '',
                              'parentCode': parent,
                              'name': name.trim(),
                              'additional': additional,
                            });
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted)
                              update(() {
                                saving = false;
                                issue = e.toString();
                              });
                          }
                        },
                  child: const Text('Хадгалах'),
                ),
              ],
            ),
          ),
        ),
      );
      if (saved == true && mounted) {
        _notice(context, 'Хадгалагдлаа');
        await load();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    if (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Устгах · ${row['name']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Болих'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Устгах'),
              ),
            ],
          ),
        ) !=
        true)
      return;
    try {
      await api.delete(
        '/ref-data/delete/${Uri.encodeComponent(row['id'].toString())}',
      );
      if (mounted) {
        _notice(context, 'Устгагдлаа');
        await load();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = rows.where((r) {
      final date = DateTime.tryParse(r['created_at'].toString());
      return [
            r['name'],
            r['additional_name'],
            r['additionalName'],
          ].join(' ').toLowerCase().contains(query) &&
          (dates == null ||
              date != null &&
                  !date.isBefore(dates!.start) &&
                  date.isBefore(dates!.end.add(const Duration(days: 1))));
    }).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Туслах утга', style: Theme.of(context).textTheme.headlineSmall),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in groups.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: group == entry.key,
                  onSelected: (_) {
                    setState(() {
                      group = entry.key;
                      query = '';
                      dates = null;
                    });
                    load();
                  },
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey(group),
                  decoration: const InputDecoration(labelText: 'Нэрээр хайх'),
                  onChanged: (v) =>
                      setState(() => query = v.trim().toLowerCase()),
                ),
              ),
              IconButton(
                tooltip: 'Үүсгэсэн огноо',
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDateRange: dates,
                  );
                  if (mounted && range != null) setState(() => dates = range);
                },
                icon: const Icon(Icons.date_range),
              ),
              if (dates != null)
                IconButton(
                  onPressed: () => setState(() => dates = null),
                  icon: const Icon(Icons.clear),
                ),
              IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
              FilledButton(
                onPressed: loading ? null : () => edit(),
                child: const Text('Нэмэх'),
              ),
            ],
          ),
          Expanded(
            child: loading
                ? const _BusyBar('Туслах утга ачаалж байна…')
                : error != null
                ? Center(child: Text(error!))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final row = filtered[i];
                      return ListTile(
                        title: Text(row['name'].toString()),
                        subtitle: Text(
                          [
                            row['additional_name'] ?? row['additionalName'],
                            row['created_at'],
                          ].whereType<String>().join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Засах',
                              onPressed: row['id'] == null
                                  ? null
                                  : () => edit(row),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Устгах',
                              onPressed: row['id'] == null
                                  ? null
                                  : () => remove(row),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
