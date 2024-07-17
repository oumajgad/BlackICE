del /q memBICE.exe
pyinstaller --noconfirm --noconsole --onefile --console --name "memBICE" "main.py"
copy /b dist\memBICE.exe memBICE.exe
del /q memBICE.spec
rmdir /s /q build
rmdir /s /q dist