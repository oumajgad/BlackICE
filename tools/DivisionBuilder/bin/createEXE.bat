rmdir /s /q build
rmdir /s /q dist
del /q DivisionBuilder.spec
del /q DivisionBuilder.exe
pyinstaller --noconfirm --onefile --console --name "DivisionBuilder" "../main.py"
copy /b dist/DivisionBuilder.exe DivisionBuilder.exe
