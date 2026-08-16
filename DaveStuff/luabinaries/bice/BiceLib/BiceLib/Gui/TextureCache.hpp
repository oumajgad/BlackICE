#pragma once

#include <string>

#include <imgui.h>

/**
 * Loads game sprites for display in the overlay.
 *
 * The mod ships unit models as .tga, which neither ImGui nor D3D9 loads on its own, so
 * this decodes them and uploads a texture. Textures are cached by path because a page
 * asks for the same image every frame.
 *
 * D3DPOOL_MANAGED is deliberate: it survives a device reset, so alt-tabbing does not
 * need every sprite re-decoded. releaseAll() exists for shutdown and for the case
 * where the device itself is replaced.
 */
namespace Gui {
    namespace Textures {
        /**
        @brief the texture for a .tga path, loading it on first use
        @param path relative to the game directory, as the mod's Lua reports it
        @returns an ImGui texture id, or 0 if the file is missing or unreadable
        */
        ImTextureID get(const std::string& path);

        /**@brief pixel size of a loaded texture, 0x0 when it could not be loaded*/
        ImVec2 size(const std::string& path);

        /**@brief drops every cached texture*/
        void releaseAll();
    }
}
