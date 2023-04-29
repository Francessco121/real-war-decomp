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

# split base exe
@split:
    tools/rw_decomp/build/split.exe

# recreate build.ninja
@configure:
    tools/rw_decomp/build/configure.exe

# compile a single source file (name should not have an extension)
cl name:
    ninja build\obj\{{name}}.obj

# build new exe
@build:
    ninja

# clean + build
@rebuild:
    just clean
    just configure
    ninja

# verify that the linked exe matches the original base exe
@verify:
    tools/rw_decomp/build/verify.exe

# verify that the base exe is valid
@verifybase:
    tools/rw_decomp/build/verify.exe base

# build + verify
@check:
    ninja
    tools/rw_decomp/build/verify.exe

# clean build artifacts (excluding tools)
@clean:
    if (Test-Path build -PathType Container) { Remove-Item build -Force -Recurse }
    if (Test-Path build.ninja -PathType Leaf) { Remove-Item build.ninja -Force -Recurse }
    if (Test-Path .ninja_log -PathType Leaf) { Remove-Item .ninja_log -Force -Recurse }
    if (Test-Path .ninja_deps -PathType Leaf) { Remove-Item .ninja_deps -Force -Recurse }

# clean build and split artifacts (excluding tools)
@clean-full:
    if (Test-Path asm -PathType Container) { Remove-Item asm -Force -Recurse }
    if (Test-Path bin -PathType Container) { Remove-Item bin -Force -Recurse }
    just clean

# start a file watcher for the sandbox
@sandbox:
    cd sandbox && dart run watcher/bin/watcher.dart

# precompile tools
build-tools:
    just build-tool-diff
    just build-tool-cl-wrapper
    just build-tool-configure
    just build-tool-link
    just build-tool-verify
    just build-tool-split
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

@build-tool-split:
    New-Item -ItemType Directory -Force -Path tools\rw_decomp\build | Out-Null
    dart compile exe -o tools/rw_decomp/build/split.exe tools/rw_decomp/bin/split.dart

@build-tool-dump:
    New-Item -ItemType Directory -Force -Path tools\rw_decomp\build | Out-Null
    dart compile exe -o tools/rw_decomp/build/dump.exe tools/rw_decomp/bin/dump.dart
