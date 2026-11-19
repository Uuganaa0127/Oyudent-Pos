part of '../main.dart';

class _ExpenseHeader extends StatelessWidget {
  const _ExpenseHeader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      children: [
        Expanded(flex: 4, child: Text('ТАЙЛБАР', style: _tableHead)),
        Expanded(flex: 2, child: Text('АНГИЛАЛ', style: _tableHead)),
        Expanded(flex: 2, child: Text('ОГНОО', style: _tableHead)),
        Expanded(flex: 2, child: Text('ТӨЛБӨР', style: _tableHead)),
        SizedBox(
          width: 100,
          child: Text('ДҮН', textAlign: TextAlign.right, style: _tableHead),
        ),
      ],
    ),
  );
}

const _tableHead = TextStyle(
  fontFamily: 'monospace',
  color: muted,
  fontSize: 9,
  letterSpacing: .8,
  fontWeight: FontWeight.w700,
);

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  const _ExpenseRow({required this.expense});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            expense.title,
            style: const TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            expense.category,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            expense.date,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            expense.method,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            '₮${_money(expense.amount.toDouble())}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

String _money(double n) {
  final parts = n.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length == 2 && parts.last != '00'
      ? '$whole.${parts.last}'
      : whole;
}
