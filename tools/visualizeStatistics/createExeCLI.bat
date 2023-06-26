del /q visualizeStatisticCLI.exe
pyinstaller --noconfirm --onefile --noconsole --name "visualizeStatisticCLI" "visualizeStatisticCLI.py"
copy /b dist\visualizeStatisticCLI.exe visualizeStatisticCLI.exe
rmdir /s /q build
rmdir /s /q dist
del /q visualizeStatisticCLI.spec
