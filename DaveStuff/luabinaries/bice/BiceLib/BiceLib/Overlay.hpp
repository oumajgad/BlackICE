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
struct IDirect3DDevice9;

namespace Overlay {
    /**@brief the device the game is rendering with, null before the first frame.
       Needed by anything creating its own D3D resources, such as the texture cache.*/
    IDirect3DDevice9* device();

    /**@brief installs the D3D9 hooks. Safe to call more than once.
       @returns false if D3D9 was unavailable or the hooks could not be placed*/
    bool install();

    /**@brief shows/hides the overlay windows (also bound to the INSERT key)*/
    void toggle();

    /**@brief whether the overlay is currently drawing*/
    bool isVisible();
}
