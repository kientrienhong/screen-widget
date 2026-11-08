import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Reads and writes values under HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
/// (programs Windows starts when you sign in) through the Windows API.
/// Running reg.exe instead can flash a console window. Windows only.
class WinRunKey {
  WinRunKey._();

  // HKEY_CURRENT_USER is (HKEY)(LONG)0x80000001, i.e. sign-extended on 64-bit.
  static const _hkcu = -0x7FFFFFFF;
  static const _path = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _regSz = 1; // REG_SZ
  static const _rrfRtRegSz = 0x00000002; // RRF_RT_REG_SZ
  static const _errorFileNotFound = 2;

  static final _advapi = DynamicLibrary.open('advapi32.dll');

  static final _regGetValue = _advapi.lookupFunction<
      Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Uint32, Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>),
      int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>)>('RegGetValueW');

  static final _regSetKeyValue = _advapi.lookupFunction<
      Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Uint32, Pointer<Void>, Uint32),
      int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Void>, int)>('RegSetKeyValueW');

  static final _regDeleteKeyValue = _advapi.lookupFunction<
      Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>),
      int Function(int, Pointer<Utf16>, Pointer<Utf16>)>('RegDeleteKeyValueW');

  /// True if a start-up entry called [name] exists.
  static bool has(String name) => using((a) {
        final size = a<Uint32>();
        final r = _regGetValue(_hkcu, _path.toNativeUtf16(allocator: a), name.toNativeUtf16(allocator: a),
            _rrfRtRegSz, nullptr, nullptr, size);
        return r == 0;
      });

  /// Creates or updates the start-up entry [name] with [command].
  static bool set(String name, String command) => using((a) {
        final data = command.toNativeUtf16(allocator: a);
        final bytes = (command.length + 1) * 2; // UTF-16 incl. the final 0
        return _regSetKeyValue(_hkcu, _path.toNativeUtf16(allocator: a), name.toNativeUtf16(allocator: a), _regSz,
                data.cast(), bytes) ==
            0;
      });

  /// Removes the start-up entry [name] (fine if it isn't there).
  static bool remove(String name) => using((a) {
        final r = _regDeleteKeyValue(_hkcu, _path.toNativeUtf16(allocator: a), name.toNativeUtf16(allocator: a));
        return r == 0 || r == _errorFileNotFound;
      });
}
