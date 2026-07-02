/// Build metadata injected at CI compile time.
abstract final class AppBuildInfo {
  static const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0-beta.1');
  static const buildSha = String.fromEnvironment('BUILD_SHA', defaultValue: 'dev');

  static String get versionLabel => version;
  static String get shortSha => buildSha.length > 7 ? buildSha.substring(0, 7) : buildSha;
  static String get displayLabel => 'v$version ($shortSha)';
}
