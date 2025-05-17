#include <common.h>
#include <npc.h>

int is_exit_status_bad() {
  int state = npc.get_state();
  int good = (state == STATE_QUIT) || (state == STATE_GOOD_TRAP);
  return !good;
}
