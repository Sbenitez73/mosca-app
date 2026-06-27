import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/config/app_secrets.dart';

const _gmailBase = 'https://gmail.googleapis.com/gmail/v1/users/me';

// Bank sender domains. The parser does the fine-grained classification.
// Gmail's from: operator matches exact domain, not subdomains.
// Bancolombia sends from at least two distinct domains.
const _bankFroms =
    '({from:bancolombia.com from:notificacionesbancolombia.com '
    'from:an.notificacionesbancolombia.com '
    'from:nequi.com.co from:davivienda.com from:bbva.com.co '
    'from:nubank.com.br from:nu.com.co from:falabella.com})';

class GmailClient {
  final Dio _dio;
  final GoogleSignIn _googleSignIn;

  GmailClient(this._dio)
      : _googleSignIn = GoogleSignIn(
          scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
          serverClientId: AppSecrets.googleServerClientId,
        );

  GoogleSignIn get googleSignIn => _googleSignIn;

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();
  Future<void> signOut() => _googleSignIn.signOut();
  Future<bool> get isSignedIn => _googleSignIn.isSignedIn();
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<List<String>> fetchTransactionMessageIds({
    int maxResults = 200,
    DateTime? since,
  }) async {
    final dateFilter = since != null
        // Gmail's after: operator takes Unix seconds
        ? 'after:${since.millisecondsSinceEpoch ~/ 1000}'
        // First-ever sync: backfill last 30 days
        : 'newer_than:30d';
    final query = '$dateFilter $_bankFroms';

    final auth = await _requireAuth();
    final response = await _dio.get(
      '$_gmailBase/messages',
      queryParameters: {'q': query, 'maxResults': maxResults},
      options: Options(headers: {'Authorization': 'Bearer $auth'}),
    );
    final messages = List<Map<String, dynamic>>.from(
      response.data['messages'] as List? ?? [],
    );
    return messages.map((m) => m['id'] as String).toList();
  }

  Future<Map<String, dynamic>> fetchMessage(String messageId) async {
    final auth = await _requireAuth();
    final response = await _dio.get(
      '$_gmailBase/messages/$messageId',
      queryParameters: {'format': 'full'},
      options: Options(headers: {'Authorization': 'Bearer $auth'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> _requireAuth() async {
    // currentUser is null after a cold start even when previously authenticated.
    // signInSilently() restores the session from the keychain with no UI shown.
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (account == null) throw Exception('Gmail not signed in');
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null) throw Exception('Failed to get access token');
    return token;
  }
}
