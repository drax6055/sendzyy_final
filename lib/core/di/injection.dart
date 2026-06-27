import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
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
import '../constants/app_constants.dart';

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

    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );
    return dio;
  });

  // Repository
  getIt.registerLazySingleton(
    () => WhatsAppRepository(getIt(), getIt()),
  );
  getIt.registerLazySingleton(
    () => ClientRepository(getIt()),
  );
  getIt.registerLazySingleton(
    () => ChatbotRepository(getIt()),
  );
  getIt.registerLazySingleton(() => GroupRepository(getIt()));
  getIt.registerLazySingleton(() => RetryRepository(getIt()));

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
}
