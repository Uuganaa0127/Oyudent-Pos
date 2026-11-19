part of '../main.dart';

class _GlobalStockWarning extends StatelessWidget {
  final String company, warehouse;
  final int count;
  final VoidCallback onTap;
  const _GlobalStockWarning({
    required this.company,
    required this.warehouse,
    required this.count,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: warningSurface,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: warningInk,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$company · $warehouse: $count нэр төрлийн барааны үлдэгдэл 5 буюу түүнээс бага байна',
                style: const TextStyle(
                  color: warningInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              'Харах',
              style: TextStyle(
                color: warningInk,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, color: warningInk, size: 17),
          ],
        ),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 36,
          child: CustomPaint(painter: _MolarMark()),
        ),
        SizedBox(width: 8),
        Text(
          'OYUDENT',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(width: 5),
        Text(
          'POS',
          style: TextStyle(
            color: aquaGlow,
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: ink,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? activeSurface : Colors.transparent,
          border: Border(
            left: BorderSide(
              width: 3,
              color: selected ? green : Colors.transparent,
            ),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? green : muted),
            const SizedBox(width: 11),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? green : ink,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  final String title, subtitle;
  final Widget? trailing;
  const _TopBar({required this.title, required this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [panelColor, deepSpaceMid, panelColor]),
      border: Border(bottom: BorderSide(color: lineColor)),
    ),
    child: CustomPaint(
      painter: const _HeaderTraces(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final heading = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 23,
                    height: 1.12,
                    letterSpacing: -.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            );
            if (bounds.maxWidth < 630 && trailing != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: trailing!,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                if (trailing != null) trailing!,
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ConnectionPill extends StatelessWidget {
  final bool connected;
  final bool loading;
  final VoidCallback onTap;
  const _ConnectionPill({
    required this.connected,
    required this.loading,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: loading ? null : onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? activeSurface : warningSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(
              Icons.circle,
              size: 7,
              color: connected ? aquaGlow : warningInk,
            ),
          const SizedBox(width: 6),
          Text(
            loading
                ? 'Холбогдож байна…'
                : connected
                ? 'Оюудент API'
                : 'Туршилтын горим · Холбогдох',
            style: TextStyle(
              color: connected ? aquaGlow : warningInk,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _CategoryChip({required this.label, this.active = false, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: active ? green : panelColor,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: active ? deepSpace : muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _VatChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _VatChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? activeSurface : Colors.transparent,
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? green : muted,
            fontSize: 9,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

// API lists may repeat IDs or change while a picker is on screen.
class _ReferenceDropdown extends StatelessWidget {
  final String? initialValue;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final InputDecoration decoration;
  final Color? dropdownColor;
  final TextStyle? style;

  const _ReferenceDropdown({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    required this.decoration,
    this.dropdownColor,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final ids = <String>{};
    final choices = items.where((item) {
      final id = item.value;
      return id != null && id.trim().isNotEmpty && ids.add(id);
    }).toList();
    final selected = ids.contains(initialValue) ? initialValue : null;
    return InputDecorator(
      decoration: decoration,
      isEmpty: selected == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          items: choices,
          onChanged: onChanged,
          isExpanded: true,
          isDense: true,
          dropdownColor: dropdownColor,
          style: style,
        ),
      ),
    );
  }
}

void _notice(BuildContext context, String message, {bool failed = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: failed ? errorSurface : activeSurface,
      content: Row(
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            color: failed ? errorInk : green,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _BusyBar extends StatelessWidget {
  final String label;
  const _BusyBar(this.label);
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(height: 8),
            LinearProgressIndicator(semanticsLabel: label),
          ],
        ),
      ),
    ),
  );
}
