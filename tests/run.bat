@echo off
cls
pushd %~dp0
cd ..\..
luajit-2.0\src\luajit.exe tsukuyomi\tests\run_all_tests.lua
REM luajit-2.0\src\luajit.exe tsukuyomi\tests\run_all_tests.lua > tsukuyomi\tests\test_output.log
popd
