import 'scenes.dart';

/// UI text in Vietnamese (the default) and English.
///
/// Write the English text in the code and wrap it in [tr]; this file holds the
/// Vietnamese for each one. A text with no Vietnamese entry falls back to
/// English. {0}, {1} … are filled from [args].
String _lang = 'vi';

/// Languages offered in Settings: code → name shown.
const kLanguages = {'vi': 'Tiếng Việt', 'en': 'English'};

String get currentLanguage => _lang;

void setLanguage(String code) => _lang = kLanguages.containsKey(code) ? code : 'vi';

bool get isVietnamese => _lang == 'vi';

String tr(String en, [List<Object> args = const []]) {
  var s = _lang == 'vi' ? (_vi[en] ?? en) : en;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// A scene's name in the current language, and its name in the other one.
String sceneName(SceneDef s) => isVietnamese ? s.vn : s.name;
String sceneOtherName(SceneDef s) => isVietnamese ? s.name : s.vn;

const _vi = <String, String>{
  // Settings panel
  'Settings': 'Cài đặt',
  'Close (Esc)': 'Đóng (Esc)',
  'Language': 'Ngôn ngữ',
  'View': 'Khung cảnh',
  'Open in new window': 'Mở trong cửa sổ mới',
  '+\nMore views\ncoming soon': '+\nSắp có thêm\nkhung cảnh',
  'Background': 'Nền',
  'Transparent background': 'Nền trong suốt',
  'Show only the tree and its animation on your desktop': 'Chỉ hiện cây và hiệu ứng trên màn hình nền',
  'Size & crop': 'Kích thước & cắt khung',
  'Widget': 'Tiện ích',
  'Portrait': 'Dọc',
  'Square': 'Vuông',
  'Landscape': 'Ngang',
  'Wide': 'Rộng',
  'W': 'R',
  'H': 'C',
  'Apply': 'Áp dụng',
  'Zoom': 'Thu phóng',
  'Move scene up / down': 'Dịch khung cảnh lên / xuống',
  'Centre': 'Giữa',
  'Reset framing': 'Đặt lại khung hình',
  'Motion': 'Chuyển động',
  'Petals': 'Cánh hoa',
  'Snow': 'Tuyết',
  'Wind': 'Gió',
  'Calm': 'Lặng gió',
  'Animation speed': 'Tốc độ hiệu ứng',
  'Tree sways in the wind': 'Cây đung đưa theo gió',
  'Petals settle on the ground': 'Cánh hoa đọng lại trên mặt đất',
  'Foreground depth blur': 'Làm mờ tiền cảnh',
  'Large soft petals close to the camera': 'Cánh hoa lớn, mờ nhẹ ở gần ống kính',
  'Window': 'Cửa sổ',
  'Lock (click-through)': 'Khoá (bấm xuyên qua)',
  'Clicks go to the apps behind. Unlock: {0}, or hover the top-right corner':
      'Bấm chuột sẽ đi tới ứng dụng phía sau. Mở khoá: {0}, hoặc giữ chuột ở góc trên bên phải',
  'Always on top': 'Luôn ở trên cùng',
  'Launch at login': 'Tự mở khi đăng nhập máy',
  'Open automatically when you sign in': 'Tự mở khi bạn đăng nhập vào máy tính',
  'Show FPS': 'Hiện FPS',
  'Open current view in new window': 'Mở khung cảnh này trong cửa sổ mới',
  'Shortcuts: 1 2 3 switch view · T transparent background · L lock · , settings · N new window · Esc close.':
      'Phím tắt: 1 2 3 đổi khung cảnh · T nền trong suốt · L khoá · , cài đặt · N cửa sổ mới · Esc đóng.',
  'Right-click the scene to open settings. Drag anywhere to move the window.':
      'Bấm chuột phải vào khung cảnh để mở cài đặt. Kéo ở bất kỳ đâu để di chuyển cửa sổ.',
  'Your settings, window position and open windows are saved and restored automatically.':
      'Cài đặt, vị trí cửa sổ và các cửa sổ đang mở được tự động lưu và khôi phục.',
  'Build {0}': 'Bản dựng {0}',

  // Title bar
  'Close': 'Đóng',
  'Minimise': 'Thu nhỏ',
  'Maximise': 'Phóng to',
  'Lock — clicks go to the apps behind (L)': 'Khoá — bấm chuột đi tới ứng dụng phía sau (L)',
  'Transparent background (T)': 'Nền trong suốt (T)',
  'Open this view in a new window (N)': 'Mở khung cảnh này trong cửa sổ mới (N)',
  'Settings (,)': 'Cài đặt (,)',

  // Messages
  'Opened “{0}” in a new window': 'Đã mở “{0}” trong cửa sổ mới',
  'Could not open a new window': 'Không mở được cửa sổ mới',
  'Transparent background — only the tree and its animation': 'Nền trong suốt — chỉ hiện cây và hiệu ứng',
  'Scene background on': 'Đã bật nền khung cảnh',
  'Could not change launch at login': 'Không đổi được chế độ tự mở khi đăng nhập',
  'Locked — clicks go to the apps behind. Unlock: {0} or hover the top-right corner':
      'Đã khoá — bấm chuột đi tới ứng dụng phía sau. Mở khoá: {0} hoặc giữ chuột ở góc trên bên phải',
  'Unlocked': 'Đã mở khoá',
  'Unlock': 'Mở khoá',
  'View cropped to {0} × {1}': 'Đã cắt khung còn {0} × {1}',
};
