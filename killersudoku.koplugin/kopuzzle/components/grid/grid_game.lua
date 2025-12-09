-- kopuzzle/components/grid/grid_game.lua
-- Grid-based puzzle game component
local PuzzleGame = require("kopuzzle/core/puzzle_game")

local GridGame = PuzzleGame:extend()

function GridGame:new()
    local game = PuzzleGame.new(self)
    game.rows = 0
    game.cols = 0
    game.grid = {}
    game.selected = {row = 1, col = 1}
    return game
end

function GridGame:createEmptyGrid(rows, cols, default_value)
    default_value = default_value or 0
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = default_value
        end
    end
    return grid
end

function GridGame:copyGrid(source_grid)
    local copy = {}
    for r, row in ipairs(source_grid) do
        copy[r] = {}
        for c, value in ipairs(row) do
            copy[r][c] = value
        end
    end
    return copy
end

function GridGame:validateGrid(grid, rows, cols)
    if type(grid) ~= "table" then
        return nil
    end
    local validated = {}
    for r = 1, rows do
        local source_row = grid[r]
        if type(source_row) ~= "table" then
            return nil
        end
        validated[r] = {}
        for c = 1, cols do
            validated[r][c] = source_row[c]
        end
    end
    return validated
end

function GridGame:getCellState(row, col)
    if not self.grid[row] then
        return nil
    end
    return self.grid[row][col]
end

function GridGame:setCellState(row, col, value)
    if not self.grid[row] then
        return false
    end
    self.grid[row][col] = value
    return true
end

function GridGame:setSelection(row, col)
    self.selected.row = self:clamp(row, 1, math.max(1, self.rows))
    self.selected.col = self:clamp(col, 1, math.max(1, self.cols))
end

function GridGame:getSelection()
    return self.selected.row, self.selected.col
end

function GridGame:moveSelection(direction)
    local row, col = self:getSelection()
    if direction == "up" then
        row = row - 1
    elseif direction == "down" then
        row = row + 1
    elseif direction == "left" then
        col = col - 1
    elseif direction == "right" then
        col = col + 1
    end
    self:setSelection(row, col)
end

return GridGame