#include <am.h>
#include <klib.h>
#include <klib-macros.h>

int main() {
  for (int i = 0; i < 10; i ++) {
    putstr("Hello, AM World @ " __ISA__ "\n");
  }
  return 0;
}
