# Fortran Vim Plugin

This repository provides a Vim plugin for Fortran developers. In its current version, it can be used to jump to the declaration
of a variable, subroutine, function, etc. and to all its references. All related files must either be part of a Git repository or
inside the current working directory.

This plugin calls [fortls](https://github.com/fortran-lang/fortls) under the hood.

## Installation

1. Install `vim-plug` if you do not have it yet. See installation instructions [here](https://github.com/junegunn/vim-plug?tab=readme-ov-file#installation).

2. Add the following lines to your `.vimrc` file:
```
call plug#begin()
Plug 'terminationshock/fortran-vim-plugin'
call plug#end()
```

3. Re-open Vim and run `:PlugInstall`.

4. Install further Python packages with `pip install GitPython fortls`.

5. Run `fortls -v` to verify that the language server is ready.

## Usage

Open any Fortran file and move the cursor onto an entity name (for example, a variable or a subroutine).
Press `F3` to navigate to its declaration. Press `F4` to see all references.

## Update

To fetch the latest version of this plugin, run `:PlugUpdate`.
