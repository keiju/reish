
#include <unistd.h>

#include "ruby.h"
#include "ruby/io.h"

VALUE rb_mReish;

static VALUE
reish_tcgetpgrp(VALUE obj, VALUE io)
{
  VALUE tmp;
  rb_pid_t pid;
  rb_io_t *fptr;

  if(NIL_P(tmp = rb_check_convert_type(io, T_FILE, "IO", "to_io"))) {
    rb_raise(rb_eTypeError, "instance of IO needed");
  }
  GetOpenFile(tmp, fptr);

  pid = tcgetpgrp(fptr->fd);
  if (pid < 0) rb_sys_fail(0);
  return PIDT2NUM(pid);
}


static VALUE
reish_tcsetpgrp(VALUE obj, VALUE io, VALUE pid)
{
  VALUE tmp;
  rb_io_t *fptr;
  int ret;

  if(NIL_P(tmp = rb_check_convert_type(io, T_FILE, "IO", "to_io"))) {
    rb_raise(rb_eTypeError, "instance of IO needed");
  }
  GetOpenFile(tmp, fptr);

  ret = tcsetpgrp(fptr->fd, NUM2PIDT(pid));
  if (ret < 0) rb_sys_fail(0);
  return io;
}


void
Init_reish()
{
  rb_mReish = rb_define_module("Reish");

  rb_define_module_function(rb_mReish, "tcgetpgrp", reish_tcgetpgrp, 1);
  rb_define_module_function(rb_mReish, "tcsetpgrp", reish_tcsetpgrp, 2);

}



