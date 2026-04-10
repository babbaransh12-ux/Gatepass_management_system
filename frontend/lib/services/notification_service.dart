import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/services/auth_service.dart';

class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static RealtimeChannel? _requestsChannel;
  static RealtimeChannel? _wardenUpdateChannel;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize listeners for the current user
  static Future<void> init(BuildContext context) async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(initSettings);

    final role = await AuthService.getRole();
    final uid = await AuthService.getUid();

    if (role == null || uid == null) return;

    // Tear down any previous subscriptions
    _requestsChannel?.unsubscribe();
    _wardenUpdateChannel?.unsubscribe();

    if (role == 'Warden') {
      _initWardenListener();
    } else if (role == 'Student') {
      _initStudentListener(uid);
    }
  }

  // ──────────────────────────── WARDEN ───────────────────────────────────────

  static void _initWardenListener() {
    // Channel 1: New student request inserted (Status=Pending)
    _requestsChannel = _supabase
        .channel('warden-new-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Leave_request',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'Status',
            value: 'Pending',
          ),
          callback: (_) => _showSystemNotification(
            "🔔 New Leave Request",
            "A student submitted a leave request — awaiting IVR parent approval.",
          ),
        )
        .subscribe();

    // Channel 2: Parent approved — warden action now needed
    _wardenUpdateChannel = _supabase
        .channel('warden-parent-approved')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'Leave_request',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'Status',
            value: 'Parent_Approved',
          ),
          callback: (_) => _showSystemNotification(
            "🚨 Action Required: Parent Approved!",
            "A parent approved a student request. Please review it now.",
          ),
        )
        .subscribe();
  }

  // ──────────────────────────── STUDENT ──────────────────────────────────────

  static void _initStudentListener(String uid) {
    _requestsChannel = _supabase
        .channel('student-status-$uid')
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

            if (newStatus == oldStatus) return;

            String title = '';
            String msg = '';

            switch (newStatus) {
              case 'Parent_Approved':
                title = "📞 Parent Approved";
                msg = "Your parent approved the request. Waiting for Warden.";
                break;
              case 'Approved':
                title = "✅ Gate Pass Ready!";
                msg = "Your gate pass is approved. The QR code is ready to use.";
                break;
              case 'Rejected':
                title = "❌ Request Rejected";
                msg = "Your leave request was rejected. You may reapply after the cooldown.";
                break;
              case 'Exit':
                title = "🚪 Exit Recorded";
                msg = "Your exit from campus has been recorded. Return safely!";
                break;
              case 'Completed':
                title = "🏠 Welcome Back!";
                msg = "Entry recorded. Your gate pass is fully completed.";
                break;
            }

            if (msg.isNotEmpty) {
              _showSystemNotification(title, msg);
            }
          },
        )
        .subscribe();
  }

  // ──────────────────────────── HELPERS ──────────────────────────────────────

  static Future<void> _showSystemNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'egatepass_alerts',
      'E-Gatepass Alerts',
      channelDescription: 'Important alerts for gatepass updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(notifId, title, body, details);
  }

  static void dispose() {
    _requestsChannel?.unsubscribe();
    _wardenUpdateChannel?.unsubscribe();
  }
}
