@echo off
cls
pushd %~dp0
cd ..\..

SET LUA=luas\luajit\luajit.exe

%LUA% tsukuyomi\thirdparty\bcname.lua 50 51 70 72

REM %LUA% tsukuyomi\tests\run_all_tests.lua
%LUA% tsukuyomi\tests\run_all_tests.lua > tsukuyomi\tests\test_output.log
popd
