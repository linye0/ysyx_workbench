/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#ifndef __ISA_RISCV_H__
#define __ISA_RISCV_H__

#include <common.h>

// RISC-V privilege levels
enum PRV
{
  PRV_U = 0,
  PRV_S = 1,
  PRV_M = 3,
};

enum CSR
{
  // Supervisor-level CSR
  CSR_SSTATUS = 0x100,
  CSR_SIE = 0x104,
  CSR_STVEC = 0x105,

  CSR_SCOUNTEREN = 0x106,

  CSR_SSCRATCH = 0x140,
  CSR_SEPC = 0x141,
  CSR_SCAUSE = 0x142,
  CSR_STVAL = 0x143,
  CSR_SIP = 0x144,
  CSR_SATP = 0x180,

  // Machine Trap Settup
  CSR_MSTATUS = 0x300,
  CSR_MISA = 0x301,
  CSR_MEDELEG = 0x302,
  CSR_MIDELEG = 0x303,
  CSR_MIE = 0x304,
  CSR_MTVEC = 0x305,

  CSR_MSTATUSH = 0x310,

  // Machine Trap Handling
  CSR_MSCRATCH = 0x340,
  CSR_MEPC = 0x341,
  CSR_MCAUSE = 0x342,
  CSR_MTVAL = 0x343,
  CSR_MIP = 0x344,

  CSR_MCYCLE = 0xb00,
  CSR_MCYCLEH = 0xb80,
  CSR_CYCLE_ = 0xc00,
  CSR_TIME = 0xc01,
  CSR_TIMEH = 0xc81,

  // Machine Information Registers
  CSR_MVENDORID = 0xf11,
  CSR_MARCHID = 0xf12,
  CSR_IMPID = 0xf13,
  CSR_MHARTID = 0xf14,
};

#if defined(CONFIG_RV64)
#error "RV64 is not supported"
#define XLEN 64
#else
#define XLEN 32
// !important: only Little-Endian is supported
typedef union
{
  struct
  {
    word_t rev1 : 1;
    word_t sie : 1;
    word_t rev2 : 1;
    word_t mie : 1;
    word_t rev3 : 1;
    word_t spie : 1;
    word_t ube : 1;
    word_t mpie : 1;
    word_t spp : 1;
    word_t vs : 2;
    word_t mpp : 2;
    word_t fs : 2;
    word_t xs : 2;
    word_t mprv : 1;
    word_t sum : 1;
    word_t mxr : 1;
    word_t tvm : 1;
    word_t tw : 1;
    word_t tsr : 1;
    word_t rev4 : 8;
    word_t sd : 1;
  } mstatus;
  struct
  {
    word_t ppn : 22;
    word_t asid : 9;
    word_t mode : 1;
  } satp;
  struct
  {
    word_t rev1 : 1;
    word_t ssie : 1;
    word_t rev2 : 3;
    word_t stie : 1;
    word_t rev3 : 3;
    word_t seie : 1;
    word_t rev4 : 3;
    word_t lcofie : 1;
  } sie;
  struct
  {
    word_t rev1 : 1;
    word_t ssie : 1;
    word_t rev2 : 3;
    word_t stie : 1;
    word_t vstie : 1;
    word_t mtie : 1;
    word_t rev3 : 1;
    word_t seie : 1;
    word_t vseie : 1;
    word_t mteie : 1;
    word_t sgeie : 1;
    word_t lcofie : 1;
  } mie;
  word_t val;
} csr_t;
#endif

// Machine cause register (mcause) values after trap.
enum MCAUSE
{
  MCA_SUP_SOF_INT = 0x1 | (1 << (XLEN - 1)),
  MCA_MAC_SOF_INT = 0x3 | (1 << (XLEN - 1)),

  MCA_SUP_TIM_INT = 0x5 | (1 << (XLEN - 1)),
  MCA_MAC_TIM_INT = 0x7 | (1 << (XLEN - 1)),

  MCA_SUP_EXT_INT = 0x9 | (1 << (XLEN - 1)),
  MCA_MAC_EXT_INT = 0xb | (1 << (XLEN - 1)),

  MCA_COU_OVE_INT = 0xd | (1 << (XLEN - 1)),

  MCA_INS_ADD_MIS = 0x0,
  MCA_INS_ACC_FAU = 0x1,
  MCA_ILLEGAL_INS = 0x2,

  MCA_BREAK_POINT = 0x3,

  MCA_LOA_ADD_MIS = 0x4,
  MCA_LOA_ACC_FAU = 0x5,
  MCA_STO_ADD_MIS = 0x6,
  MCA_STO_ACC_FAU = 0x7,

  MCA_ENV_CAL_UMO = 0x8,
  MCA_ENV_CAL_SMO = 0x9,

  MCA_ENV_CAL_MMO = 0xb,
  MCA_INS_PAG_FAU = 0xc,
  MCA_LOA_PAG_FAU = 0xd,

  MCA_STO_PAG_FAU = 0xf,

  MCA_SOF_CHE = 0x12,
  MCA_HAR_ERR = 0x13,
};

typedef struct {
  word_t gpr[MUXDEF(CONFIG_RVE, 32, 16)];
  vaddr_t pc;
  word_t sr[4096];
  uint32_t priv;
  uint32_t last_inst_priv;
} MUXDEF(CONFIG_RV64, riscv64_CPU_state, riscv32_CPU_state);

// decode
typedef struct {
  uint32_t inst;
} MUXDEF(CONFIG_RV64, riscv64_ISADecodeInfo, riscv32_ISADecodeInfo);

#define isa_mmu_check(vaddr, len, type) (MMU_DIRECT)

#endif
