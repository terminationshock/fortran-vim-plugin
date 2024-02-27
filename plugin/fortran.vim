if exists("g:loaded_fortran_plugin")
    finish
endif
let g:loaded_fortran_plugin = 1

nmap <F3> :call fortran#FindDefinition()<CR>
nmap <F4> :call fortran#FindReferences()<CR>
