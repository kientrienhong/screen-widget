#!/usr/bin/env bash
# Current Xcode versions only build for macOS 12.0+. Raises the app's deployment
# target and forces every plugin pod to 12.0 too (plugins still declare older
# minimums). Safe to run any number of times. Called by setup_macos.sh and
# before every compile by build_macos.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f macos/Podfile ] || exit 0
before=$(cat macos/Podfile macos/Runner.xcodeproj/project.pbxproj | md5)

sed -i '' -E "s/^platform :osx, '[0-9.]+'/platform :osx, '12.0'/" macos/Podfile
sed -i '' -E 's/MACOSX_DEPLOYMENT_TARGET = [0-9.]+;/MACOSX_DEPLOYMENT_TARGET = 12.0;/g' macos/Runner.xcodeproj/project.pbxproj
if ! grep -q "MACOSX_DEPLOYMENT_TARGET'] = '12.0'" macos/Podfile; then
  /usr/bin/python3 - <<'PY'
p = 'macos/Podfile'
s = open(p).read()
old = "    flutter_additional_macos_build_settings(target)\n"
new = old + ("    target.build_configurations.each do |config|\n"
             "      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'\n"
             "    end\n")
open(p, 'w').write(s.replace(old, new, 1))
PY
fi
after=$(cat macos/Podfile macos/Runner.xcodeproj/project.pbxproj | md5)
if [ "$before" != "$after" ] && [ -d macos/Pods ]; then
  echo "Deployment target changed — regenerating plugin projects (pod install)…"
  (cd macos && pod install)
fi
echo "macOS deployment target: 12.0"
