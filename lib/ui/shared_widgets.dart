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
    color: const Color(0xFFFFF5E5),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB45309),
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$company · $warehouse: $count product${count == 1 ? '' : 's'} at or below 5 in stock',
                style: const TextStyle(
                  color: Color(0xFF87430B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              'View',
              style: TextStyle(
                color: Color(0xFF87430B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, color: Color(0xFF87430B), size: 17),
          ],
        ),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  final bool inverse;
  const _Brand({this.inverse = false});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: inverse ? aquaGlow : green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.storefront_rounded, size: 19, color: deepSpace),
      ),
      const SizedBox(width: 10),
      Text(
        'oyudent',
        style: TextStyle(
          color: inverse ? Colors.white : ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        'POS',
        style: TextStyle(
          color: inverse ? const Color(0xFFB2BCD7) : muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ],
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
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF414980) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? aquaGlow : const Color(0xFFB2BCD7),
            ),
            const SizedBox(width: 11),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFD6DDEF),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
  Widget build(BuildContext context) => Container(
    height: 77,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Colors.white, Color(0xFFEEF0FF)]),
      border: Border(bottom: BorderSide(color: lineColor)),
    ),
    child: Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
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
        color: connected ? const Color(0xFFE8F5EC) : const Color(0xFFFFF4E2),
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
              color: connected ? green : const Color(0xFFD58C20),
            ),
          const SizedBox(width: 6),
          Text(
            loading
                ? 'Connecting…'
                : connected
                ? 'Oyudent API'
                : 'Demo mode · Connect',
            style: TextStyle(
              color: connected ? green : const Color(0xFF956415),
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
    color: active ? green : Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : muted,
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
    color: selected ? const Color(0xFFEAF2EC) : Colors.transparent,
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
      backgroundColor: failed ? const Color(0xff892d39) : deepSpaceMid,
      content: Row(
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
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
