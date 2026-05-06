/// Shared copy for guest / anonymous UX (Profile, History, Home, round cloud gate).
abstract final class GuestPromotionCopy {
  static const title = "You're playing as a guest";
  static const subtitle =
      'Rounds can sync to this browser profile. Add email and a password to keep the same player identity across devices and unlock People.';

  static const upgradeCta = 'Upgrade guest account';

  static const createInsteadCta = 'Create a separate new account instead';

  /// One-line strip (e.g. dashboard).
  static const syncShortLine = 'Upgrade your guest account to sync history across devices.';

  /// History tab card (before upgrade CTA).
  static const historyBody =
      'Your rounds stay on this guest profile. Upgrade to keep them if you switch browser or device.';
}
