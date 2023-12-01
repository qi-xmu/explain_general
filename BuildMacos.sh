#! /bin/zsh
version=-$1
APP=build/macos/Build/Products/Release/explain_general.app
if [ ! -d "$APP" ]; then
    flutter build macos --release
fi
mv $APP ./SparkAI.app
zip -r explain_general-macos-amr64-$version.zip SparkAI.app
rm -rf SparkAI.app