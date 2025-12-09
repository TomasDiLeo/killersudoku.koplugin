-- killersudoku.koplugin/killer_game.lua
-- Killer Sudoku game logic using kopuzzle framework

local GridGame = require("kopuzzle/components/grid/grid_game")
local loader = require("killer_loader")

local KillerSudokuGame = GridGame:extend()

function KillerSudokuGame:new()
    local game = GridGame.new(self)
    game.rows = 9
    game.cols = 9
    game.user = self:createEmptyGrid(9, 9)
    game.solution = self:createEmptyGrid(9, 9)
    game.conflicts = self:createEmptyGrid(9, 9, false)
    game.notes = self:createEmptyNotes()
    game.cages = {}  -- Array of cage definitions
    game.cage_grid = self:createEmptyGrid(9, 9)  -- Maps cell to cage number
    game.puzzle_id = 1
    
    -- Check if puzzle data is available
    local count = loader.count()
    if count == 0 then
        local logger = require("logger")
        logger.err("Killer Sudoku: No puzzle data found!")
        logger.err("Please ensure puzzles.bin and index.bin are in the killersudoku.koplugin directory")
    end
    
    game.max_puzzle_id = math.max(1, count)
    game.undo_stack = {}
    game.reveal_solution = false
    return game
end

function KillerSudokuGame:createEmptyNotes()
    local notes = {}
    for r = 1, 9 do
        notes[r] = {}
        for c = 1, 9 do
            notes[r][c] = {}
        end
    end
    return notes
end

function KillerSudokuGame:copyNotes(src)
    local notes = {}
    for r = 1, 9 do
        notes[r] = {}
        for c = 1, 9 do
            local dest_cell = {}
            local source_cell = src and src[r] and src[r][c]
            if type(source_cell) == "table" then
                for digit, flag in pairs(source_cell) do
                    local d = tonumber(digit)
                    if d and d >= 1 and d <= 9 and flag then
                        dest_cell[d] = true
                    end
                end
            end
            notes[r][c] = dest_cell
        end
    end
    return notes
end

function KillerSudokuGame:cloneNoteCell(cell)
    if not cell then
        return nil
    end
    local copy = nil
    for digit = 1, 9 do
        if cell[digit] then
            copy = copy or {}
            copy[digit] = true
        end
    end
    return copy
end

-- Convert flat cell index (0-80) to row, col (1-9, 1-9)
function KillerSudokuGame:flatToRowCol(flat_index)
    local row = math.floor(flat_index / 9) + 1
    local col = (flat_index % 9) + 1
    return row, col
end

-- Convert row, col to flat index
function KillerSudokuGame:rowColToFlat(row, col)
    return (row - 1) * 9 + (col - 1)
end

function KillerSudokuGame:loadPuzzleData(puzzle_id)
    local puzzle_data = loader.load_puzzle(puzzle_id)
    
    -- Clear existing data
    self.cages = {}
    self.cage_grid = self:createEmptyGrid(9, 9)
    
    -- Process each cage
    for cage_num, cage_def in ipairs(puzzle_data) do
        local cage = {
            sum = cage_def.sum,
            cells = {},
            cage_num = cage_num
        }
        
        for _, flat_index in ipairs(cage_def.cells) do
            local row, col = self:flatToRowCol(flat_index)
            table.insert(cage.cells, {row = row, col = col})
            self.cage_grid[row][col] = cage_num
        end
        
        table.insert(self.cages, cage)
    end

    self:colorCages()
end

-- Puzzle generation functions (backtracking solver)
function KillerSudokuGame:shuffledDigits()
    local digits = {1, 2, 3, 4, 5, 6, 7, 8, 9}
    for i = #digits, 2, -1 do
        local j = math.random(i)
        digits[i], digits[j] = digits[j], digits[i]
    end
    return digits
end

