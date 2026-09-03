local mp = require 'mp'
local assdraw = require 'mp.assdraw'

mp.set_property("osc", "no")
mp.set_property("osd-bar", "no")

local overlay = mp.create_osd_overlay("ass-events")
local active = true
local hide_timer = nil
local show_duration = 2.0

local function format_time(seconds)
    if not seconds then return "00:00" end
    local s = math.floor(seconds)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    s = s % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function render()
    local is_fs = mp.get_property_bool("fullscreen", false)

    -- If fullscreen and inactive, clear overlay
    if is_fs and not active then
        overlay:remove()
        return
    end

    local w, h = mp.get_osd_size()
    if not w or not h or w == 0 then return end

    overlay.res_x = w
    overlay.res_y = h

    local duration = mp.get_property_native("duration") or 0
    local time_pos = mp.get_property_native("time-pos") or 0
    local percent = (duration > 0) and (time_pos / duration) or 0

    local ass = assdraw.ass_new()
    local panel_h = 60
    local panel_y = h - panel_h
    local bar_h = 5
    local bar_y = panel_y + 28
    local margin_x = 95
    local center_y = bar_y + (bar_h / 2)

    ass:new_event()
    ass:pos(0, 0)
    ass:append("{\\1c&H000000&\\1a&H88&\\bord0}")
    ass:draw_start()
    ass:rect_cw(0, panel_y, w, h)
    ass:draw_stop()

    ass:new_event()
    ass:pos(0,0)
    ass:append("{\\1c&H444444&\\1a&H44&\\bord0}")
    ass:draw_start()
    ass:rect_cw(margin_x, bar_y, w - margin_x, bar_y + bar_h)
    ass:draw_stop()

    local p_width = margin_x + ((w - margin_x * 2) * percent)
    if p_width > margin_x then
        ass:new_event()
        ass:pos(0,0)
        ass:append("{\\1c&H0065FF&\\bord0}")
        ass:draw_start()
        ass:rect_cw(margin_x, bar_y, p_width, bar_y + bar_h)
        ass:draw_stop()
    end

    local r = 7
    ass:new_event()
    ass:pos(0,0)
    ass:append("{\\1c&H0065FF&\\bord0}")
    ass:draw_start()
    ass:round_rect_cw(p_width - r, center_y - r, p_width + r, center_y + r, r)
    ass:draw_stop()

    ass:new_event()
    ass:pos(15, center_y)
    ass:append(string.format("{\\an4\\fs24\\b1\\c&HFFFFFF&\\3c&H000000&\\3a&H44&\\bord1.5}%s", format_time(time_pos)))

    ass:new_event()
    ass:pos(w - 15, center_y)
    ass:append(string.format("{\\an6\\fs24\\b1\\c&HFFFFFF&\\3c&H000000&\\3a&H44&\\bord1.5}%s", format_time(duration)))

    overlay.data = ass.text
    overlay:update()
end

local function hide_ui()
    if mp.get_property_bool("fullscreen", false) then
        active = false
        render()
    end
end

local function show_ui()
    active = true
    render()
    if hide_timer then hide_timer:kill() end
    if mp.get_property_bool("fullscreen", false) then
        hide_timer = mp.add_timeout(show_duration, hide_ui)
    end
end

local function on_fullscreen_change(_, is_fs)
    if not is_fs then
        active = true -- Always show when leaving fullscreen (windowed mode)
        if hide_timer then hide_timer:kill() end
    else
        hide_timer = mp.add_timeout(show_duration, hide_ui)
    end
    render()
end

local function on_click()
    local is_fs = mp.get_property_bool("fullscreen", false)
    if is_fs and not active then 
        show_ui()
        mp.command("cycle pause")
        return 
    end
    
    local w, h = mp.get_osd_size()
    local mouse_x, mouse_y = mp.get_mouse_pos()
    local panel_h = 60
    local panel_y = h - panel_h
    local bar_h = 5
    local bar_y = panel_y + 28
    local margin_x = 95

    if mouse_y >= (bar_y - 15) and mouse_y <= (bar_y + bar_h + 15) then
        if mouse_x >= margin_x and mouse_x <= (w - margin_x) then
            local percent = (mouse_x - margin_x) / (w - margin_x * 2)
            local duration = mp.get_property_native("duration")
            if duration then
                mp.set_property_native("time-pos", duration * percent)
                show_ui()
            end
            return
        end
    end
    
    mp.command("cycle pause")
end

mp.observe_property("time-pos", "number", render)
mp.observe_property("duration", "number", render)
mp.observe_property("osd-dimensions", "native", render)
mp.observe_property("fullscreen", "bool", on_fullscreen_change)

mp.add_forced_key_binding("mouse_move", "mouse_move", show_ui)
mp.add_forced_key_binding("MBTN_LEFT", "seek_click", on_click)