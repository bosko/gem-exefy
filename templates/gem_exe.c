#include "ruby.h"
#include <stdlib.h>

#ifdef HAVE_LOCALE_H
#include <locale.h>
#endif

#ifndef MAXPATHLEN
# define MAXPATHLEN 1024
#endif

void
dump_args(int argc, char **argv)
{
  int i;
  printf("Number of arguments: %d\n", argc);

  for (i = 0; i < argc; ++i)
    printf("Argument %d: %s\n", i, argv[i]);

  printf("=================\n");
}

int
main(int argc, char **argv)
{
  int i;
  int myargc;
  char** myargv;
  char script_path[MAXPATHLEN];
  char* dump_val;
  DWORD attr;

#ifdef HAVE_LOCALE_H
  setlocale(LC_CTYPE, "");
#endif

  dump_val = getenv("EXEFY_DUMP");

  if (GetModuleFileName(NULL, script_path, MAXPATHLEN)) {
    for (i = strlen(script_path) - 1; i >= 0; --i) {
      if (*(script_path + i) == '.') {
        *(script_path + i) = '\0';
        break;
      }
    }

    attr = GetFileAttributes(script_path);
    if (attr == INVALID_FILE_ATTRIBUTES) {
      printf("Script %s is missing!", script_path);
      return -1;
    }
    // Let Ruby initialize program arguments
    ruby_sysinit(&argc, &argv);

    // Change arguments by inserting path to script file
    // as second argument (first argument is always executable
    // name) and copying arguments from command line after it.
    myargc = argc + 1;
    myargv = (char**)xmalloc(sizeof(char*) * (myargc + 1));
    if (NULL != myargv) {
      memset(myargv, 0, sizeof(char*) * (myargc + 1));
      *myargv = *argv;
      *(myargv + 1) = &script_path[0];

      for (i = 1; i < argc; ++i) {
         *(myargv + i + 1) = *(argv + i);
      }

      if (NULL != dump_val) {
        dump_args(myargc, myargv);
      }

      {
        RUBY_INIT_STACK;
        ruby_init();
        return ruby_run_node(ruby_options(myargc, myargv));
      }
    }
    else {
      printf("Not enough memory to continue. Exiting...");
    }
  }

  // Return an error when nothing works
  return -1;
}
