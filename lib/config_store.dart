import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Where each window's configuration is saved. Every window is its own
/// process, so each one gets its own file and they never overwrite each other.
///
///   <config dir>/main.json           the main window
///   <config dir>/popouts/<id>.json   each "Open in new window" window
///   <config dir>/popouts/<id>.lock   held by that window while it runs
///
/// Config dir: %APPDATA%\ScreenWidget on Windows,
/// ~/Library/Application Support/ScreenWidget on macOS.
class ConfigStore {
  ConfigStore._(this.file);

  final File file;
  RandomAccessFile? _lock;

  static Directory get dir {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final base = env['APPDATA'] ?? env['LOCALAPPDATA'] ?? Directory.systemTemp.path;
      return Directory('$base${Platform.pathSeparator}ScreenWidget');
    }
    final home = env['HOME'] ?? Directory.systemTemp.path;
    if (Platform.isMacOS) return Directory('$home/Library/Application Support/ScreenWidget');
    return Directory('$home/.screen_widget');
  }

  static Directory get _popoutDir => Directory('${dir.path}${Platform.pathSeparator}popouts');

  static ConfigStore forMain() => ConfigStore._(File('${dir.path}${Platform.pathSeparator}main.json'));

  static ConfigStore forPopout(String id) => ConfigStore._(File('${_popoutDir.path}${Platform.pathSeparator}$id.json'));

  /// A new id for a pop-out window.
  static String newPopoutId() {
    final r = math.Random().nextInt(1 << 30).toRadixString(36);
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$r';
  }

  /// Ids of the pop-out windows that were open last time (closed ones are deleted).
  static List<String> savedPopoutIds() {
    try {
      return _popoutDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.json'))
          .map((n) => n.substring(0, n.length - '.json'.length))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  File get _lockFile => File(file.path.replaceFirst(RegExp(r'\.json$'), '.lock'));

  /// Marks this window as running. Returns false if another process already
  /// runs the same window (so it must not open a second copy).
  bool hold() {
    try {
      _lockFile.parent.createSync(recursive: true);
      final raf = _lockFile.openSync(mode: FileMode.append); // append: never truncates a file another window has locked
      try {
        raf.lockSync(FileLock.exclusive);
      } catch (_) {
        raf.closeSync();
        return false;
      }
      _lock = raf;
      return true;
    } catch (_) {
      return true; // can't tell; better to open than to lose the window
    }
  }

  /// True if the pop-out with this id is open right now.
  static bool isPopoutRunning(String id) {
    final store = forPopout(id);
    if (!store.hold()) return true;
    store._release();
    return false;
  }

  void _release() {
    try {
      _lock?.unlockSync();
      _lock?.closeSync();
    } catch (_) {}
    _lock = null;
  }

  Map<String, dynamic>? read() {
    try {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null; // missing or corrupt: caller uses defaults
    }
  }

  /// Writes through a temp file, so a crash mid-write never leaves a broken file.
  void write(Map<String, dynamic> data) {
    try {
      file.parent.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(data), flush: true);
      try {
        tmp.renameSync(file.path);
      } catch (_) {
        file.writeAsStringSync(jsonEncode(data), flush: true);
        tmp.deleteSync();
      }
    } catch (_) {
      // Saving is best-effort; the app keeps working with what's in memory.
    }
  }

  /// Forget this window (the user closed a pop-out on purpose).
  void delete() {
    _release();
    for (final f in [file, _lockFile]) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }
}
