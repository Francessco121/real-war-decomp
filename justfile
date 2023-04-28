set shell := ["cmd.exe", "/c"]

diff symbol:
    cd tools/rw_diff && dart run bin/diff.dart {{symbol}}

dump symbol:
    cd tools/rw_decomp && dart run bin/dump.dart {{symbol}}

split:
    cd tools/rw_decomp && dart run bin/split.dart

link:
    cd tools/rw_decomp && dart run bin/link.dart

verify:
    cd tools/rw_decomp && dart run bin/verify.dart

verifybase:
    cd tools/rw_decomp && dart run bin/verify.dart base

sandbox:
    cd sandbox && dart run watcher/bin/watcher.dart