function KillerSudokuGame:isValidPlacement(grid, row, col, value)
    -- Check row
    for c = 1, 9 do
        if c ~= col and grid[row][c] == value then
            return false
        end
    end
    
    -- Check column
    for r = 1, 9 do
        if r ~= row and grid[r][col] == value then
            return false
        end
    end
    
    -- Check 3x3 box
    local box_row = math.floor((row - 1) / 3) * 3 + 1
    local box_col = math.floor((col - 1) / 3) * 3 + 1
    for r = box_row, box_row + 2 do
        for c = box_col, box_col + 2 do
            if (r ~= row or c ~= col) and grid[r][c] == value then
                return false
            end
        end
    end
    
    -- Check cage constraint (no duplicates, sum check)
    local cage_num = self.cage_grid[row][col]
    if cage_num > 0 then
        local cage = self.cages[cage_num]
        local cage_sum = 0
        local cage_count = 0
        
        for _, cell in ipairs(cage.cells) do
            local r, c = cell.row, cell.col
            if r == row and c == col then
                cage_sum = cage_sum + value
                cage_count = cage_count + 1
            elseif grid[r][c] ~= 0 then
                if grid[r][c] == value then
                    return false  -- Duplicate in cage
                end
                cage_sum = cage_sum + grid[r][c]
                cage_count = cage_count + 1
            end
        end
        
        -- If cage is complete, check sum
        if cage_count == #cage.cells then
            if cage_sum ~= cage.sum then
                return false
            end
        elseif cage_sum > cage.sum then
            return false  -- Already exceeds target
        end
    end
    
    return true
end

function KillerSudokuGame:solvePuzzle(grid, cell)
    if cell > 81 then
        return true
    end
    
    local row = math.floor((cell - 1) / 9) + 1
    local col = (cell - 1) % 9 + 1
    
    if grid[row][col] ~= 0 then
        return self:solvePuzzle(grid, cell + 1)
    end
    
    for _, value in ipairs(self:shuffledDigits()) do
        if self:isValidPlacement(grid, row, col, value) then
            grid[row][col] = value
            if self:solvePuzzle(grid, cell + 1) then
                return true
            end
            grid[row][col] = 0
        end
    end
    
    return false
end

function KillerSudokuGame:generatePuzzle(params)
    local puzzle_id = (params and params.puzzle_id) or self.puzzle_id or 1
    
    -- Validate puzzle ID
    if puzzle_id < 1 then puzzle_id = 1 end
    if puzzle_id > self.max_puzzle_id then puzzle_id = self.max_puzzle_id end
    
    self.puzzle_id = puzzle_id
    
    -- Load cage structure
    self:loadPuzzleData(puzzle_id)
    
    -- Don't generate solution - it's too slow
    -- Solution will be checked by validating constraints
    self.solution = self:createEmptyGrid(9, 9)
    
    -- Clear user data
    self.user = self:createEmptyGrid(9, 9)
    self.notes = self:createEmptyNotes()
    self.conflicts = self:createEmptyGrid(9, 9, false)
    self.selected = {row = 1, col = 1}
    self.reveal_solution = false
    self.undo_stack = {}
    
    self:recalcConflicts()
end

