if exist deploy\ (
rmdir /S /Q deploy
)
mkdir deploy
xcopy /C /Y *.exe deploy\
xcopy /C /Y resource\ deploy\resource\
windeployqt --dir deploy %1.exe
