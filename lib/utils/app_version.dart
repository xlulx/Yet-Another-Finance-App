/// Set by the Release APK workflow (`--dart-define=APP_VERSION=1.2.3`);
/// "dev" for local and test builds.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
