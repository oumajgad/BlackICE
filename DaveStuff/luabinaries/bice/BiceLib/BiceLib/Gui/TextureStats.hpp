#pragma once

/**
 * What the game asks Direct3D for, texture by texture.
 *
 * The question this exists to answer: when a DXT compressed .dds is loaded, does it
 * stay compressed in memory, or does the loader expand it to 32 bits per pixel? The
 * mod's art can be compressed to a quarter of its size, but that only buys anything
 * if the format survives the load, and reading the game's disassembly could not
 * settle it - the format argument at the call sites comes out of a register.
 *
 * Hooking IDirect3DDevice9::CreateTexture settles it, because D3DX creates its
 * textures through the device like everyone else. Whatever format arrives here is
 * the format the texture actually has.
 *
 * The sizes are computed from the format and the mip chain rather than asked of the
 * driver, so they are what the data costs, not what a particular driver padded it
 * to. Under DXVK the bytes live in Vulkan memory, but D3DPOOL_MANAGED - which is
 * what the game asks for - also keeps a system copy, so they count twice over.
 */

namespace Gui {
    namespace TextureStats {
        struct Row
        {
            unsigned int format = 0;
            char name[20] = {};

            // Alive now: what the process is actually holding.
            unsigned int liveCount = 0;
            unsigned __int64 liveBytes = 0;
            unsigned __int64 liveManagedBytes = 0;

            // Ever created, which says how much churn there is behind the total.
            unsigned int count = 0;
            unsigned __int64 bytes = 0;

            bool compressed = false;
        };

        struct Summary
        {
            unsigned int liveCount = 0;
            unsigned __int64 liveBytes = 0;
            unsigned __int64 liveCompressedBytes = 0;
            unsigned __int64 liveUncompressedBytes = 0;
            unsigned __int64 liveManagedBytes = 0;

            unsigned int count = 0;
            unsigned __int64 bytes = 0;

            unsigned int formats = 0;
            bool hooked = false;
            bool releaseHooked = false;
        };

        /**@brief records one successfully created texture. Callable from any thread.
           @param texture identifies it, so releasing it can be matched up later*/
        void note(const void* texture, unsigned int width, unsigned int height,
            unsigned int levels, unsigned int usage, unsigned int format,
            unsigned int pool);

        /**@brief records that a texture's last reference has gone*/
        void noteDestroyed(const void* texture);

        /**@brief marks the Release hook as installed; without it nothing is ever
           taken off the live totals and they only grow*/
        void setReleaseHooked();

        /**@brief marks the hook as installed, so the page can say so when it is not*/
        void setHooked();

        /**@brief copies a snapshot, largest first
           @returns how many rows were written*/
        int snapshot(Row* out, int capacity);

        Summary summary();

        /**@brief forgets everything counted so far*/
        void reset();
    }
}
