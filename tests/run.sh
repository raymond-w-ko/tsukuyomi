#!/bin/bash
set -e

clear
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"
cd ../..
luajit tsukuyomi/tests/run_all_tests.lua
