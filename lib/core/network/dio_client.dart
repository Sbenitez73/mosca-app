import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'interceptors/auth_interceptor.dart';

class DioClient {
  late final Dio dio;

  DioClient(GoogleSignIn googleSignIn) {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(googleSignIn),
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    ]);
  }
}
