import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Shared helpers for presenting API responses without owning navigation.
class ResponseHandler {
  const ResponseHandler._();

  static const Color _successColor = Color(0xFF2F8F5B);
  static const Color _errorColor = Color(0xFFC1443A);
  static const Color _infoColor = Color(0xFF142B45);

  static String messageOrFallback(
    String? message, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final value = message?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  static Future<bool?> showSuccess(String message) =>
      _showToast(message, backgroundColor: _successColor);

  static Future<bool?> showError(String message) =>
      _showToast(message, backgroundColor: _errorColor);

  static Future<bool?> showInfo(String message) =>
      _showToast(message, backgroundColor: _infoColor);

  static Future<bool?> _showToast(
    String message, {
    required Color backgroundColor,
  }) {
    final value = message.trim();
    if (value.isEmpty) return Future<bool?>.value(false);
    return Fluttertoast.showToast(
      msg: value,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 14,
    );
  }
}
