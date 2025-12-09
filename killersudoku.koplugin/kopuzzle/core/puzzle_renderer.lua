-- kopuzzle/core/puzzle_renderer.lua
-- Base class for puzzle rendering

local InputContainer = require("ui/widget/container/inputcontainer")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")

local PuzzleRenderer = InputContainer:extend{
    game = nil,
    max_width = nil,
    max_height = nil,
}

function PuzzleRenderer:init()
    self.paint_rect = Geom:new{x = 0, y = 0, w = 10, h = 10}
    self:setupGestures()
end

function PuzzleRenderer:setupGestures()
    -- Can be overridden by subclasses for specific gesture handling
    self.ges_events = {
        Tap = {
            require("ui/gesturerange"):new{
                ges = "tap",
                range = function()
                    return self.paint_rect
                end,
            },
        },
    }
end

function PuzzleRenderer:setMaxDimensions(max_w, max_h)
    self.max_width = max_w
    self.max_height = max_h
    if self.game then
        self:updateMetrics()
    end
end

-- Abstract methods
function PuzzleRenderer:updateMetrics()
    error("PuzzleRenderer:updateMetrics() must be implemented by subclass")
end

function PuzzleRenderer:paintTo(bb, x, y)
    error("PuzzleRenderer:paintTo() must be implemented by subclass")
end

-- Utility methods
function PuzzleRenderer:refresh()
    if not self.paint_rect then
        return
    end
    UIManager:setDirty(self, function()
        return "ui", Geom:new{
            x = self.paint_rect.x,
            y = self.paint_rect.y,
            w = self.paint_rect.w,
            h = self.paint_rect.h,
        }
    end)
end

function PuzzleRenderer:onTap(_, ges)
    -- Default implementation - can be overridden
    return false
end

return PuzzleRenderer