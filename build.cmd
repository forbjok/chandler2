@echo off
dub build -b release
choco pack "chocolatey\package.nuspec"
