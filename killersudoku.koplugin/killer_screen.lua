-- killersudoku.koplugin/killer_screen.lua
-- Killer Sudoku game screen using kopuzzle framework

local PuzzleScreen = require("kopuzzle/core/puzzle_screen")
local KillerSudokuRenderer = require("killer_renderer")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local Device = require("device")
local _ = require("gettext")
local T = require("ffi/util").template

local KillerSudokuScreen = PuzzleScreen:extend{}

function KillerSudokuScreen:init()
    self.note_mode = false
    
    -- Create renderer
    self.renderer = KillerSudokuRenderer:new{
        game = self.game,
        onSelectionChanged = function()
            self:updateStatus()
        end,
    }
    
    -- Call parent init
    PuzzleScreen.init(self)
end

function KillerSudokuScreen:getInitialStatus()
    return _("Tap a cell, then pick a number.")
end

function KillerSudokuScreen:getTopButtons()
    return {
        {
            {
                text = _("⇐"),
                callback = function()
                    self:onPreviousPuzzle()
                end,
            },
            {
                text = _("⇒"),
                callback = function()
                    self:onNextPuzzle()
                end,
            },
            {
                text = _("Select puzzle"),
                callback = function()
                    self:openPuzzleSelector()
                end,
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

function KillerSudokuScreen:getActionButtons()
    local keypad_rows = {}
    local value = 1
    for _ = 1, 3 do
        local row = {}
        for _ = 1, 3 do
            local digit = value
            row[#row + 1] = {
                text = tostring(digit),
                callback = function()
                    self:onDigit(digit)
                end,
            }
            value = value + 1
        end
        keypad_rows[#keypad_rows + 1] = row
    end
    keypad_rows[#keypad_rows + 1] = {
        {
            id = "note_button",
            text = self:getNoteButtonText(),
            callback = function()
                self:toggleNoteMode()
            end,
        },
        {
            text = _("Erase"),
            callback = function()
                self:onErase()
            end,
        },
        {
            text = _("Check"),
            callback = function()
                self:checkSolution()
            end,
        },
        {
            id = "undo_button",
            text = _("Undo"),
            callback = function()
                self:onUndo()
            end,
        },
    }
    return keypad_rows
end

function KillerSudokuScreen:buildLayout()
    local Device = require("device")
    local Screen = Device.screen
    local VerticalGroup = require("ui/widget/verticalgroup")
    local VerticalSpan = require("ui/widget/verticalspan")
    local ButtonTable = require("ui/widget/buttontable")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local Size = require("ui/size")
    local Geom = require("ui/geometry")
    
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
    
    -- Create action buttons
    local action_buttons_config = self:getActionButtons()
    local action_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width = math.floor(Screen:getWidth() * 0.85),
        buttons = action_buttons_config,
    }
    self.action_buttons = action_buttons
    
    local layout_vertical_margin = Size.padding.large
    local top_buttons_height = top_buttons:getSize().h
    local status_height = self.status_text:getSize().h
    local action_height = action_buttons:getSize().h
    
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
    
    -- Use simple VerticalGroup instead of ScrollableContainer
    self.layout = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{width = Size.span.vertical_default},
        top_buttons,
        VerticalSpan:new{width = Size.span.vertical_default},
        board_frame,
        VerticalSpan:new{width = Size.span.vertical_default},
    }
    
    self[1] = self.layout
    self[2] = self.status_text
    self[3] = action_buttons
    
    -- Get button references
    self.note_button = action_buttons:getButtonById("note_button")
    self.undo_button = action_buttons:getButtonById("undo_button")
    
    self:updateNoteButton()
    self:updateUndoButton()
    self:updateStatus()
end

function KillerSudokuScreen:getNoteButtonText()
    return self.note_mode and _("Note: On") or _("Note: Off")
end

function KillerSudokuScreen:updateNoteButton()
    if not self.note_button then
        return
    end
    local width = self.note_button.width
    self.note_button:setText(self:getNoteButtonText(), width)
end

function KillerSudokuScreen:updateUndoButton()
    if not self.undo_button then
        return
    end
    self.undo_button:enableDisable(self.game:canUndo())
end

function KillerSudokuScreen:toggleNoteMode()
    self.note_mode = not self.note_mode
    self:updateNoteButton()
    self:updateStatus(self.note_mode and _("Note mode enabled.") or _("Note mode disabled."))
end

function KillerSudokuScreen:getPuzzleNumberText()
    return T(_("Puzzle #%1"), self.game.puzzle_id)
end

function KillerSudokuScreen:openPuzzleSelector()
    local input_dialog
    input_dialog = InputDialog:new{
        title = _("Enter puzzle number"),
        input = tostring(self.game.puzzle_id),
        input_type = "number",
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = _("Random"),
                    callback = function()
                        local random_id = math.random(1, self.game.max_puzzle_id)
                        self:loadPuzzle(random_id)
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = _("Load"),
                    is_enter_default = true,
                    callback = function()
                        local puzzle_id = tonumber(input_dialog:getInputText())
                        if puzzle_id and puzzle_id >= 1 and puzzle_id <= self.game.max_puzzle_id then
                            self:loadPuzzle(puzzle_id)
                        else
                            UIManager:show(InfoMessage:new{
                                text = T(_("Please enter a number between 1 and %1"), 
                                       self.game.max_puzzle_id),
                                timeout = 2,
                            })
                        end
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function KillerSudokuScreen:loadPuzzle(puzzle_id)
    self.game:generatePuzzle({puzzle_id = puzzle_id})
    self.plugin:saveState()
    self.renderer:refresh()
    self:updateUndoButton()
    self:updateStatus(T(_("Loaded puzzle #%1"), puzzle_id))
end

function KillerSudokuScreen:updateStatus(message)
    local status
    if message then
        status = message
    else
        local remaining = self.game:getRemainingCells()
        local row, col = self.game:getSelection()
        
        -- Get cage info
        local cage = self.game:getCage(row, col)
        local cage_info = ""
        if cage then
            local current_sum = self.game:getCageCurrentSum(row, col)
            cage_info = T(_(" · Cage: %1/%2"), current_sum, cage.sum)
        end
        
        status = T(_("Selected: %1,%2  · Empty: %3%4"), 
                  row, col, remaining, cage_info)
        
        if self.note_mode then
            status = status .. "\n" .. _("Note mode is ON.")
        end
    end
    PuzzleScreen.updateStatus(self, status)
end

function KillerSudokuScreen:onDigit(value)
    if self.note_mode then
        local ok, err = self.game:toggleNoteDigit(value)
        if not ok then
            self:updateStatus(err)
            return
        end
        self.renderer:refresh()
        self:updateStatus()
        self.plugin:saveState()
        self:updateUndoButton()
        return
    end
    
    local ok, err = self.game:setValue(value)
    if not ok then
        self:updateStatus(err)
        return
    end
    self.renderer:refresh()
    self:updateStatus()
    self.plugin:saveState()
    self:updateUndoButton()
end

function KillerSudokuScreen:onErase()
    local row, col = self.game:getSelection()
    self.game:clearNotes(row, col)
    local ok, err = self.game:setValue(nil)
    if not ok then
        self:updateStatus(err)
        return
    end
    self.renderer:refresh()
    self:updateStatus()
    self.plugin:saveState()
    self:updateUndoButton()
end

function KillerSudokuScreen:onNextPuzzle()
    -- Load next puzzle
    local next_id = self.game.puzzle_id + 1
    if next_id > self.game.max_puzzle_id then
        next_id = 1
    end
    self:loadPuzzle(next_id)
end

function KillerSudokuScreen:onPreviousPuzzle()
    -- Load previous puzzle
    local prev_id = self.game.puzzle_id - 1
    if prev_id < 1 then
        prev_id = self.game.max_puzzle_id
    end
    self:loadPuzzle(prev_id)
end

function KillerSudokuScreen:checkSolution()
    -- Check if puzzle is complete
    if self.game:checkWinCondition() then
        UIManager:show(InfoMessage:new{
            text = _("Congratulations! Puzzle solved correctly!"),
            timeout = 4
        })
        self:updateStatus(_("Puzzle complete!"))
    else
        -- Check for specific issues
        local remaining = self.game:getRemainingCells()
        if remaining > 0 then
            UIManager:show(InfoMessage:new{
                text = T(_("Not complete yet. %1 cells remain."), remaining),
                timeout = 3
            })
        else
            -- All cells filled but something is wrong
            local has_conflicts = false
            for r = 1, 9 do
                for c = 1, 9 do
                    if self.game:isConflict(r, c) then
                        has_conflicts = true
                        break
                    end
                end
                if has_conflicts then break end
            end
            
            if has_conflicts then
                UIManager:show(InfoMessage:new{
                    text = _("There are conflicts (duplicates in rows/columns/boxes/cages)."),
                    timeout = 3
                })
            else
                -- Check cage sums
                local wrong_sums = {}
                for _, cage in ipairs(self.game.cages) do
                    local sum = 0
                    for _, cell in ipairs(cage.cells) do
                        sum = sum + self.game.user[cell.row][cell.col]
                    end
                    if sum ~= cage.sum then
                        table.insert(wrong_sums, sum .. "≠" .. cage.sum)
                    end
                end
                
                if #wrong_sums > 0 then
                    UIManager:show(InfoMessage:new{
                        text = T(_("Some cage sums are incorrect (%1 cages)."), #wrong_sums),
                        timeout = 3
                    })
                end
            end
        end
    end
end

function KillerSudokuScreen:paintTo(bb, x, y)
    local Blitbuffer = require("ffi/blitbuffer")
    local Size = require("ui/size")
    
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    
    local top_offset = self.layout_vertical_margin or Size.padding.large
    local layout_size = self.layout:getSize()
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
        self.action_buttons.dimen = require("ui/geometry"):new{
            x = action_x,
            y = action_y,
            w = action_size.w,
            h = action_size.h
        }
        self.action_buttons:paintTo(bb, action_x, action_y)
    end
end

function KillerSudokuScreen:onUndo()
    local ok, err = self.game:undo()
    if not ok then
        self:updateStatus(err)
        return
    end
    self.renderer:refresh()
    self:updateStatus(_("Last move undone."))
    self.plugin:saveState()
    self:updateUndoButton()
end

return KillerSudokuScreen