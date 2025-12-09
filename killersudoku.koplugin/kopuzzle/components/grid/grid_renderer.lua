-- kopuzzle/components/grid/grid_renderer.lua
-- Grid-based puzzle renderer component

local PuzzleRenderer = require("kopuzzle/core/puzzle_renderer")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local Size = require("ui/size")
local Device = require("device")
local Screen = Device.screen

local GridRenderer = PuzzleRenderer:extend{
    cell_size = 30,
    grid_origin_x = 0,
    grid_origin_y = 0,
}

function GridRenderer:updateMetrics()
    if not self.game then
        return
    end
    
    local rows = self.game.rows or 0
    local cols = self.game.cols or 0
    
    local target_w = self.max_width or math.floor(Screen:getWidth() * 0.9)
    local target_h = self.max_height or math.floor(Screen:getHeight() * 0.9)
    
    local cell_size = math.floor(math.min(
        target_w / math.max(1, cols),
        target_h / math.max(1, rows)
    ))
    
    cell_size = math.max(20, cell_size)
    
    self.cell_size = cell_size
    self.total_width = cols * cell_size
    self.total_height = rows * cell_size
    self.grid_origin_x = self.paint_rect.x
    self.grid_origin_y = self.paint_rect.y
    self.dimen = Geom:new{w = self.total_width, h = self.total_height}
end

function GridRenderer:getCellFromPoint(x, y)
    if not self.grid_origin_x then
        return nil
    end
    
    local cell = self.cell_size
    if cell <= 0 then
        return nil
    end
    
    local local_x = x - self.grid_origin_x
    local local_y = y - self.grid_origin_y
    
    if local_x < 0 or local_y < 0 then
        return nil
    end
    
    local col = math.floor(local_x / cell) + 1
    local row = math.floor(local_y / cell) + 1
    
    if row < 1 or row > self.game.rows or col < 1 or col > self.game.cols then
        return nil
    end
    
    return row, col
end

function GridRenderer:onTap(_, ges)
    if not (ges and ges.pos) then
        return false
    end
    
    local row, col = self:getCellFromPoint(ges.pos.x, ges.pos.y)
    if not row then
        return false
    end
    
    self.game:setSelection(row, col)
    
    if self.onSelectionChanged then
        self.onSelectionChanged(row, col)
    end
    
    if self.onCellActivated then
        self.onCellActivated(row, col)
    end
    
    self:refresh()
    return true
end

function GridRenderer:paintGrid(bb, x, y)
    local cell = self.cell_size
    local rows = self.game.rows
    local cols = self.game.cols
    local sel_row, sel_col = self.game:getSelection()
    
    -- Draw cells
    for row = 1, rows do
        for col = 1, cols do
            local cell_x = x + (col - 1) * cell
            local cell_y = y + (row - 1) * cell
            
            -- Background
            local bg_color = Blitbuffer.COLOR_WHITE
            if row == sel_row and col == sel_col then
                bg_color = Blitbuffer.COLOR_GRAY
            end
            bb:paintRect(cell_x, cell_y, cell, cell, bg_color)
            
            -- Cell content (override this method to customize)
            self:paintCell(bb, cell_x, cell_y, cell, row, col)
        end
    end
    
    -- Draw grid lines
    local thick = Size.line.thick
    local thin = Size.line.thin
    
    for i = 0, rows do
        local y0 = y + i * cell
        local thickness = (i % 5 == 0) and thick or thin
        bb:paintRect(x, y0, cols * cell, thickness, Blitbuffer.COLOR_BLACK)
    end
    
    for i = 0, cols do
        local x0 = x + i * cell
        local thickness = (i % 5 == 0) and thick or thin
        bb:paintRect(x0, y, thickness, rows * cell, Blitbuffer.COLOR_BLACK)
    end
end

function GridRenderer:paintCell(bb, x, y, size, row, col)
    -- Override this method in subclass to customize cell rendering
    local value = self.game:getCellState(row, col)
    if value and value ~= 0 then
        bb:paintRect(x + 2, y + 2, size - 4, size - 4, Blitbuffer.COLOR_GRAY_4)
    end
end

function GridRenderer:paintTo(bb, x, y)
    self.paint_rect = Geom:new{
        x = x,
        y = y,
        w = self.total_width or 10,
        h = self.total_height or 10
    }
    self:updateMetrics()
    self.paint_rect.w = self.total_width
    self.paint_rect.h = self.total_height
    
    bb:paintRect(x, y, self.total_width, self.total_height, Blitbuffer.COLOR_WHITE)
    self:paintGrid(bb, x, y)
end

return GridRenderer