@echo off
if not exist "build\obj" mkdir build\obj
cl /nologo /c /I "C:\Program Files (x86)\Microsoft Visual Studio\VC98\Include" /Fobuild\obj\test.obj /O1 sandbox\src\test.c
rem link /NOLOGO /LIBPATH:"C:\Program Files (x86)\Microsoft Visual Studio\VC98\Lib" /OUT:build\test.exe /MAP:build\test.map /NOENTRY build\obj\test.obj
rem link /NOLOGO /LIBPATH:"C:\Program Files (x86)\Microsoft Visual Studio\VC98\Lib" /OUT:build\main.exe /MAP:build\main.map /SUBSYSTEM:WINDOWS build\obj\main.obj USER32.LIB
