import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/sync_data_model.dart';

/// Top-level function for handling background messages when app is terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Handling background message: ${message.messageId}', name: 'FcmBackgroundHandler');

  try {
    final data = message.data;

    // We can't directly use the stream here since the app might be terminated
    // Instead, we could store this in a persistent location and process it when app starts
    // For now, we'll just log it
    if (data.containsKey('tableName') && data.containsKey('uuid')) {
      developer.log('Background sync data received: $data', name: 'FcmBackgroundHandler');
      // TODO: Store in persistent storage for processing when app starts
    }
  } catch (e, stackTrace) {
    developer.log(
      'Error in background message handler: $e',
      error: e,
      stackTrace: stackTrace,
      name: 'FcmBackgroundHandler',
    );
  }
}

class FcmMessagingService {
  static final FcmMessagingService _instance = FcmMessagingService._internal();
  factory FcmMessagingService() => _instance;
  FcmMessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final StreamController<SyncDataModel> _dataMessageController =
      StreamController<SyncDataModel>.broadcast();

  /// Stream of data messages received from FCM
  Stream<SyncDataModel> get dataMessageStream => _dataMessageController.stream;

  static bool hasInit = false;

  /// Initialize FCM and set up listeners
  Future<void> initialize() async {
    if (!hasInit)
      hasInit = true;
    else
      return;
    developer.log('Initializing FCM Messaging Service', name: 'FcmMessagingService');

    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    developer.log(
      'FCM Permission status: ${settings.authorizationStatus}',
      name: 'FcmMessagingService',
    );

    // Get the FCM token
    String? token = await _messaging.getToken();
    developer.log('FCM Token: $token', name: 'FcmMessagingService');

    // Listen to token refresh
    _messaging.onTokenRefresh.listen((String token) {
      developer.log('FCM Token refreshed: $token', name: 'FcmMessagingService');
    });

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen for background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Set up background message handler (when app is terminated)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    developer.log('FCM Messaging Service initialized successfully', name: 'FcmMessagingService');
  }

  /// Handle messages received when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    developer.log('Received foreground message: ${message.messageId}', name: 'FcmMessagingService');
    _processDataMessage(message);
  }

  /// Handle messages received when app is in background or opened from notification
  void _handleBackgroundMessage(RemoteMessage message) {
    developer.log('Received background message: ${message.messageId}', name: 'FcmMessagingService');
    _processDataMessage(message);
  }

  /// Process the data payload from FCM message
  void _processDataMessage(RemoteMessage message) {
    try {
      final data = message.data;
      developer.log('Processing FCM data: $data', name: 'FcmMessagingService');

      // Check if this is a sync data message
      if (data.containsKey('tableName') && data.containsKey('uuid')) {
        final syncData = SyncDataModel.fromFcmPayload(data);
        developer.log('Created SyncDataModel: $syncData', name: 'FcmMessagingService');

        // Emit to stream
        _dataMessageController.add(syncData);
      } else {
        developer.log('Message does not contain sync data format', name: 'FcmMessagingService');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error processing FCM message: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'FcmMessagingService',
      );
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    developer.log('Subscribed to topic: $topic', name: 'FcmMessagingService');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    developer.log('Unsubscribed from topic: $topic', name: 'FcmMessagingService');
  }

  /// Dispose resources
  void dispose() {
    _dataMessageController.close();
  }
}
