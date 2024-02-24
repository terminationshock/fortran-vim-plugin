module mod_test1

  use mod_test2, only: sub2
  use mod_test3

  type type_B
    integer :: j
    contains
      procedure :: subb => subb_
  end type

contains

  subroutine sub1
    type(type_a) :: a
    type(type_b) :: b
    integer :: i

    call a%suba()
    i = fun(b%j)
    call b%subb()
  end subroutine sub1

  function fun(x)
    integer :: x
    real :: fun

    call sub2()
    call sub3()
  end function fun

  subroutine subb_
    type(type_c) :: c
    call c%subc()
  end subroutine subb_

end module mod_test1
