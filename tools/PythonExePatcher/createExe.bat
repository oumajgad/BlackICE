del /q zDsafe_ExePatcher.exe
pyinstaller --noconfirm --onefile --console --name "zDsafe_ExePatcher" "ExePatcher.py"
copy /b dist\zDsafe_ExePatcher.exe zDsafe_ExePatcher.exe
del /q zDsafe_ExePatcher.spec
rmdir /s /q build
rmdir /s /q dist