set formats=*.mp3
set presets=-vn -ar 44100 -ac 2 -ab 64k -vol 400 -f mp3
set outputext=mp3

for %%g in (%formats%) do start /b /wait "" "ffmpeg.exe" -y -i "%~dp0%%g" %presets% "%~dp0%%~ng-compressed.%outputext%" && TITLE "Converted: "%%g
