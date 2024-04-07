set shell := ["powershell.exe", "-c"]

# list justfile recipes
@help:
    just --list -u

# live diff between a recompiled function and its original assembly
@diff symbol:
    tools/rw_diff/build/diff.exe {{symbol}}

# dump function assembly to file
@dump symbol:
    tools/rw_decomp/build/dump.exe {{symbol}}

# find the archive files that define the given symbols
@libsearch libfile +symbols:
    dart run tools/rw_decomp/bin/lib_search.dart {{libfile}} {{symbols}}

# work with the rw.yaml file
@rwyaml *args:
    dart run tools/rw_decomp/bin/rwyaml.dart {{args}}

# calculate decomp progress
@progress *args:
    dart run tools/rw_decomp/bin/progress.dart {{args}}

# recreate build.ninja
@configure:
    tools/rw_decomp/build/configure.exe

# compile a single source file (name should not have an extension)
cl name:
    ninja build\obj\{{name}}.obj

# build new exe
[no-exit-message]
@build:
    ninja

# clean + build
[no-exit-message]
@rebuild:
    just clean
    just configure
    ninja

# verify decomp accuracy
[no-exit-message]
@verify *args:
    tools/rw_decomp/build/verify.exe {{args}}

# verify that the base exe is valid
[no-exit-message]
@verifybase:
    dart run tools/rw_decomp/bin/md5.dart base

# build + verify
[no-exit-message]
@check:
    ninja
    tools/rw_decomp/build/verify.exe

# clean build artifacts (excluding tools)
@clean:
    if (Test-Path build -PathType Container) { Remove-Item build -Force -Recurse }
    if (Test-Path build.ninja -PathType Leaf) { Remove-Item build.ninja -Force }
    if (Test-Path .ninja_log -PathType Leaf) { Remove-Item .ninja_log -Force }
    if (Test-Path .ninja_deps -PathType Leaf) { Remove-Item .ninja_deps -Force }

# start a file watcher for the sandbox
@sandbox:
    cd sandbox; dart run ../tools/rw_sandbox_watcher/bin/watcher.dart

# precompile tools
build-tools:
    just build-tool-diff
    just build-tool-cl-wrapper
    just build-tool-configure
    just build-tool-link
    just build-tool-verify
    just build-tool-dump

@build-tool-diff:
    New-Item -ItemType Directory -Force -Path tools\rw_diff\build | Out-Null
    dart compile exe -o tools/rw_diff/build/diff.exe tools/rw_diff/bin/diff.dart

@build-tool-cl-wrapper:
    New-Item -ItemType Directory -Force -Path tools\rw_decomp\build | Out-Null
    dart compile exe -o tools/rw_decomp/build/cl_wrapper.exe tools/rw_decomp/bin/cl_wrapper.dart

@build-tool-configure:
    New-Item -ItemType Directory -Force -Path tools\rw_decomp\build | Out-Null
    dart compile exe -o tools/rw_decomp/build/configure.exe tools/rw_decomp/bin/configure.dart

@build-tool-link:
    New-Item -ItemType Directory -Force -Path tools\rw_decomp\build | Out-Null
    dart compile exe -o tools/rw_decomp/build/link.exe tools/rw_decomp/bin/link.dart

@build-tool-verify:
    New-Item -ItemType Directory -Force -Path tools\rw_decomp\build | Out-Null
    dart compile exe -o tools/rw_decomp/build/verify.exe tools/rw_decomp/bin/verify.dart

@build-tool-dump:
    New-Item -ItemType Directory -Force -Path tools\rw_decomp\build | Out-Null
    dart compile exe -o tools/rw_decomp/build/dump.exe tools/rw_decomp/bin/dump.dart
