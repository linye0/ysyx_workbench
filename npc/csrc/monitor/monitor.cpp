#include "difftest.h"
#include <common.h>
#include <getopt.h>
#include <sdb.h>
#include <memory.h>

static const uint32_t img[] = {
    0x00108093, // 80000000: addi ra, ra, 1
    0x00108093, // 80000004: addi ra, ra, 1
    0x00108093, // 80000008: addi ra, ra, 1
    0x00108093, // 8000000c: addi ra, ra, 1
    0x00108093, // 80000010: addi ra, ra, 1
    0x00000117, // 80000014: auipc sp,0x0
    0x00100513, // 80000018: addi 0, zero, 1
    0x00a12023, // 8000001c: sw	a0,0(sp)
    0x00a12023, // 80000020: sw	a0,0(sp)
    0x00a12023, // 80000024: sw	a0,0(sp)
    0x00012483, // 80000028: lw	s1,0(sp)
    0x00012483, // 8000002c: lw	s1,0(sp)
    0x00000513, // 80000030: addi 0, zero, 0
    // ebreak;          0b0000000 00001 00000 000 00000 11100 11;
    0b00000000000100000000000001110011,
};

static const uint32_t img_char_test[] = {
    0x00000117, // 80000000: auipc sp,0x0
    0x0080016f, // 80000004: jal sp, 0x8
    0x04100713, // 80000008: addi a4, zero, 0x41
    0x04100713, // 8000000c: addi a4, zero, 0x41
    0x00000463, // 80000010: beq a0, x0, 0x8
    0x00000117, // 80000014: auipc sp,0x0
    0x00012483, // 80000018: lw	s1,0(sp)
    0x04100713, // 8000001c: addi a4, zero, 0x41
    0x100007b7, // 80000020: lui a5, 0x10000
    0x00000117, // 80000024: auipc sp,0x0
    0x00a00713, // 80000028: addi a4, zero, 0x0a
    0x00a00713, // 8000002c: addi a4, zero, 0x0a
    0x00a00713, // 80000030: addi a4, zero, 0x0a
    0x00a00713, // 80000034: addi a4, zero, 0x0a
    0xdf002117, // 80000038: auipc sp, -135166
    0xffc10113, // 8000003c: addi sp, sp, -4
    0xff410113, // 80000040: addi sp, sp, -12
    0x00a00713, // 80000044: addi a4, zero, 0x0a
    0x00a00713, // 80000048: addi a4, zero, 0x0a
    0x00a00713, // 8000004c: addi a4, zero, 0x0a
    0x00100073, // 80000050: ebreak
};

static void welcome() {
	printf("Welcome to npc!\n");
}

static char* img_file = NULL;
static char* elf_file = NULL;
static char* log_file = NULL;
static char* ref_so_file = NULL;

void parse_elf(const char* elf_file);
void sdb_set_batch_mode();
void init_log(const char *log_file);
void init_disasm();
void init_sdb(int argc, char** argv);


long load_file(const char *filename, void *buf)
{
  FILE *fp = fopen(filename, "rb");
  assert(fp != NULL);

  fseek(fp, 0, SEEK_END);
  long size = ftell(fp);

  Log("image: %s, size: %ld", filename, size);

  fseek(fp, 0, SEEK_SET);
  int ret = fread(buf, size, 1, fp);
  assert(ret == 1);

  fclose(fp);
  return size;
}

static long load_img()
{
  long size;
  // Load image to memory
  if (img_file == NULL)
  {
    Log("No image is given, use default image.");
    memcpy(guest_to_host(MBASE), img, sizeof(img));
    size = sizeof(img);
  }
  else
  {
    size = load_file(img_file, guest_to_host(MBASE));
    // load_file(img_file, guest_to_host(FLASH_BASE));
  }
  return size;
}


static int parse_args(int argc, char *argv[]) {
	const struct option table[] = {
		{"img", required_argument, NULL, 'i'},
		{"elf", required_argument, NULL, 'e'},
		{"batch", no_argument, NULL, 'b'},
    {"diff", required_argument, NULL, 'd'},
	};
	int o;
	while ((o = getopt_long(argc, argv, "-bi:e:d:", table, NULL)) != -1) {
		switch (o) {
      case 'b': sdb_set_batch_mode(); break;
      case 'd': ref_so_file = optarg; break;
			case 'i': img_file = optarg; break;
			case 'e': elf_file = optarg; break;	
			default:
					printf("read argument error\n");
					exit(0);
		}
	}
	return 0;
}

void init_monitor(int argc, char* argv[]) {
	parse_args(argc, argv);

	init_log("npc-log.log");

  long img_size = load_img();

	init_sdb(argc, argv);

	parse_elf(elf_file);

  printf("ref_so_file: %s\n", ref_so_file);

  init_difftest(ref_so_file, img_size, 0);

  #ifdef CONFIG_ITRACE
  init_disasm();
  #endif

	welcome();
}
