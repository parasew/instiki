#!/bin/sh

hdiutil create -size 12m -fs HFS+ -volname Instiki -ov /tmp/Instiki_12MB.dmg
hdiutil mount /tmp/Instiki_12MB.dmg
# strip ~/ruby/instiki/natives/osx/build/Instiki.app/Contents/MacOS/Instiki
ditto ~/ruby/instiki/natives/osx/desktop_launcher/build/Instiki.app /Volumes/Instiki/Instiki.app
hdiutil unmount /Volumes/Instiki
hdiutil convert -format UDZO -o /tmp/Instiki.dmg /tmp/Instiki_12MB.dmg
hdiutil internet-enable -yes /tmp/Instiki.dmg
