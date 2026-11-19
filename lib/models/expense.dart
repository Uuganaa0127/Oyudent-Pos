part of '../main.dart';

class Expense {
  final String title, category, date, method;
  final int amount;
  const Expense(this.title, this.category, this.date, this.method, this.amount);
}

const _demoExpenses = [
  Expense('Coffee beans · 5 kg', 'Supplies', 'Nov 17, 2026', 'Cash', 185000),
  Expense('Milk and dairy', 'Supplies', 'Nov 16, 2026', 'Bank transfer', 92000),
  Expense(
    'Store electricity',
    'Utilities',
    'Nov 15, 2026',
    'Bank transfer',
    148500,
  ),
  Expense('Paper cups and lids', 'Supplies', 'Nov 14, 2026', 'Cash', 76000),
  Expense('Monthly rent', 'Rent', 'Nov 12, 2026', 'Bank transfer', 650000),
  Expense('Cleaning supplies', 'Other', 'Nov 10, 2026', 'Cash', 42000),
];
