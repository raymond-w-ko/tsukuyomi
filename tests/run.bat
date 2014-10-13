@echo off
cls
pushd %~dp0
cd ..\..

luajit-2.0\src\luajit.exe tsukuyomi\thirdparty\bcname.lua 50 51 70 72

REM luajit-2.0\src\luajit.exe tsukuyomi\tests\run_all_tests.lua
luajit-2.0\src\luajit.exe tsukuyomi\tests\run_all_tests.lua > tsukuyomi\tests\test_output.log
popd
