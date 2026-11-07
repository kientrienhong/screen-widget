/// Which build this is: the git commit it was built from (set by the build
/// scripts and the GitHub workflow with --dart-define=BUILD_ID=...).
/// "dev" means a plain `flutter run`; a trailing "+" means uncommitted changes.
const kBuildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');
