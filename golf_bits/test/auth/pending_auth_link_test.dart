import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/auth/pending_auth_link.dart';

void main() {
  test('captures recovery type from query', () {
    PendingAuthLink.captureFromUriBeforeSupabaseInit(
      Uri.parse('golfbits://auth-callback?type=recovery'),
    );
    expect(PendingAuthLink.takePasswordRecovery(), isTrue);
    expect(PendingAuthLink.takePasswordRecovery(), isFalse);
  });

  test('captures signup type from fragment', () {
    PendingAuthLink.captureFromUriBeforeSupabaseInit(
      Uri.parse('golfbits://auth-callback#type=signup&access_token=x'),
    );
    expect(PendingAuthLink.takeEmailSignupConfirmed(), isTrue);
  });

  test('captures invite token and email', () {
    PendingAuthLink.captureFromUriBeforeSupabaseInit(
      Uri.parse(
        'golfbits://auth-callback?invite_token=abc&invite_email=a%40b.com',
      ),
    );
    expect(PendingAuthLink.takeRoundInviteToken(), 'abc');
    expect(PendingAuthLink.inviteEmail, 'a@b.com');
  });
}
