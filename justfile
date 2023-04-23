set shell := ["cmd.exe", "/c"]

diff symbol:
    cd tools/diff && dart run bin/diff.dart {{symbol}}

sandbox:
    cd sandbox && dart run watcher/bin/watcher.dart
