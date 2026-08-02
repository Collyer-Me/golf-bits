import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/auth/auth_redirect.dart';

void main() {
  test('native auth redirect constant is the golfbits scheme', () {
    expect(kNativeAuthRedirectUrl, 'golfbits://auth-callback');
  });
}
