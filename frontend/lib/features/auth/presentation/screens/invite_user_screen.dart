import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Modèle mock pour l'historique 
enum InviteStatus { pending, used, expired }

class InviteHistoryItem {
  final String email;
  final String role;
  final String sentDate;
  final String timeInfo;
  final InviteStatus status;

  const InviteHistoryItem({
    required this.email,
    required this.role,
    required this.sentDate,
    required this.timeInfo,
    required this.status,
  });
}

const List<InviteHistoryItem> _mockHistory = [
  InviteHistoryItem(
    email: 'sarah@company.com',
    role: 'Admin',
    sentDate: 'Sent 21/02/2026',
    timeInfo: 'Expired',
    status: InviteStatus.expired,
  ),
  InviteHistoryItem(
    email: 'mike@company.com',
    role: 'Operator',
    sentDate: 'Sent 22/02/2026',
    timeInfo: '13h remaining',
    status: InviteStatus.pending,
  ),
  InviteHistoryItem(
    email: 'lisa@company.com',
    role: 'Operator',
    sentDate: 'Sent 10/02/2026',
    timeInfo: 'Expired',
    status: InviteStatus.expired,
  ),
  InviteHistoryItem(
    email: 'john@company.com',
    role: 'Admin',
    sentDate: 'Sent 18/02/2026',
    timeInfo: 'Used',
    status: InviteStatus.used,
  ),
];

