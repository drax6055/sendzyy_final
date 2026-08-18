import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:iFloraBuzz/features/chat/data/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iFloraBuzz/core/services/encryption_service.dart';
import 'package:iFloraBuzz/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:iFloraBuzz/features/templates/presentation/bloc/template_bloc.dart';
import 'package:iFloraBuzz/features/messages/presentation/bloc/message_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/whatsapp_repository.dart';
import 'package:iFloraBuzz/features/reports/presentation/bloc/report_bloc.dart';
import 'package:iFloraBuzz/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/client_repository.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/client_bloc.dart';
import 'package:iFloraBuzz/features/chatbot/data/repositories/chatbot_repository.dart';
import 'package:iFloraBuzz/features/chatbot/presentation/bloc/chatbot_bloc.dart';
import 'package:iFloraBuzz/features/clients/data/repositories/group_repository.dart';
import 'package:iFloraBuzz/features/clients/presentation/bloc/group_bloc.dart';
import 'package:iFloraBuzz/features/whatsapp/data/repositories/retry_repository.dart';
import 'package:iFloraBuzz/features/catalog/data/repositories/catalog_repository.dart';
import 'package:iFloraBuzz/features/catalog/presentation/bloc/catalog_bloc.dart';
import '../constants/app_constants.dart';

import 'package:iFloraBuzz/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:iFloraBuzz/features/notifications/data/repositories/notification_repository.dart';
import 'package:iFloraBuzz/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:iFloraBuzz/core/services/calling_webrtc_service.dart';
import 'package:iFloraBuzz/features/calling/data/repositories/calling_repository.dart';
import 'package:iFloraBuzz/features/calling/data/repositories/calling_repository_impl.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_control_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_permission_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_settings_bloc.dart';
import 'package:iFloraBuzz/features/calling/presentation/bloc/call_log_bloc.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  // Shared Preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton(() => sharedPreferences);

  // Dio
  getIt.registerLazySingleton(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Auth Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = sharedPreferences.getString('auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
    return dio;
  });

  // Repository
  getIt.registerLazySingleton(() => WhatsAppRepository(getIt(), getIt()));
  getIt.registerLazySingleton(() => ClientRepository(getIt()));
  getIt.registerLazySingleton(() => ChatbotRepository(getIt()));
  getIt.registerLazySingleton(() => GroupRepository(getIt()));
  getIt.registerLazySingleton(() => RetryRepository(getIt()));

  // Notifications Data Layer
  getIt.registerLazySingleton(() => NotificationRemoteDataSource(dio: getIt()));
  getIt.registerLazySingleton(
    () => NotificationRepository(remoteDataSource: getIt()),
  );

  // Services
  getIt.registerLazySingleton(() => EncryptionService());
  getIt.registerLazySingleton(() => SocketService());

  // Features - Auth
  getIt.registerFactory(() => AuthBloc(getIt(), getIt(), getIt()));

  // Features - Templates
  getIt.registerFactory(() => TemplateBloc(getIt()));

  // Features - Messages
  getIt.registerFactory(() => MessageBloc(getIt()));

  // Features - Reports
  getIt.registerFactory(() => ReportBloc(getIt(), getIt()));

  // Features - Chat
  getIt.registerFactory(() => ChatBloc(getIt(), getIt()));

  // Features - Clients
  getIt.registerFactory(() => ClientsBloc(getIt()));

  // Features - Chatbot
  getIt.registerFactory(() => ChatbotBloc(getIt()));

  // Features - Groups
  getIt.registerFactory(() => GroupsBloc(getIt()));

  // Features - Notifications
  getIt.registerFactory(() => NotificationBloc(repository: getIt()));

  // Features - Calling
  getIt.registerLazySingleton<CallingRepository>(
    () => CallingRepositoryImpl(getIt(), getIt()),
  );
  getIt.registerFactory<CallingWebRTCService>(
    () => CallingWebRTCService.create(),
  );
  getIt.registerLazySingleton(
    () => CallControlBloc(repository: getIt(), webrtcService: getIt()),
  );
  getIt.registerFactory(
    () => CallPermissionBloc(getIt()),
  );
  getIt.registerFactory(
    () => CallSettingsBloc(getIt()),
  );
  getIt.registerLazySingleton(
    () => CallLogBloc(),
  );
  // Features - Catalog
  getIt.registerLazySingleton(() => CatalogRepository(getIt()));
  getIt.registerFactory(() => CatalogBloc(getIt()));
}
