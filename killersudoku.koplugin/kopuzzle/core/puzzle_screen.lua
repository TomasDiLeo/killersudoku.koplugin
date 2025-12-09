-- kopuzzle/core/puzzle_screen.lua
-- Base class for puzzle game screens

local InputContainer = require("ui/widget/container/inputcontainer")
local Device = require("device")
local Geom = require("ui/geometry")
local Font = require("ui/font")
local Size = require("ui/size")
local Screen = Device.screen
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local TextWidget = require("ui/widget/textwidget")
local ButtonTable = require("ui/widget/buttontable")
local FrameContainer = require("ui/widget/container/framecontainer")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local PuzzleScreen = InputContainer:extend{}

function PuzzleScreen:init()
    self.dimen = Geom:new{
        x = 0,
        y = 0,
        w = Screen:getWidth(),
        h = Screen:getHeight()
    }
    self.covers_fullscreen = true
    
    if Device:hasKeys() then
        self.key_events = {
            Close = {{Device.input.group.Back}}
        }
    end
    
    -- Initialize status text
    self.status_text = TextWidget:new{
        text = self:getInitialStatus(),
        face = Font:getFace("smallinfofont"),
    }
    
    -- Initialize renderer (must be provided by subclass or options)
    if not self.renderer then
        error("PuzzleScreen requires a renderer")
    end
    
    self:buildLayout()
end

-- Abstract/customizable methods
function PuzzleScreen:getInitialStatus()
    return _("Welcome to the puzzle!")
end

function PuzzleScreen:getTopButtons()
    return {
        {
            {
                text = _("New game"),
                callback = function() self:onNewGame() end,
            },
            {
                text = _("Restart"),
                callback = function() self:onRestart() end,
            },
            {
                text = _("Close"),
                callback = function()
                    self:onClose()
                    UIManager:close(self)
                    UIManager:setDirty(nil, "full")
                end,
            },
        },
    }
end

function PuzzleScreen:getActionButtons()
    -- Override in subclass for game-specific actions
    return {}
end

function PuzzleScreen:buildLayout()
    local board_frame_width = math.floor(Screen:getWidth() * 0.9)
    local board_frame_padding = Size.padding.large
    
    local board_frame = FrameContainer:new{
        padding = board_frame_padding,
        width = board_frame_width,
        bordersize = 0,
        self.renderer,
    }
    
    -- Create top buttons
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width = math.floor(Screen:getWidth() * 0.9),
        buttons = self:getTopButtons(),
    }
    
    -- Create action buttons if any
    local action_buttons = nil
    local action_buttons_config = self:getActionButtons()
    if #action_buttons_config > 0 then
        action_buttons = ButtonTable:new{
            shrink_unneeded_width = true,
            width = math.floor(Screen:getWidth() * 0.85),
            buttons = action_buttons_config,
        }
        self.action_buttons = action_buttons
    end
    
    local layout_vertical_margin = Size.padding.large
    local top_buttons_height = top_buttons:getSize().h
    local status_height = self.status_text:getSize().h
    local action_height = action_buttons and action_buttons:getSize().h or 0
    
    local frame_border = board_frame.bordersize or Size.border.window
    local frame_margin = board_frame.margin or 0
    local board_inner_width = board_frame_width - 2 * (board_frame_padding + frame_border + frame_margin)
    
    local available_height = Screen:getHeight() - 2 * layout_vertical_margin
    local spacing = Size.span.vertical_default * 4
    available_height = available_height - spacing - top_buttons_height - status_height - action_height
    local board_inner_height = available_height - 2 * (frame_border + frame_margin + board_frame_padding)
    
    board_inner_width = math.max(1, board_inner_width)
    board_inner_height = math.max(1, board_inner_height)
    
    self.renderer:setMaxDimensions(board_inner_width, board_inner_height)
    board_frame.height = math.max(0, board_inner_height + 2 * (board_frame_padding + frame_border + frame_margin))
    
    self.layout_vertical_margin = layout_vertical_margin
    
    self.content_layout = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{width = Size.span.vertical_default},
        top_buttons,
        VerticalSpan:new{width = Size.span.vertical_default},
        board_frame,
        VerticalSpan:new{width = Size.span.vertical_default},
    }
    
    local scrolling_height = Screen:getHeight() - 2 * layout_vertical_margin - action_height - status_height - 2 * Size.span.vertical_default
    local scrolling_width = math.floor(Screen:getWidth() * 0.95)
    
    self.layout = ScrollableContainer:new{
        dimen = Geom:new{w = scrolling_width, h = scrolling_height},
        self.content_layout,
    }
    
    self[1] = self.layout
    self[2] = self.status_text
    if action_buttons then
        self[3] = action_buttons
    end
end

function PuzzleScreen:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    
    local top_offset = self.layout_vertical_margin or Size.padding.large
    local layout_size = self.layout.dimen or self.layout:getSize()
    local layout_x = x + math.floor((self.dimen.w - layout_size.w) / 2)
    local layout_y = y + top_offset
    self.layout:paintTo(bb, layout_x, layout_y)
    
    local status_size = self.status_text:getSize()
    local status_x = x + math.floor((self.dimen.w - status_size.w) / 2)
    local status_y = layout_y + layout_size.h + Size.span.vertical_default
    self.status_text:paintTo(bb, status_x, status_y)
    
    if self.action_buttons then
        local action_size = self.action_buttons:getSize()
        local action_x = x + math.floor((self.dimen.w - action_size.w) / 2)
        local action_y = status_y + status_size.h + Size.span.vertical_default
        self.action_buttons.dimen = Geom:new{
            x = action_x,
            y = action_y,
            w = action_size.w,
            h = action_size.h
        }
        self.action_buttons:paintTo(bb, action_x, action_y)
    end
end

function PuzzleScreen:updateStatus(message)
    self.status_text:setText(message or self:getInitialStatus())
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

-- Event handlers (can be overridden)
function PuzzleScreen:onNewGame()
    -- Override in subclass
end

function PuzzleScreen:onRestart()
    -- Override in subclass
end

function PuzzleScreen:onClose()
    if self.plugin then
        self.plugin:onScreenClosed()
    end
end

function PuzzleScreen:onShow()
    UIManager:setDirty(self, function()
        return "full", self.dimen
    end)
    return true
end

return PuzzleScreen