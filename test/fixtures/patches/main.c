#include <dep.h>

int
main() {
  return dep_patched() == 2 ? 0 : 1;
}
