# Killer Sudoku Plugin for KOReader

This plugin adds a fully playable Killer Sudoku game to KOReader. It lets you load one of tens of thousands of puzzles from a bundled database and solve it directly on your device using a simple keypad interface.

Contributions, fixes, and puzzle database improvements are welcome.  
Please submit issues or pull requests through the GitHub repository.

<img src="/images/completedExample.png" alt="drawing" width="300"/>
## Overview

The plugin loads puzzles from a pre-built database of **56,615** Killer Sudoku grids. These puzzles come from the public dataset maintained at:  
[https://github.com/UvA-KR16/KilerSudoku](https://github.com/UvA-KR16/KilerSudoku)

The puzzles contain **no initial digits**. Each puzzle is still **uniquely solvable through cage constraints and standard Killer Sudoku logic**, without requiring pre-filled numbers.

The game interface supports pencil marks, full solve checking. There are no hints or aids beyond that.
## Installation

1. Download the release zip containing the plugin `killersudoku.koplugin` and the required database files inside the folder (`puzzles.bin` and `index.bin`).
    
2. Move the `killersudoku.koplugin` folder into KOReader’s `plugins/` directory.
    
3. Restart KOReader if needed.
    
4. The plugin will appear under **Tools** as **Killer Sudoku**.
    

The plugin has been tested on KOReader **2025.10** on a Kindle PW5, and requires the bundled binary puzzle database to function.
## Usage

### Selecting a Puzzle

Open the plugin and choose a puzzle in one of two ways:

- Tap **Select puzzle** to enter a puzzle number between 1 and the maximum available (56,615 for the included index).
    
- Tap **Random** to load a randomly selected puzzle.
    

<img src="/images/loadPuzzle.png" alt="drawing" width="300"/>

### Entering Numbers

Tap a cell to select it, then use the keypad to enter a digit.  
If **Note** mode is enabled, the digit is added as a pencil mark instead of a full entry.

<img src="/images/loaded.png" alt="drawing" width="300"/>
<img src="/images/notes.png" alt="drawing" width="300"/>
### Checking Progress

A **Check** button is available to validate the current grid. It reports whether the puzzle is complete or if inconsistencies are present.

<img src="/images/conflicts.png" alt="drawing" width="300"/>
<img src="/images/completed.png" alt="drawing" width="300"/>
<img src="/images/notCompleted.png" alt="drawing" width="300"/>
### Saving Progress

Progress is preserved **only while the current puzzle remains loaded**.  
Switching to another puzzle discards the ongoing one. There is no long-term puzzle archive as of now.

### Undo and Erase

- **Undo** reverses the last action.
    
- **Erase** clears the selected cell.
    
## Features

- 56k+ Killer Sudoku puzzles
    
- Pencil marks
    
- Error checking
    
- No hints
    
- No given digits (logic-complete puzzles)
    
- Simple keypad-based input
    
- Fast puzzle loading from binary index

## Building a Database

### Plain Puzzles
Inside the `killersudoku_database/plain` you will find a plain text database of killer sudoku puzzles, adding more puzzles requires following the structure in these files:

`<Cage sum> <RowColumn> <RowColumn> <RowColumn> ...`

For example:
`10 01 02 10`

Is a cage of sum 10 and its cells are (0, 1), (0, 2) and (1, 0)

### Binary and module
Inside the `killersudoku_database/lua` you will find a precompiled binary database

### Making a binary database
To make a binary puzzle database for the killersudoku plugin just make plain killersudoku files inside the `plain` directory and run the python script. Then, you can replace the `puzzles.bin` and `index.bin` files in the plugin directory (If you have difficulties with this please contact me via my reddit or tomasjdle@gmail.com)
## License

This plugin is released under the **GPLv3**, the same license used by KOReader.