part of '../main.dart';

class Expense {
  final String title, category, date, method;
  final int amount;
  const Expense(this.title, this.category, this.date, this.method, this.amount);
}

const _demoExpenses = [
  Expense('Кофены үр · 5 кг', 'Хангамж', '2026.11.17', 'Бэлэн мөнгө', 185000),
  Expense('Сүү, сүүн бүтээгдэхүүн', 'Хангамж', '2026.11.16', 'Дансаар', 92000),
  Expense(
    'Дэлгүүрийн цахилгаан',
    'Ашиглалтын зардал',
    '2026.11.15',
    'Дансаар',
    148500,
  ),
  Expense('Цаасан аяга, таг', 'Хангамж', '2026.11.14', 'Бэлэн мөнгө', 76000),
  Expense('Сарын түрээс', 'Түрээс', '2026.11.12', 'Дансаар', 650000),
  Expense(
    'Цэвэрлэгээний хэрэгсэл',
    'Бусад',
    '2026.11.10',
    'Бэлэн мөнгө',
    42000,
  ),
];
