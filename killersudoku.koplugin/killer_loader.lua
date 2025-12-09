-- killersudoku.koplugin/killer_loader.lua
-- Loader for binary Killer Sudoku format

local M = {}

-- Paths to binary files (relative to plugin directory)
local function get_plugin_path()
    -- Get the directory of this file
    local info = debug.getinfo(1, "S")
    local path = info.source:match("@(.*)/")
    if path then
        return path .. "/"
    end
    -- Fallback: try to find from package path
    for search_path in package.path:gmatch("([^;]+)") do
        local test_path = search_path:match("(.*/)")
        if test_path then
            return test_path
        end
    end
    return "./"
end

local PLUGIN_PATH = get_plugin_path()
local PUZZLES_BIN = PLUGIN_PATH .. "puzzles.bin"
local INDEX_BIN = PLUGIN_PATH .. "index.bin"

---------------------------------------------------------
-- Load index on module load
---------------------------------------------------------
local index = {}
local index_loaded = false

local function load_index()
    if index_loaded then return end
    local logger = require("logger")
    
    local f = io.open(INDEX_BIN, "rb")
    if not f then
        logger.warn("Killer Sudoku: index.bin not found at", INDEX_BIN)
        index_loaded = true
        return
    end
    
    while true do
        local bytes = f:read(4)
        if not bytes then break end
        -- 32-bit little-endian unsigned integer
        local b1, b2, b3, b4 = bytes:byte(1, 4)
        local offset = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
        table.insert(index, offset)
    end
    f:close()
    index_loaded = true
    
    logger.info("Killer Sudoku: Loaded", #index, "puzzle indices")
end

---------------------------------------------------------
-- Reads a single byte and returns the number 0–255
---------------------------------------------------------
local function read_byte(f)
    local b = f:read(1)
    if not b then error("Unexpected end of puzzles.bin") end
    return b:byte(1)
end

---------------------------------------------------------
-- Public: load puzzle by ID (1-based index)
-- Returns a Lua structure:
-- {
--    { sum=20, cells={0,1,2,9,18} },
--    { sum=27, cells={3,4,...} },
--    ...
-- }
---------------------------------------------------------
function M.load_puzzle(id)
    load_index()
    
    local offset = index[id]
    if not offset then
        error("Puzzle ID out of range: " .. tostring(id))
    end

    local f = assert(io.open(PUZZLES_BIN, "rb"))
    f:seek("set", offset)

    -- First byte = number of cages
    local cage_count = read_byte(f)

    local puzzle = {}

    for _ = 1, cage_count do
        local sum = read_byte(f)
        local cell_count = read_byte(f)

        local cells = {}
        for i = 1, cell_count do
            cells[i] = read_byte(f)
        end

        puzzle[#puzzle + 1] = {
            sum = sum,
            cells = cells
        }
    end

    f:close()
    return puzzle
end

---------------------------------------------------------
-- Return number of puzzles
---------------------------------------------------------
function M.count()
    load_index()
    return #index
end

---------------------------------------------------------
-- Check if puzzle data is available
---------------------------------------------------------
function M.is_available()
    load_index()
    return #index > 0
end

return M