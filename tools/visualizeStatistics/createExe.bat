del /q visualizeStatistic.exe
pyinstaller --noconfirm --onefile --console --name "visualizeStatistic" "visualizeStatistic.py"
copy /b dist\visualizeStatistic.exe visualizeStatistic.exe
rmdir /s /q build
rmdir /s /q dist
del /q visualizeStatistic.spec
