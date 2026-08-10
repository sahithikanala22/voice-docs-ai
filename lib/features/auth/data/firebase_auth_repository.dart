import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:ai_voice_docs/core/constants/app_constants.dart';
import 'package:ai_voice_docs/core/errors/exceptions.dart';

import '../domain/auth_repository.dart';

/// Default [AuthRepository]: phone number + WhatsApp OTP. The OTP itself is
/// generated and verified by a small Node backend hosted on Vercel (see
/// `server/api/sendOtp.js` / `verifyOtp.js`), since sending a WhatsApp
/// message requires a secret Twilio token that must never ship inside the
/// app. A correct code gets a Firebase custom token back from that backend,
/// which this class exchanges for a real signed-in session via
/// `signInWithCustomToken`.
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final Dio _dio = Dio(BaseOptions(baseUrl: AppConstants.otpApiBaseUrl));

  AppUser? _toAppUser(fb.User? user) =>
      user == null ? null : AppUser(uid: user.uid, phoneNumber: user.phoneNumber);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> sendOtp(String phoneNumber) async {
    try {
      await _dio.post('/api/sendOtp', data: {'phoneNumber': phoneNumber});
    } on DioException catch (e) {
      throw AuthException(_serverMessage(e) ?? 'Could not send the code. Try again.');
    }
  }

  @override
  Future<void> verifyOtp({required String phoneNumber, required String code}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/verifyOtp',
        data: {'phoneNumber': phoneNumber, 'code': code},
      );
      final token = response.data?['token'] as String;
      await _auth.signInWithCustomToken(token);
    } on DioException catch (e) {
      throw AuthException(_serverMessage(e) ?? 'Incorrect code. Try again.');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// The server always responds with `{"error": "readable message"}` on
  /// failure (see server/lib) — surface that directly instead of a generic
  /// Dio exception string.
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return null;
  }
}
