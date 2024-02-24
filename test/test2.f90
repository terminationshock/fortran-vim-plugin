module mod_test2
  use other, only: y
  use mod_test3

contains

  subroutine sub2
    integer :: x
    type(type_c) :: cc
    call y()
    call cc%subc3()
  end subroutine sub2

end module
