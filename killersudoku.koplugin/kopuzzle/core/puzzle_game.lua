-- kopuzzle/core/puzzle_game.lua
-- Base class for all puzzle game logic

local PuzzleGame = {}
PuzzleGame.__index = PuzzleGame

function PuzzleGame:new()
    local game = {
        state = nil,
        config = {},
    }
    setmetatable(game, self)
    return game
end

function PuzzleGame:extend()
    local class = {}
    setmetatable(class, {__index = self})
    class.__index = class
    return class
end

-- Abstract methods to be implemented by subclasses
function PuzzleGame:initialize(config)
    error("PuzzleGame:initialize() must be implemented by subclass")
end

function PuzzleGame:resetState()
    error("PuzzleGame:resetState() must be implemented by subclass")
end

function PuzzleGame:validateMove(move)
    error("PuzzleGame:validateMove() must be implemented by subclass")
end

function PuzzleGame:applyMove(move)
    error("PuzzleGame:applyMove() must be implemented by subclass")
end

function PuzzleGame:checkWinCondition()
    error("PuzzleGame:checkWinCondition() must be implemented by subclass")
end

function PuzzleGame:serialize()
    error("PuzzleGame:serialize() must be implemented by subclass")
end

function PuzzleGame:deserialize(data)
    error("PuzzleGame:deserialize() must be implemented by subclass")
end

function PuzzleGame:generatePuzzle(params)
    error("PuzzleGame:generatePuzzle() must be implemented by subclass")
end

-- Utility method that can be used by subclasses
function PuzzleGame:clamp(value, min_val, max_val)
    return math.max(min_val, math.min(max_val, value))
end

return PuzzleGame