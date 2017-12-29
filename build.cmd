@echo off

set /p VERSION=< VERSION

dub build --compiler=ldc2 --arch=x86 -b release
7z a -mx=9 chandler_v%VERSION%.zip chandler.exe LICENSE.md README.md
choco pack "chocolatey\package.nuspec"
