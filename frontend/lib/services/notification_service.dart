import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/services/auth_service.dart';

class NotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static RealtimeChannel? _requestsChannel;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize listeners for the current user
  static Future<void> init(BuildContext context) async {
    // Initialize Local Notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _localNotifications.initialize(initSettings);

    final role = await AuthService.getRole();
    final uid = await AuthService.getUid();
    
    if (role == null || uid == null) return;

    // Remove existing channel if any
    _requestsChannel?.unsubscribe();

    if (role == 'Warden') {
      _initWardenListener();
    } else if (role == 'Student') {
      _initStudentListener(uid);
    }
  }

  static void _initWardenListener() {
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
            _showSystemNotification(
              "🚨 Alert Notified: New Request!", 
              "A student just submitted a leave request that requires your approval."
            );
          },
        )
        .subscribe();
  }

  static void _initStudentListener(String uid) {
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
               String title = "Gate Pass Update";
               String msg = "";
               if (newStatus == 'Parent_Approved') {
                 title = "📞 Parent Approved";
                 msg = "Your parent has approved your request. Waiting for Warden.";
               } else if (newStatus == 'Warden_Approved' || newStatus == 'Approved') {
                 title = "✅ Request Approved!";
                 msg = "Your Gate Pass is generated and ready to use.";
               } else if (newStatus == 'Rejected') {
                 title = "❌ Request Rejected";
                 msg = "Your leave request was unfortunately rejected.";
               }

               if (msg.isNotEmpty) {
                 _showSystemNotification(title, msg);
               }
            }
          },
        )
        .subscribe();
  }

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

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Generate a unique ID
    final int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notifId,
      title,
      body,
      notificationDetails,
    );
  }

  static void dispose() {
    _requestsChannel?.unsubscribe();
  }
}
