This is a DLL which enables borderless windowed mode, aswell as providing the option to stretch that window with a correct cursor position. 
Hoi3 uses its own method of figuring out where the mouse is pointed, so simply changing the window size is not enough.

Almost all code is from: https://github.com/horsenit/v2winfix. Only the "strechted with fixed cursor position" is by me.


### How to use.

1. Simply drop the "dinput8.dll" into your main Hoi3 folder. (The folder with the "Hoi3_tfh.exe")
1. Start the game once.
1. Now there should be a file at "C:\Users\YOUR USERNAME\Documents\Paradox Interactive\v2winfix.ini" which you can edit
1. To get borderless you simply set borderless to "1" and set "fullScreen=no" in your Hoi3 "settings.txt" (located for example at "C:\Users\YOUR USERNAME\Documents\Paradox Interactive\Hearts of Iron III\BlackICE 12.1.1")

#### Stretched window with fixed cursor
If you want to play in windowed mode but your monitor resolution is larger than 1080p the game UI will not look right, and using a tool like "winexplorer" (https://www.nirsoft.net/utils/winexp.html) to edit the window size will cause the mouse cursor to be offset ingame.

Instead use the settings in the "dsafe" category of the v2winfix.ini. "original" X and Y should be the same as in your Hoi3 settings, "stretched" should be the actual resolution of your monitor.

Example:
```
[v2winfix]
borderless=1
[dsafe]
original_X=1920
original_Y=1080
stretched_X=2560
stretched_Y=1440
```

Now the game window will fill your screen once you reach the main menu. The resolution will still be the original value so things might look a bit blurry.
