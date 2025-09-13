import '../services/fcm_messaging_service.dart';
import '../services/api_service.dart';
import '../services/local_database_service.dart';
import '../services/fallback_queue_service.dart';
import '../controllers/sync_controller.dart';

class AppDependencies {
  static final AppDependencies _instance = AppDependencies._internal();
  factory AppDependencies() => _instance;
  AppDependencies._internal();

  late final FcmMessagingService fcmService;
  late final ApiService apiService;
  late final LocalDatabaseService localDatabaseService;
  late final FallbackQueueService fallbackQueueService;

  late final SyncController syncController;

  Future<void> initialize() async {
    fcmService = FcmMessagingService();
    apiService = ApiService();
    localDatabaseService = LocalDatabaseService();
    fallbackQueueService = FallbackQueueService();
    syncController = SyncController();

    await fcmService.initialize();
    await localDatabaseService.initialize(syncBetweenServer: true);
    await fallbackQueueService.initialize();
    await syncController.initialize();
  }

  void dispose() {
    syncController.dispose();
    fcmService.dispose();
    fallbackQueueService.dispose();
    localDatabaseService.dispose();
  }
}
