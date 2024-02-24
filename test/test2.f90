module mod_test2
  use other, only: y

contains

  subroutine sub2
    integer :: x
    call y()
  end subroutine sub2

end module
