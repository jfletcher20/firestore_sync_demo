import '../services/fcm_messaging_service.dart';
import '../services/api_service.dart';
import '../services/local_database_service.dart';
import '../services/fallback_queue_service.dart';
import '../controllers/sync_controller.dart';

class AppDependencies {
  static final AppDependencies _instance = AppDependencies._internal();
  factory AppDependencies() => _instance;
  AppDependencies._internal();

  // Services
  late final FcmMessagingService fcmService;
  late final ApiService apiService;
  late final LocalDatabaseService localDatabaseService;
  late final FallbackQueueService fallbackQueueService;

  // Controllers
  late final SyncController syncController;

  /// Initialize all dependencies
  Future<void> initialize() async {
    // Initialize services
    fcmService = FcmMessagingService();
    apiService = ApiService();
    localDatabaseService = LocalDatabaseService();
    fallbackQueueService = FallbackQueueService();
    syncController = SyncController();

    await localDatabaseService.initialize();
    await fcmService.initialize();
    await fallbackQueueService.initialize();
    await syncController.initialize();
  }

  /// Dispose all dependencies
  void dispose() {
    syncController.dispose();
    fcmService.dispose();
    fallbackQueueService.dispose();
    localDatabaseService.dispose();
  }
}
