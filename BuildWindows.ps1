
flutter build windows --release

$APP="build\windows\x64\runner\Release\"
$DEST="explain_general"
# 移动文件
Move-Item -Path $APP -Destination $DEST -Force
# 压缩文件
Compress-Archive -Update -Path $DEST -DestinationPath "$DEST-windows-x64.zip"
# 移除
Remove-Item -Path $DEST -Recurse -Force