function KillerSudokuGame:recalcConflicts()
    for r = 1, 9 do
        for c = 1, 9 do
            self.conflicts[r][c] = false
        end
    end
    
    local function markConflicts(cells)
        local map = {}
        for _, cell in ipairs(cells) do
            if cell.value ~= 0 then
                map[cell.value] = map[cell.value] or {}
                table.insert(map[cell.value], cell)
            end
        end
        for _, positions in pairs(map) do
            if #positions > 1 then
                for _, pos in ipairs(positions) do
                    self.conflicts[pos.row][pos.col] = true
                end
            end
        end
    end
    
    -- Check rows
    for r = 1, 9 do
        local cells = {}
        for c = 1, 9 do
            cells[#cells + 1] = {row = r, col = c, value = self.user[r][c]}
        end
        markConflicts(cells)
    end
    
    -- Check columns
    for c = 1, 9 do
        local cells = {}
        for r = 1, 9 do
            cells[#cells + 1] = {row = r, col = c, value = self.user[r][c]}
        end
        markConflicts(cells)
    end
    
    -- Check 3x3 boxes
    for box_row = 0, 2 do
        for box_col = 0, 2 do
            local cells = {}
            for r = 1, 3 do
                for c = 1, 3 do
                    local row = box_row * 3 + r
                    local col = box_col * 3 + c
                    cells[#cells + 1] = {row = row, col = col, value = self.user[row][col]}
                end
            end
            markConflicts(cells)
        end
    end
    
    -- Check cages
    for _, cage in ipairs(self.cages) do
        local cells = {}
        for _, cell in ipairs(cage.cells) do
            cells[#cells + 1] = {
                row = cell.row, 
                col = cell.col, 
                value = self.user[cell.row][cell.col]
            }
        end
        markConflicts(cells)
    end
end

function KillerSudokuGame:getCageNumber(row, col)
    return self.cage_grid[row][col] or 0
end

function KillerSudokuGame:getCage(row, col)
    local cage_num = self:getCageNumber(row, col)
    if cage_num > 0 then
        return self.cages[cage_num]
    end
    return nil
end

function KillerSudokuGame:getDisplayValue(row, col)
    local value = self.user[row][col]
    if value == 0 then
        return nil
    end
    return value
end

function KillerSudokuGame:isConflict(row, col)
    return self.conflicts[row][col]
end

function KillerSudokuGame:setValue(value)
    local _ = require("gettext")
    
    local row, col = self:getSelection()
    local prev_value = self.user[row][col]
    local prev_notes = self:cloneNoteCell(self.notes[row][col])
    local new_value = value or 0
    
    if prev_value == new_value and not prev_notes then
        if not value then
            return false, _("Cell already empty.")
        end
        return true
    end
    
    self.user[row][col] = new_value
    self:clearNotes(row, col)
    self:recalcConflicts()
    
    if prev_value ~= new_value or prev_notes then
        self:pushUndo{
            type = "value",
            row = row,
            col = col,
            prev_value = prev_value,
            prev_notes = prev_notes,
        }
    end
    return true
end

function KillerSudokuGame:clearNotes(row, col)
    if self.notes[row] and self.notes[row][col] then
        self.notes[row][col] = {}
    end
end

function KillerSudokuGame:getCellNotes(row, col)
    local cell = self.notes[row] and self.notes[row][col]
    if not cell then
        return nil
    end
    for digit = 1, 9 do
        if cell[digit] then
            return cell
        end
    end
    return nil
end

function KillerSudokuGame:toggleNoteDigit(value)
    local _ = require("gettext")
    
    local row, col = self:getSelection()
    if self.user[row][col] ~= 0 then
        return false, _("Clear the cell before adding notes.")
    end
    
    self.notes[row][col] = self.notes[row][col] or {}
    local prev_cell = self:cloneNoteCell(self.notes[row][col])
    local was_set = self.notes[row][col][value] and true or false
    
    if was_set then
        self.notes[row][col][value] = nil
    else
        self.notes[row][col][value] = true
    end
    
    local now_set = self.notes[row][col][value] and true or false
    if was_set == now_set then
        return true
    end
    
    self:pushUndo{
        type = "notes",
        row = row,
        col = col,
        prev_notes = prev_cell,
    }
    return true
end

function KillerSudokuGame:getRemainingCells()
    local remaining = 0
    for r = 1, 9 do
        for c = 1, 9 do
            if self.user[r][c] == 0 then
                remaining = remaining + 1
            end
        end
    end
    return remaining
end

function KillerSudokuGame:pushUndo(entry)
    if entry then
        self.undo_stack[#self.undo_stack + 1] = entry
    end
end

function KillerSudokuGame:canUndo()
    return self.undo_stack[1] ~= nil
end

function KillerSudokuGame:undo()
    local _ = require("gettext")
    local entry = table.remove(self.undo_stack)
    if not entry then
        return false, _("Nothing to undo.")
    end
    local row, col = entry.row, entry.col
    if entry.type == "value" then
        self.user[row][col] = entry.prev_value or 0
        self.notes[row][col] = self:cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
        self:recalcConflicts()
    elseif entry.type == "notes" then
        self.notes[row][col] = self:cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
    end
    return true
end

function KillerSudokuGame:toggleSolution()
    -- Removed - no solver
end

function KillerSudokuGame:isShowingSolution()
    return false
end

function KillerSudokuGame:checkWinCondition()
    -- Check all cells filled
    for r = 1, 9 do
        for c = 1, 9 do
            if self.user[r][c] == 0 then
                return false
            end
            if self.conflicts[r][c] then
                return false
            end
        end
    end
    
    -- Check all cage sums match
    for _, cage in ipairs(self.cages) do
        local sum = 0
        for _, cell in ipairs(cage.cells) do
            sum = sum + self.user[cell.row][cell.col]
        end
        if sum ~= cage.sum then
            return false
        end
    end
    
    return true
end

function KillerSudokuGame:getCageSum(row, col)
    local cage = self:getCage(row, col)
    if cage then
        return cage.sum
    end
    return nil
end

function KillerSudokuGame:getCageCurrentSum(row, col)
    local cage = self:getCage(row, col)
    if not cage then
        return nil
    end
    
    local sum = 0
    for _, cell in ipairs(cage.cells) do
        sum = sum + self.user[cell.row][cell.col]
    end
    return sum
end

function KillerSudokuGame:serialize()
    return {
        user = self:copyGrid(self.user),
        notes = self:copyNotes(self.notes),
        puzzle_id = self.puzzle_id,
        selected = {row = self.selected.row, col = self.selected.col},
    }
end

function KillerSudokuGame:deserialize(state)
    if not state or not state.puzzle_id then
        return
    end
    
    self.puzzle_id = state.puzzle_id
    
    -- Load puzzle structure
    self:loadPuzzleData(self.puzzle_id)
    
    if state.user then
        self.user = self:validateGrid(state.user, 9, 9) or self:createEmptyGrid(9, 9)
    end
    
    self.notes = self:copyNotes(state.notes)
    self.undo_stack = {}
    
    if state.selected then
        self.selected = {
            row = self:clamp(state.selected.row or 1, 1, 9),
            col = self:clamp(state.selected.col or 1, 1, 9),
        }
    else
        self.selected = {row = 1, col = 1}
    end
    
    self:recalcConflicts()
end

function KillerSudokuGame:buildCageAdjacency()
    -- adjacency[cage_num] = set of adjacent cage numbers
    local adjacency = {}
    
    for cage_num = 1, #self.cages do
        adjacency[cage_num] = {}
    end
    
    -- Check each cage against all others
    for i = 1, #self.cages do
        for j = i + 1, #self.cages do
            -- Check if cages i and j are adjacent
            local are_adjacent = false
            
            for _, cell_i in ipairs(self.cages[i].cells) do
                for _, cell_j in ipairs(self.cages[j].cells) do
                    local row_i, col_i = cell_i.row, cell_i.col
                    local row_j, col_j = cell_j.row, cell_j.col
                    
                    -- Check if cells share an edge (not diagonal)
                    local row_diff = math.abs(row_i - row_j)
                    local col_diff = math.abs(col_i - col_j)
                    
                    if (row_diff == 1 and col_diff == 0) or 
                       (row_diff == 0 and col_diff == 1) then
                        are_adjacent = true
                        break
                    end
                end
                if are_adjacent then break end
            end
            
            if are_adjacent then
                adjacency[i][j] = true
                adjacency[j][i] = true
            end
        end
    end
    
    return adjacency
end

function KillerSudokuGame:colorCages()
    local adjacency = self:buildCageAdjacency()
    local colors = {}  -- colors[cage_num] = color_number
    
    -- Color each cage with the smallest available color
    for cage_num = 1, #self.cages do
        -- Find colors used by adjacent cages
        local used_colors = {}
        for adj_cage, _ in pairs(adjacency[cage_num]) do
            if colors[adj_cage] then
                used_colors[colors[adj_cage]] = true
            end
        end
        
        -- Find smallest unused color
        local color = 1
        while used_colors[color] do
            color = color + 1
        end
        
        colors[cage_num] = color
    end
    
    self.cage_colors = colors
    return colors
end

return KillerSudokuGame