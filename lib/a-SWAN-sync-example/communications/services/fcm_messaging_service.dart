import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../models/sync_data_model.dart';

class FcmMessagingService {
  static final FcmMessagingService _instance = FcmMessagingService._internal();
  factory FcmMessagingService() => _instance;
  FcmMessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final StreamController<SyncDataModel> _dataMessageController =
      StreamController<SyncDataModel>.broadcast();

  Stream<SyncDataModel> get dataMessageStream => _dataMessageController.stream;

  static bool hasInit = false;
  Future<void> initialize() async {
    if (!hasInit)
      hasInit = true;
    else
      return;
    developer.log('Initializing FCM Messaging Service', name: 'FcmMessagingService');

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

    String? token = await _messaging.getToken();
    developer.log('FCM Token: $token', name: 'FcmMessagingService');
    _messaging.onTokenRefresh.listen((String token) {
      developer.log('FCM Token refreshed: $token', name: 'FcmMessagingService');
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    developer.log('FCM Messaging Service initialized successfully', name: 'FcmMessagingService');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    developer.log('Received foreground message: ${message.data}', name: 'FcmMessagingService');
    _processDataMessage(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    developer.log('Received background message: ${message.messageId}', name: 'FcmMessagingService');
    _processDataMessage(message);
  }

  void _processDataMessage(RemoteMessage message) async {
    try {
      developer.log('Processing FCM data: $message.data', name: 'FcmMessagingService');
      if (message.data.containsKey('tableName') && message.data.containsKey('uuid')) {
        var syncData = SyncDataModel.fromFcmPayload(message.data);
        developer.log('Created SyncDataModel: $syncData', name: 'FcmMessagingService');
        _dataMessageController.add(syncData);
      } else
        developer.log('Message does not contain sync data format', name: 'FcmMessagingService');
    } catch (e, stackTrace) {
      developer.log(
        'Error processing FCM message: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'FcmMessagingService',
      );
    }
  }

  Future<String?> getToken() async => await _messaging.getToken();
  void dispose() {
    _dataMessageController.close();
  }
}
