import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/auth_service.dart';

class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static RealtimeChannel? _requestsChannel;

  /// Initialize listeners for the current user
  static Future<void> init(BuildContext context) async {
    final role = await AuthService.getRole();
    final uid = await AuthService.getUid();
    
    if (role == null || uid == null) return;

    // Remove existing channel if any
    _requestsChannel?.unsubscribe();

    if (role == 'Warden') {
      _initWardenListener(context);
    } else if (role == 'Student') {
      _initStudentListener(context, uid);
    }
  }

  static void _initWardenListener(BuildContext context) {
    _requestsChannel = _supabase
        .channel('warden-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Leave_request',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'Status',
            value: 'Pending',
          ),
          callback: (payload) {
            _showNotification(
              context, 
              "New Leave Request", 
              "A new student request is waiting for your approval."
            );
          },
        )
        .subscribe();
  }

  static void _initStudentListener(BuildContext context, String uid) {
    _requestsChannel = _supabase
        .channel('student-status')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Leave_request',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'AU_id',
            value: uid,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['Status'];
            final oldStatus = payload.oldRecord['Status'];

            if (newStatus != oldStatus) {
               String msg = "";
               if (newStatus == 'Parent_Approved') msg = "Your parent has approved your request.";
               else if (newStatus == 'Warden_Approved' || newStatus == 'Approved') msg = "Warden has approved! Your Gate Pass is ready.";
               else if (newStatus == 'Rejected') msg = "Your leave request was rejected.";

               if (msg.isNotEmpty) {
                 _showNotification(context, "Gate Pass Update", msg);
               }
            }
          },
        )
        .subscribe();
  }

  static void _showNotification(BuildContext context, String title, String body) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFF2D5AF0),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: "VIEW", textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  static void dispose() {
    _requestsChannel?.unsubscribe();
  }
}
