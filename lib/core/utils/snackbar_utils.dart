import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showGlobalSnackBar(String message, {Color backgroundColor = Colors.red}) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

String parseErrorMessage(dynamic e, String defaultMessage) {
  if (e is Exception) {
    // If it's a DioException, try to extract nested error message
    try {
      // We can use reflection-free check or dynamic properties
      final dynamic err = e;
      if (err.response?.data != null) {
        final errorData = err.response.data;
        if (errorData is Map) {
          final details = errorData['details'];
          if (details is Map && details['error'] is Map) {
            final metaError = details['error'] as Map;
            return metaError['error_user_msg'] ?? 
                   metaError['error_user_title'] ?? 
                   metaError['message'] ?? 
                   defaultMessage;
          } else if (errorData['error'] is Map) {
            return errorData['error']['message'] ?? defaultMessage;
          } else if (errorData['error'] is String) {
            return errorData['error'];
          }
        }
      }
      if (err.message != null) {
        return err.message;
      }
    } catch (_) {}
  }
  
  final str = e.toString();
  if (str.startsWith('Exception: ')) {
    return str.substring('Exception: '.length);
  }
  return str.isNotEmpty ? str : defaultMessage;
}
