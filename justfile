set shell := ["cmd.exe", "/c"]

diff symbol:
    cd tools/diff && dart run bin/diff.dart {{symbol}}

dump symbol:
    cd tools/dump && dart run bin/dump.dart {{symbol}}

split:
    cd tools/rw_split && dart run bin/rw_split.dart

link:
    cd tools/rw_build && dart run bin/link.dart

verify:
    cd tools/rw_build && dart run bin/verify.dart

baseverify:
    cd tools/rw_build && dart run bin/verify.dart base

sandbox:
    cd sandbox && dart run watcher/bin/watcher.dart
