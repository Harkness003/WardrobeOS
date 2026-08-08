import 'package:google_sign_in/google_sign_in.dart';

import 'google_calendar_auth_store.dart';

abstract interface class GoogleCalendarAuthenticator {
  Future<GoogleCalendarConnection?> authenticate({bool interactive = true});
  Future<void> disconnect();
}

class GoogleSignInCalendarAuthenticator implements GoogleCalendarAuthenticator {
  static const calendarReadonlyScope =
      'https://www.googleapis.com/auth/calendar.readonly';
  final GoogleSignIn _googleSignIn;

  GoogleSignInCalendarAuthenticator({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(scopes: const [calendarReadonlyScope]);

  @override
  Future<GoogleCalendarConnection?> authenticate({bool interactive = true}) async {
    final account = await _googleSignIn.signInSilently() ??
        (interactive ? await _googleSignIn.signIn() : null);
    if (account == null) return null;
    final token = (await account.authentication).accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('calendarAccessTokenUnavailable');
    }
    return GoogleCalendarConnection(
      accountEmail: account.email,
      accessToken: token,
      connectedAt: DateTime.now(),
      calendarReadGranted: true,
    );
  }

  @override
  Future<void> disconnect() => _googleSignIn.disconnect();
}
