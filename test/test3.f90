module mod_test3
  use mod_test1, only: type_b

  type type_c
    type(type_b) :: b
    contains
      procedure :: subc
  end type

contains

  subroutine sub3
    type(type_c) :: c
    c%b%J = 0
  end subroutine sub3

end module
