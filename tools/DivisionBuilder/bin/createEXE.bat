del /q DivisionBuilder.exe
pyinstaller --noconfirm --onefile --console --name "DivisionBuilder" "../main.py"
copy /b dist/DivisionBuilder.exe DivisionBuilder.exe
del /q DivisionBuilder.spec
rmdir /s /q build
rmdir /s /q dist