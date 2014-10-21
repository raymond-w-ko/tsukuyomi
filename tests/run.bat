@echo off
cls
pushd %~dp0
cd ..\..

SET LUAJIT=luas\luajit\luajit.exe

%LUAJIT% tsukuyomi\thirdparty\bcname.lua 50 51 70 72

REM %LUAJIT% tsukuyomi\tests\run_all_tests.lua
%LUAJIT% tsukuyomi\tests\run_all_tests.lua > tsukuyomi\tests\test_output.log
popd
