version=-$1
APP=build/macos/Build/Products/Release/explain_general.app
if [ ! -d "$APP" ]; then
    flutter build macos --release
fi
mv $APP ./SparkAIr.app
zip -r explain_general-macos-amr64-$version.zip SparkAIr.app
rm -rf SparkAIr.app