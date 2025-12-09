-- killersudoku.koplugin/killer_renderer.lua
-- Killer Sudoku board renderer using kopuzzle framework

local GridRenderer = require("kopuzzle/components/grid/grid_renderer")
local Blitbuffer = require("ffi/blitbuffer")
local RenderText = require("ui/rendertext")
local Font = require("ui/font")
local Size = require("ui/size")
local Geom = require("ui/geometry")

local KillerSudokuRenderer = GridRenderer:extend{}

function KillerSudokuRenderer:init()
    GridRenderer.init(self)
    self.number_face = nil
    self.note_face = nil
    self.cage_face = nil
end

function KillerSudokuRenderer:updateMetrics()
    GridRenderer.updateMetrics(self)
    
    -- Set up fonts based on cell size
    local cell = self.cell_size
    self.number_face = Font:getFace("cfont", math.max(24, math.floor(cell / 2.8)))
    self.note_face = Font:getFace("smallinfofont", math.max(14, math.floor(cell / 8)))
    self.cage_face = Font:getFace("smallinfofont", math.max(12, math.floor(cell / 7)))
end

-- Helper to draw text in corner of cell
function KillerSudokuRenderer:drawCornerText(bb, x, y, w, h, face, text, color)
    local metrics = RenderText:sizeUtf8Text(0, h, face, text, true, false)
    
    -- Position in top-left with padding
    local padding = 2
    local text_x = x + padding
    local baseline = y + metrics.y_top + padding
    
    -- Draw subtle background
    local bg_w = metrics.x + padding
    local bg_h = metrics.y_top - metrics.y_bottom + padding
    bb:paintRect(text_x - 1, y + padding - 1, bg_w, bg_h, Blitbuffer.COLOR_WHITE)
    
    RenderText:renderUtf8Text(bb, text_x, baseline, face, text, true, false, color)
end

-- Helper to draw centered text
function KillerSudokuRenderer:drawCenteredText(bb, x, y, w, h, face, text, color)
    local metrics = RenderText:sizeUtf8Text(0, h, face, text, true, false)
    local text_x = x + math.floor((w - metrics.x) / 2)
    local baseline = y + math.floor((h + metrics.y_top - metrics.y_bottom) / 2)
    RenderText:renderUtf8Text(bb, text_x, baseline, face, text, true, false, color)
end

-- Determine which borders this cell needs for its cage
function KillerSudokuRenderer:getCageBorders(row, col)
    local current_cage = self.game:getCageNumber(row, col)
    
    if current_cage == 0 then
        return false, false, false, false
    end
    
    local top = false
    local right = false
    local bottom = false
    local left = false
    
    -- Check neighbors
    if row == 1 or self.game:getCageNumber(row - 1, col) ~= current_cage then
        top = true
    end
    
    if col == 9 or self.game:getCageNumber(row, col + 1) ~= current_cage then
        right = true
    end
    
    if row == 9 or self.game:getCageNumber(row + 1, col) ~= current_cage then
        bottom = true
    end
    
    if col == 1 or self.game:getCageNumber(row, col - 1) ~= current_cage then
        left = true
    end
    
    return top, right, bottom, left
end

