@echo off
cls
pushd %~dp0
cd ..\..

SET LUA=luas\lua51\lua.exe

REM %LUA% tsukuyomi\tests\run_all_tests.lua
%LUA% tsukuyomi\tests\run_all_tests.lua > tsukuyomi\tests\test_output.log

popd
