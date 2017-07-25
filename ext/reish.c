
#include <unistd.h>

#include "ruby.h"
#include "ruby/io.h"

VALUE rb_mReish;

static ID id_to_i;


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

#define PST2INT(st) NUM2INT(pst_to_i(st))

static VALUE
reish_wifscontinued(VALUE obj, VALUE st)
{
  int status = NUM2INT(rb_funcall(st, id_to_i, 0));

  if (WIFCONTINUED(status))
    return Qtrue;
  else
    return Qfalse;
}


void
Init_reish()
{

  id_to_i = rb_intern("to_i");
  
  rb_mReish = rb_define_module("Reish");

  rb_define_const(rb_mReish, "WCONTINUED", INT2FIX(WCONTINUED));

  rb_define_module_function(rb_mReish, "tcgetpgrp", reish_tcgetpgrp, 1);
  rb_define_module_function(rb_mReish, "tcsetpgrp", reish_tcsetpgrp, 2);

  rb_define_module_function(rb_mReish, "wifscontined?", reish_wifscontinued, 1);
}



