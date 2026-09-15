import 'package:flutter/material.dart';

class StatusStyle {
  static Color color(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'created':
        return const Color(0xFFA78BFA);
      case 'assigned':
      case 'pending':
        return const Color(0xFF9CA3AF);
      case 'acknowledgement':
        return const Color(0xFF8B5CF6);
      case 'in_progress':
      case 'quote_sent':
      case 'sent_quote':
        return const Color(0xFF3B82F6);
      case 'quote_verified':
        return const Color(0xFF16A34A);
      case 'not_verified':
      case 'not_relevant':
        return const Color(0xFFEF4444);
      case 'completed':
      case 'issue_completed':
        return const Color(0xFFEAB308);
      case 'closed':
      case 'approved':
        return const Color(0xFF22C55E);
      case 'revoked':
      case 'on_hold':
      case 'rejected':
      case 'not_required':
        return const Color(0xFFEF4444);
      case 'reassign':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static String label(String? status) {
    final value = (status ?? 'unknown').toLowerCase();
    if (value == 'not_verified') return 'Not Verified';
    return value.split('_').map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1);
    }).join(' ');
  }
}
