-- Import the MPV API
local mp = require 'mp'

-- === CONFIGURATION ===
-- Customizable keybinding for toggling RTX ON/OFF
local toggle_key = "ctrl+shift+u" 
-- Number of decimal places to which the scaling factor is rounded
local rounding_precision = 3 
-- Whether the script starts with RTX enabled by default
local autovsr_enabled = false

-- === UTILITY FUNCTIONS ===

-- Function: round_to_precision
-- Purpose: Rounds a given value to a specified number of decimal places.
-- Parameters:
--   value - the number to be rounded.
--   precision - the number of decimal places to round to.
-- Returns: The value rounded to the specified precision.
local function round_to_precision(value, precision)
    local multiplier = 10 ^ precision -- Compute the multiplier based on precision (e.g., 1000 for 3 dp)
    return math.floor(value * multiplier + 0.5) / multiplier -- Round value and divide back
end

-- Function: is_valid_resolution
-- Purpose: Checks if a resolution (width and height) is valid (not nil).
-- Parameters:
--   width - the width of the resolution.
--   height - the height of the resolution.
-- Returns: true if both width and height are valid, otherwise false.
local function is_valid_resolution(width, height)
    return width ~= nil and height ~= nil
end

-- === MAIN FUNCTIONS ===

-- Function: autovsr
-- Purpose: Automatically adjusts scaling based on the current video and display resolution.
-- Steps:
--   1. Retrieves video and display dimensions.
--   2. Calculates the appropriate scaling factor dynamically.
--   3. Applies the scaling using NVIDIA hardware acceleration if required.
local function autovsr()
    -- Get display and video dimensions from MPV properties
    local display_width = mp.get_property_native("display-width")
    local video_width = mp.get_property_native("width")
    local display_height = mp.get_property_native("display-height")
    local video_height = mp.get_property_native("height")
    -- Get pixel format of the video (hardware or software-based)
    local pixfmt = mp.get_property_native("video-params/hw-pixelformat") or
        mp.get_property_native("video-params/pixelformat")

    -- Validate that both video and display resolutions are valid
    if not is_valid_resolution(display_width, display_height) or not is_valid_resolution(video_width, video_height) then
        mp.msg.warn("Invalid resolution properties. Skipping scaling.") -- Warn if any resolution is missing
        return
    end

    -- Calculate the scale factor by dividing the largest display dimension by the largest video dimension
    local scale = math.max(display_width, display_height) / math.max(video_width, video_height)
    scale = round_to_precision(scale, rounding_precision) -- Round the scale factor to 3 decimal places

    -- Retrieve the current video filter list
    local vf = mp.get_property("vf") or ""
    -- Remove existing NVIDIA scaling filter if it already exists
    if string.match(vf, "@vsr") then
        mp.command("vf remove @vsr")
    end

    -- Apply scaling only if the scale factor is greater than 1 (i.e., upscaling is needed)
    if scale > 1 then
        -- Use NVIDIA's d3d11vpp filter for scaling with the calculated factor
        mp.command("vf append @vsr:d3d11vpp:scaling-mode=nvidia:scale=" .. scale)
        -- Provide OSD feedback about the applied scaling factor
        mp.osd_message("Scaling applied: " .. scale)
    else
        -- Log information if no scaling is required
        mp.msg.info("No scaling applied. Scale factor: " .. scale)
    end
end

-- Function: enable_autovsr
-- Purpose: Enables the auto-scaling functionality by observing MPV properties and applying filters dynamically.
local function enable_autovsr()
    if not autovsr_enabled then -- Check if the feature is already enabled
        autovsr_enabled = true
    end

    autovsr() -- Trigger the scaling process
    -- Observe MPV properties and call autovsr whenever these properties change
    mp.observe_property("video-params/pixelformat", "native", autovsr)
    mp.observe_property("vf", "native", autovsr)
    -- Notify the user via OSD that RTX scaling is enabled
    mp.osd_message("RTX ON")
end

-- Function: disable_autovsr
-- Purpose: Disables the auto-scaling functionality by removing filters and stopping property observation.
local function disable_autovsr()
    if autovsr_enabled then -- Check if the feature is already disabled
        autovsr_enabled = false
    end

    -- Remove the NVIDIA scaling filter
    mp.command("vf remove @vsr")
    -- Stop observing MPV properties
    mp.unobserve_property(autovsr)
    -- Notify the user via OSD that RTX scaling is disabled
    mp.osd_message("RTX OFF")
end

-- Function: toggle_autovsr
-- Purpose: Toggles auto-scaling on or off using the specified keybinding.
local function toggle_autovsr()
    if autovsr_enabled then
        disable_autovsr() -- Disable if currently enabled
    else
        enable_autovsr() -- Enable if currently disabled
    end
end

-- === SCRIPT INITIATION ===

-- Automatically enable auto-scaling (RTX ON) when the script is loaded
-- Uncomment to enable
-- enable_autovsr()

-- Bind the toggle function to the specified keybinding
mp.add_key_binding(toggle_key, "toggle_autovsr", toggle_autovsr)

-- END OF SCRIPT