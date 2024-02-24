if exists("g:loaded_fortran_plugin")
    finish
endif
let g:loaded_fortran_plugin = 1

nmap <F4> :call fortran#Fortran()<CR>
