if not exist deploy\ (
mkdir deploy
)
xcopy /C /Y *.exe deploy\
xcopy /C /Y *.bmp deploy\
windeployqt --dir deploy %1.exe
