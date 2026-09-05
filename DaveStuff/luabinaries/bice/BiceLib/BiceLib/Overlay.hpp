#pragma once

/**
 * Dear ImGui overlay rendered directly inside hoi3_tfh.exe.
 *
 * The game renders with Direct3D 9, so the overlay works by patching the shared
 * IDirect3DDevice9 vtable (Present + Reset). d3d9.dll hands out one vtable for
 * every device it creates, so hooking it through a throwaway device also catches
 * the device the game is drawing with.
 *
 * Present rather than EndScene: the game wraps its offscreen render targets in
 * their own BeginScene/EndScene pairs, so an EndScene hook draws the overlay into
 * cached UI textures instead of only onto the screen.
 *
 * Input is picked up by subclassing the game window; messages ImGui wants are
 * swallowed so the game does not also act on them.
 */
#include <string>

struct IDirect3DDevice9;

namespace Overlay {
    /**
    @brief the directory BiceLib.dll sits in, ending in a separator

    Where everything the overlay owns is kept, rather than the game's root: the docking
    layout, and the console's saved scripts. Empty only if the module path could not be
    read at all.
    */
    const std::string& directory();

    /**
    @brief the directory hoi3_tfh.exe sits in, ending in a separator

    The game's own root, which is not where the DLL lives - that is inside the mod. Mod
    content is reached from here, as the utility's Lua reaches it through the working
    directory, which is the game root only for as long as nothing changes it.
    */
    const std::string& gameDirectory();

    /**@brief the device the game is rendering with, null before the first frame.
       Needed by anything creating its own D3D resources, such as the texture cache.*/
    IDirect3DDevice9* device();

    /**@brief installs the D3D9 hooks. Safe to call more than once.
       @returns false if D3D9 was unavailable or the hooks could not be placed*/
    bool install();

    /**@brief shows/hides the overlay windows (also bound to the key below)*/
    void toggle();

    /**@brief whether the overlay is currently drawing*/
    bool isVisible();

    /**
    @brief the virtual key code that shows and hides the overlay

    INSERT unless it has been changed. Kept in the settings file, so it survives a
    restart, and read the first time it is needed rather than at load time.
    */
    unsigned toggleKey();

    /**@brief rebinds the key and saves it*/
    void setToggleKey(unsigned virtualKey);

    /**@brief what to call the key on screen, e.g. "Insert", from Windows' own table*/
    std::string toggleKeyName();

    /**
    @brief waits for the next key press and binds it

    While this is waiting the window procedure swallows key presses instead of acting
    on them, so binding a key the game uses does not also trigger the game. ESCAPE
    cancels rather than binds: it opens the game's menu, so it is a poor choice, and
    being unable to back out of a capture would be worse.
    */
    void beginToggleKeyCapture();
    bool capturingToggleKey();
    void cancelToggleKeyCapture();

    /**
    @brief whether a page may be dragged out of the game window into one of its own

    False in exclusive fullscreen, where D3D9 refuses a detached window the swap chain
    it needs, and false when the presenting thread does not own the game window. Worth
    saying on the page rather than leaving a player to find that pages behave one way
    in a window and another way fullscreen and assume something is broken.
    */
    bool canDetachPages();
}
