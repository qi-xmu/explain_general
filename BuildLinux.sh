#! /bin/bash
version=-$1
APP=build/linux/x64/release/bundle

flutter build linux --release

mv $APP explain_general
zip -r explain_general-linux-x64$version.zip explain_general
rm -rf explain_general