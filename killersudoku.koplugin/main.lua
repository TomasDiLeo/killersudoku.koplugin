-- killersudoku.koplugin/main.lua
-- Killer Sudoku puzzle game plugin using the kopuzzle framework

local PuzzlePlugin = require("kopuzzle/core/puzzle_plugin")
local _ = require("gettext")

local KillerSudoku = PuzzlePlugin:extend{
    name = "killersudoku",
    is_doc_only = false,
}

function KillerSudoku:getMenuText()
    return _("Killer Sudoku")
end

function KillerSudoku:createGame()
    local KillerSudokuGame = require("killer_game")
    return KillerSudokuGame:new()
end

function KillerSudoku:createScreen()
    local KillerSudokuScreen = require("killer_screen")
    return KillerSudokuScreen:new{
        game = self:getGame(),
        plugin = self,
    }
end

return KillerSudoku