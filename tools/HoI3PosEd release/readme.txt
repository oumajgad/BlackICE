Hoi3PosEd Beta 26.4 for Hearts of Iron 3

This is a tool to edit the HoI3 Map

Now with TFH and moddir support!


IMPORTANT: YOU HAVE TO CHOOSE YOUR HOI3 GAME FOLDER NOW (NOT THE MAP FOLDER AS IN PREVIOUS VERSIONS!!!)

Features:

-editing of positions of text, units and buildings directly on the map
-searching for position errors
-editing values of buildings and resources at different dates (even multiple provinces at once)
-changing owner, controller and add_core at different dates (even multiple provinces at once)
-Region tool for creating regions (can be used to store selections)
-many map modes for terrain, infra, buildings, resources, owner, controller and add_core
-OOB: moving of units and saving is now possible
-OOB: you can generate an error report to locate units in enemy provinces
-OOB: OOB browser, detach and attach units multiple units at once
-painting rivers on the map and checking for errors
-painting the terrain map (including various filters for the terrain mapmode)


Getting started:

Extract the files and choose your Hoi3 game folder (not the map folder, as in previous versions!).
Use the comboboxes to select a expansion / mod.

***
Be careful, always make backups and don't alter the vanilla files directly.
***

Some notes to the mod folder:

-for FtM and earlier:
 If you want to change province files, you have to copy all province files directly from you game in the history\provinces folder of your mod folder and use the replace="history" command in your mod file.
 Because of the replace command you have to copy all history sub folders too, but this time you have to keep the same folder structure as in the game.
-for TFH:
 You only have to use a replace_path="history\provinces" command in your mod file

Basically the editor creates needed folders for all expansions and keeps the game folder structure.




MOUSE:

drag around the map with the middle mousebutton (like in FtM)
zoom with the mousewheel to the mousecursor

leftclick on a province will select it
shift+left click: adds provinces to the selection
control+left click: removes provinces to the selection
you can leftclick and drag the icons on the map


SEARCHFIELD (top left):
Here you can search ids or province names. By hitting enter the province is selected and centered on the map
With the buttons you can jump back and forward.


CHECKBOX: 'Search Errors'
If checked, all provinces with position errors will be shown (the text will be).
***I put a small threshold in. This could be changed, if necessary.
You can jump between them with the buttons to the right.


ITEM-COMBOBOX to the left:
Here you can select all items. If they have a '*' in the name, they have no position.

POSITIONS-FIELDS to the left:
Type the position and press enter or the "SET" button

CREATE BUTTON
This will create a position for the selected item and centers it on the province







***Paint TOOL*** (shift+F11):
   -painting rivers:

   -select a color form the palette with the left (foreground) or right (background) mousekey
   -paint with the left or right mousekey
   -for erasing use the pink or the white color, doesn't matter which one (the last two colors in the table)
   -hotkey 'x' swaps the foreground and background colors
   -hotkey 'p' picks the color under the mouse cursor on the map
   -to end the paint mode simply close the window
   -if you save the rivers.bmp it is automatically matched to the provinces.bmp. You have to restart the editor to see the changes.

   -painting terrain:

   -the terrain mapmode is automatically created if you choose the terrain tab (you can hide / show the map with F8)
    The terrain map is a layer above the provinces and the political map. So if you have filtered some terrain, you can see them through.
    Remember that you can hide them with F1 and F2(rivers with F3)

   -select a color from the palette with the left (foreground) or right (background) mousekey (only colors defined in terrain.txt are selectable)
   -paint with the left or right mousekey
   -hotkey 'x' swaps the foreground and background colors
   -hotkey 'p' picks the color under the mouse cursor on the map
   -the checkboxes will let you filter the different terrain categories
    The palette is updated immediately. To see the changes on the map you have to press the 'update map' button.

   -The 'select all' and 'invert' buttons are used for the filter checkboxes
   -'draw border' is used to draw borders around the provinces
   -if you save the terrain.bmp it is automatically matched to the provinces.bmp. You have to restart the editor to see the changes.

***REGION TOOL***
You can generate regions by simply select provinces on the map, press 'Create region' button and then copy them to the clipboard.
This does work the other way too. You can paste text and create a selection from it.
Don't worry about the format, just throw in what you want. Only the numbers will be read.

***DETACH (key 'd') AND ATTACH UNITS (key 'a')***
-you can detach and attach multiple units at once (attach works only if there aren't to many land units (5) in the formation, except for a theatre)
  -you can attach units even without detaching first
  -the distance shown is calculated between the first unit and the HQs
  -'***' behind the HQ name means that this HQ belongs to a selected unit
   (theoretically you can attach units to their own HQ. which means that they will be put at the end of the formation)

***UNIT SELECTION WINDOW*** (F11):
  The leader files aren't used yet. There is only Rommel for testing.
  The selection works basically like in FTM:
  -you can multi select units by holding shift.
  -control click selects the hq and its units
  -you can deselect by clicking the X Button
  -the search function only searches for unit names yet. Leader will be added later.
  What does those letters mean?
  E=experience, S=strength, O=organisation, D= dig in
  If there is no number behind this, it means at least one brigade is using a variable


***OOB BROWSER*** (key: 'o')
   There are two windows (you can hide the right one by pressing the button with the two arrows at the top).
   You can navigate independently in the windows, except for the selection, which is the same for both.
   The changes are always made in the active (white background, blue bar) window.
   Attaching units is also possible in this windows (light green HQs).
   The tabbers show a few filters. The 'Land' tab also shows naval and air units attached to HQs (don't know, if I should remove them).
   You can change the country by selecting units (the first unit is used) on the map or typing the tag into the textfield.

   -shift+left click: adds / removes a unit from the selection
   -control+left click: selects the whole formation (and expands it too)
   -control+double click: collapses the formation
   -key: 'm' expand / collapse the OOB
   -key: 'f' goto the selected unit
   -key: 'ESC' cancels attach




KEYBOARD shortcuts:

Space: centers the selected province on the map

shift+left click: adds provinces to the selection
control+left click: removes provinces to the selection

PageUp, PageDown: zoomin/zoomout (to mousecursor)
Cursor Keys: scroll the map

Num+, Num- : scales the selected text
Num*, Num/ : rotates the selected text
Delete: deletes the position (icon will be placed in the center of the province ingame)

x: switches the color for the selected provinces on the map(white or red)
   if the paint tool is open: swaps the foreground and background colors
r: adds a region to the selection
t: adds a country to the selection

'for OOB:
w: centers the selected unit on the map
d: detach unit
a: attach unit
m: expand / collapse the OOB
f: goto the selected unit in the OOB browser
ESC: cancels attach
if OOB view is on 'b' will toggle the selection mode (standard / box selection)

F1: toggles visibility of provinces
F2: toggles visibility of simplemap (political)
F3: toggles visibility of rivers
F4: toggles visibility of all icons
Shift+F4: toggles visibility of the selected icon (the text in the combobox is marked with |h if the icon is hidden)
F5: toggles OOB visibility

F7: toggles 'Show all exiting buildings'
F8: creates a map (you can change the mode in the 'Province details' window
F9: opens 'Province details' window (F9)
F10: opens 'Region tool'
F11: opens 'Unit selection'
'o': toggles OOB browser
shift+F11: opens 'Paint tool'

If the paint tool is open:
x: swaps the foreground and background colors
p: picks the color under the mouse cursor
ctrl+z: undo
ctrl+y: redo