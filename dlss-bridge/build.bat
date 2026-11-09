@echo off
rem Builds siris.dll and the probe with MSVC (Visual Studio 2022).
rem The project lives in a deep folder; MSVC cannot open headers past MAX_PATH, so the build runs
rem on a temporary drive letter (subst) that is removed again afterwards.
setlocal
rem An Arm64 JVM (Windows on Arm) cannot load an x64 DLL, so the bridge is built for the machine it is built on.
rem The machine's value comes from the registry: a shell under x64 emulation (Git Bash) reports AMD64 in its environment.
for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE') do set MACHINE_ARCH=%%A
set VCTOOLS=Microsoft.VisualStudio.Component.VC.Tools.x86.x64
set VCVARS=vcvars64.bat
if /i "%MACHINE_ARCH%"=="ARM64" set VCTOOLS=Microsoft.VisualStudio.Component.VC.Tools.ARM64
if /i "%MACHINE_ARCH%"=="ARM64" set VCVARS=vcvarsarm64.bat
for /f "usebackq delims=" %%I in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires %VCTOOLS% -property installationPath`) do set VSDIR=%%I
call "%VSDIR%\VC\Auxiliary\Build\%VCVARS%" >nul 2>nul
where cl >nul 2>nul || (echo MSVC not found & exit /b 1)

set DRIVE=
for %%D in (W V U T S R Q P) do if not defined DRIVE if not exist %%D:\ set DRIVE=%%D:
if not defined DRIVE (echo no free drive letter & exit /b 1)
subst %DRIVE% "%~dp0."
pushd %DRIVE%\
call :build
set RESULT=%ERRORLEVEL%
popd
subst %DRIVE% /d
exit /b %RESULT%

:build
if not exist out mkdir out
set JDK=%JAVA_HOME%
if not defined JDK (echo set JAVA_HOME to a JDK 25 & exit /b 1)
if not exist third_party\ngx\include (echo run fetch-deps.ps1 first & exit /b 1)
set INC=/I third_party\ngx\include /I third_party\vulkan-headers\include /I "%JDK%\include" /I "%JDK%\include\win32"
cl /nologo /std:c++17 /O2 /MD /EHsc /W3 /DUNICODE %INC% /LD src\bridge.cpp src\jni.cpp /Fo:out\ /Fe:out\siris.dll ^
   /link third_party\ngx\lib\nvsdk_ngx_d.lib user32.lib advapi32.lib || exit /b 1
cl /nologo /std:c++17 /O2 /MD /EHsc /W3 /DUNICODE /I third_party\vulkan-headers\include src\probe.cpp /Fo:out\ /Fe:out\dlss_probe.exe ^
   /link out\siris.lib user32.lib || exit /b 1
copy /y third_party\ngx\bin\nvngx_dlss.dll out\ >nul
copy /y third_party\ngx\bin\nvngx_dlssg.dll out\ >nul
echo BUILD OK
exit /b 0
