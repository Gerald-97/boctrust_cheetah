part of '../app_flow/app_flow_navigator.dart';

class TransactionContext {
  const TransactionContext({
    required this.amount,
    required this.description,
    required this.title,
    required this.row1Label,
    required this.row1Value,
    required this.row2Label,
    required this.row2Value,
    this.fee = '₦0.00',
  });

  final String amount;
  final String description;
  final String title;
  final String row1Label;
  final String row1Value;
  final String row2Label;
  final String row2Value;
  final String fee;
}