function KillerSudokuRenderer:getCageColor(cage_num)
    if cage_num == 0 then
        return Blitbuffer.COLOR_WHITE
    end
    
    -- Use the computed color from game
    local color_num = self.game.cage_colors and self.game.cage_colors[cage_num] or 1
    
    local colors = {
        Blitbuffer.COLOR_WHITE,
        Blitbuffer.COLOR_GRAY_D,
        Blitbuffer.COLOR_GRAY_B,
        Blitbuffer.COLOR_GRAY_9,
        Blitbuffer.COLOR_GRAY_7,
    }
    
    -- Use modulo to wrap if we need more than 5 colors (rare)
    return colors[((color_num - 1) % #colors) + 1]
end

-- Check if this is the top-left cell of a cage (for displaying sum)
function KillerSudokuRenderer:isCageTopLeft(row, col, cage)
    if not cage then return false end
    
    local min_row = 10
    local min_col = 10
    
    for _, cell in ipairs(cage.cells) do
        if cell.row < min_row or (cell.row == min_row and cell.col < min_col) then
            min_row = cell.row
            min_col = cell.col
        end
    end
    
    return row == min_row and col == min_col
end

function KillerSudokuRenderer:drawDottedHorizontal(bb, xi, xf, y, dots, dotW, dotH, color)
    -- edge case: fewer than 2 dots makes no sense for "xi to xf"
    if dots < 2 then
        -- still draw one dot on xi
        bb:paintRect(xi, y, dotW, dotH, color)
        return
    end

    local L = xf - xi
    local segments = dots - 1   -- number of gaps
    local gap = (L - (dots * dotW)) / segments
    
    -- If gap becomes negative, dots cannot fit → compress gap to zero.
    -- This keeps behavior stable rather than silently breaking.
    if gap < 0 then gap = 0 end

    for i = 0, dots - 1 do
        -- Position of dot i
        local x = xi + i * (dotW + gap)
        bb:paintRect(math.floor(x + 0.5), y, dotW, dotH, color)
    end
end

function KillerSudokuRenderer:drawDottedVertical(bb, x, yi, yf, dots, dotW, dotH, color)
    -- trivial case
    if dots < 2 then
        bb:paintRect(x, yi, dotW, dotH, color)
        return
    end

    local L = yf - yi
    local segments = dots - 1
    local gap = (L - (dots * dotH)) / segments

    -- If dots don't fit, collapse the gap to 0 instead of breaking
    if gap < 0 then gap = 0 end

    for i = 0, dots - 1 do
        local y = yi + i * (dotH + gap)
        bb:paintRect(x, math.floor(y + 0.5), dotW, dotH, color)
    end
end



function KillerSudokuRenderer:paintCell(bb, x, y, size, row, col)
    local value = self.game:getDisplayValue(row, col)
    local cage_num = self.game:getCageNumber(row, col)
    local cage = self.game:getCage(row, col)

    
    -- Background color based on cage
    local bg_color = self:getCageColor(cage_num)
    bb:paintRect(x, y, size, size, bg_color)
    
    local sel_row, sel_col = self.game:getSelection()
    if row == sel_row and col == sel_col then
        local selection_size = size * (7/10)
        local cx = x + math.floor((size - selection_size) / 2)
        local cy = y + math.floor((size - selection_size) / 2) - 1
        --local cx = x + size/2 - selection_size/2
        --local cy = y + size/2 - selection_size/2
        bb:paintBorder(cx, cy, selection_size, selection_size, 2, Blitbuffer.COLOR_BLACK, 10, 1)
    end

    -- Draw cage borders with dotted style (subtle)
    local top, right, bottom, left = self:getCageBorders(row, col)
    
    -- Dotted line parameters
    local dot_size = 5
    local dot_amount = 8
    local dot_thickness = 3


    local indentation = 5
    local border_color = Blitbuffer.COLOR_BLACK
    
    if top or bottom then
        -- Draw dotted horizontal line at top
        local dotW = dot_size
        local dotH = dot_thickness

        local xi 
        if not left then xi = x + dotW/2
        else xi = x + indentation end

        local xf 
        if not right then xf = x + size - dotW/2
        else xf = x + size - indentation * 2 end

        local yp_top = y + indentation
        local yp_bottom = y + size - indentation * 2

        if top then
            self:drawDottedHorizontal(bb, xi, xf, yp_top, dot_amount, dotW, dotH, border_color)
        end
        if bottom then
            self:drawDottedHorizontal(bb, xi, xf, yp_bottom, dot_amount, dotW, dotH, border_color)
        end
    end
    
    if left or right then
        local dotW = dot_thickness
        local dotH = dot_size

        local yi
        if not top then yi = y + dotH/2
        else yi = y + indentation end

        local yf
        if not bottom then yf = y + size - dotH/2
        else yf = y + size - indentation * 2 end

        local xp_left = x + indentation
        local xp_right = x + size - indentation * 2

        if left then
            self:drawDottedVertical(bb, xp_left, yi, yf, dot_amount, dotW, dotH, border_color)
        end
        if right then
            self:drawDottedVertical(bb, xp_right, yi, yf, dot_amount, dotW, dotH, border_color)
        end
    end
    
    -- Draw cage sum in top-left cell of cage
    if self:isCageTopLeft(row, col, cage) and cage then
        local sum_text = tostring(cage.sum)
        self:drawCornerText(bb, x, y, size, size, self.cage_face, 
                           sum_text, Blitbuffer.COLOR_GRAY_4)
    end
    
    -- Draw the digit or notes
    if value then
        local color = Blitbuffer.COLOR_BLACK
        
        if self.game:isConflict(row, col) then
            color = Blitbuffer.COLOR_RED
        end
        
        local text = tostring(value)
        self:drawCenteredText(bb, x, y, size, size, self.number_face, text, color)
    else
        -- Draw notes
        local notes = self.game:getCellNotes(row, col)
        if notes then
            local scale = 0.6       
            local note_area = size * scale
            local mini = note_area / 3
            local offset = (size - note_area) / 2
            for digit = 1, 9 do
                if notes[digit] then
                    
                    local mini_col = (digit - 1) % 3
                    local mini_row = math.floor((digit - 1) / 3)
                    local mini_x = x + offset + mini_col * mini
                    local mini_y = y + offset + mini_row * mini + offset / 3

                    local note_text = tostring(digit)
                    self:drawCenteredText(bb, mini_x, mini_y, mini, mini, 
                                         self.note_face, note_text, Blitbuffer.COLOR_GRAY_4)
                end
            end
        end
    end
end

function KillerSudokuRenderer:paintGrid(bb, x, y)
    local cell = self.cell_size    
    
    -- Draw cells (this includes dotted cage borders)
    for row = 1, 9 do
        for col = 1, 9 do
            local cell_x = x + (col - 1) * cell
            local cell_y = y + (row - 1) * cell
            self:paintCell(bb, cell_x, cell_y, cell, row, col)
        end
    end

    
    -- Draw main sudoku grid with PROMINENT 3x3 box lines
    local thin = Size.line.thin
    local thick = Size.line.thick * 1.5  -- Make 3x3 borders even thicker
    
    for i = 0, 9 do
        local is_box_line = (i % 3 == 0)
        local thickness = is_box_line and thick or thin
        local grid_color = is_box_line and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_GRAY_C
        
        -- Vertical lines
        local x_pos = x + math.floor(i * cell) - thickness / 2
        bb:paintRect(x_pos, y, thickness, 9 * cell, grid_color)
        
        -- Horizontal lines
        local y_pos = y + math.floor(i * cell) - thickness / 2
        bb:paintRect(x, y_pos, 9 * cell + thickness / 2, thickness, grid_color)
    end

end

return KillerSudokuRenderer