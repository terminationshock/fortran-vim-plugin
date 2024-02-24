# Fortran Vim Plugin

This repository provides a Vim plugin for Fortran developers. In its current version, it can be used to jump to the declaration
of a variable, subroutine, function, etc. in a complex software project. All related files must either be part of a Git repository or
inside the current working directory.

## Installation

1. Install `vim-plug` if you do not have it yet. See installation instructions [here](https://github.com/junegunn/vim-plug?tab=readme-ov-file#installation).

2. Add the following lines to your `.vimrc` file:
```
call plug#begin()
Plug 'terminationshock/fortran-vim-plugin'
call plug#end()
```

3. Re-open Vim and run `:PlugInstall`.

4. Install further Python packages with `pip install GitPython lxml`.

## Usage

Open any Fortran file and move the cursor onto an entity name (for example, a variable).
By default, the plugin is bound to the key `F4`. Press it to navigate to the matching declaration.

## Update

To fetch the latest version of this plugin, run `:PlugUpdate`.

## Tests

Tests have been implemented for this plugin. Go to the `test` directory and run `./run_tests.py`.
