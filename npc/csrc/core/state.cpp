#include <common.h>
#include <npc.h>

extern NPCState npc;

int is_exit_status_bad() {
  int state = npc.state;
  int good = (state == NPC_END) || (state == NPC_QUIT);
  return !good;
}
