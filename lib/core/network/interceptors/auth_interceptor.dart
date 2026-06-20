import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthInterceptor extends Interceptor {
  final GoogleSignIn _googleSignIn;

  AuthInterceptor(this._googleSignIn);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final account = _googleSignIn.currentUser;
    if (account != null) {
      try {
        final auth = await account.authentication;
        if (auth.accessToken != null) {
          options.headers['Authorization'] = 'Bearer ${auth.accessToken}';
        }
      } catch (_) {
        // Proceed without auth header — caller handles 401
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
