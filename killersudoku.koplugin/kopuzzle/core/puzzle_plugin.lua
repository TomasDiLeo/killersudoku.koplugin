-- kopuzzle/core/puzzle_plugin.lua
-- Base class for puzzle plugins

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local PuzzlePlugin = WidgetContainer:extend{
    name = "puzzle",
    is_doc_only = false,
}

function PuzzlePlugin:init()
    self.settings_file = DataStorage:getSettingsDir() .. "/" .. self.name .. ".lua"
    self.settings = LuaSettings:open(self.settings_file)
    self.ui.menu:registerToMainMenu(self)
end

function PuzzlePlugin:addToMainMenu(menu_items)
    menu_items[self.name] = {
        text = self:getMenuText(),
        sorting_hint = "tools",
        callback = function()
            self:showGame()
        end,
    }
end

-- Abstract methods
function PuzzlePlugin:getMenuText()
    return _("Puzzle")
end

function PuzzlePlugin:createGame()
    error("PuzzlePlugin:createGame() must be implemented by subclass")
end

function PuzzlePlugin:createScreen()
    error("PuzzlePlugin:createScreen() must be implemented by subclass")
end

-- Concrete methods
function PuzzlePlugin:getGame()
    if not self.game then
        self.game = self:createGame()
        local state = self.settings:readSetting("state")
        if state and self.game.deserialize then
            local success = pcall(function()
                self.game:deserialize(state)
            end)
            if not success then
                -- If deserialization fails, generate new puzzle
                if self.game.generatePuzzle then
                    self.game:generatePuzzle()
                end
            end
        elseif self.game.generatePuzzle then
            self.game:generatePuzzle()
        end
    end
    return self.game
end

function PuzzlePlugin:saveState()
    if not self.game then
        return
    end
    if self.game.serialize then
        local state = self.game:serialize()
        self.settings:saveSetting("state", state)
        self.settings:flush()
    end
end

function PuzzlePlugin:showGame()
    if self.screen then
        return
    end
    self.screen = self:createScreen()
    UIManager:show(self.screen)
end

function PuzzlePlugin:onScreenClosed()
    self.screen = nil
end

return PuzzlePlugin