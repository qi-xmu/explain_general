#! /bin/zsh
version=-$1
APP=build/macos/Build/Products/Release/explain_general.app

flutter build macos --release

mv $APP ./SparkAI.app
zip -r explain_general-macos-amr64$version.zip SparkAI.app
rm -rf SparkAI.app