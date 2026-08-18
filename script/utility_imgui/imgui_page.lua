-- Shared error handling for the ImGui page modules.
--
-- Every call the overlay makes into a page is answered with a table carrying an
-- available flag. A page that throws has to answer the same way, with the error as its
-- reason: the overlay calls in from the render thread and can only report what the
-- table tells it, so an unguarded error would reach the player as a blank panel.

local Page = {}

--- Runs one page call, turning an error into an unavailable answer.
function Page.Guard(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        return { available = false, reason = tostring(result) }
    end
    return result
end

return Page
