set shell := ["cmd.exe", "/c"]

diff symbol:
    cd tools/diff && dart run bin/diff.dart {{symbol}}

dump symbol:
    cd tools/dump && dart run bin/dump.dart {{symbol}}

sandbox:
    cd sandbox && dart run watcher/bin/watcher.dart
