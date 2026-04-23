# BTB 性能对比报告

测试程序：CoreMark (riscv32-npc, difftest ON)
测试时间：2026-04-23

## 数据汇总

| 指标                  | 无 BTB 基线  | BTB v1 (1-bit, 32-entry) | BTB v2 (bimodal, 64-entry) | BTB v3 (修复冲刷逻辑) |
|-----------------------|-------------|--------------------------|----------------------------|-----------------------|
| Total Cycles          | 3,842,004   | 3,903,730                | 3,904,657                  | 3,626,169             |
| Total Instructions    | 769,197     | 769,217                  | 769,219                    | 769,211               |
| IPC                   | 0.2002      | 0.1970                   | 0.1970                     | 0.2121                |
| CPI                   | 4.9948      | 5.0749                   | 5.0761                     | 4.7141                |
| Control Flow CPI      | 6.1304      | 6.3874                   | 6.3913                     | 5.0822                |
| BTB Predict           | 158,116     | 158,106                  | 158,105                    | 158,109               |
| BTB Mispredict        | 158,116     | 76,654                   | 63,696                     | 63,695                |
| BTB Accuracy          | 50.00%      | 67.35%                   | 71.28%                     | 71.28%                |

## 根本原因分析（v1/v2 性能反而下降）

`jump_req` 包含了 `ex_branch_taken`，导致**正确预测的跳转**在 EX 阶段也会冲刷流水线：

```
// 错误实现：
wire jump_req = global_trap_flush || ex_branch_taken || ex_mispredict;
```

时序分析（BTB 正确预测，错误实现）：
- Cycle 1: branch 在 IF，BTB 命中 → next_pc = btb_target
- Cycle 2: branch 在 ID，btb_target 在 IF
- Cycle 3: branch 在 EX，btb_target 在 ID
- Cycle 4: EX 确认跳转，**ex_branch_taken=1 → jump_req=1 → 冲刷 IF/ID**，重新取 btb_target
- Cycle 5: btb_target 重新在 IF（与无 BTB 完全相同！）

正确预测带来的 2 周期收益被 EX 阶段的冲刷完全抵消，还额外引入了误预测的冲刷开销。

## 修复方案（v3）

只在真正预测错误时冲刷，正确预测的跳转不触发冲刷：

```systemverilog
// 修复后：
wire jump_req = global_trap_flush || ex_mispredict;

assign next_pc = (wbu_trap_fire) ? mtvec :
                 (wbu_mret_fire) ? mepc  :
                 (ex_mispredict) ? (ex_branch_taken ? ex_branch_target : (id_ex_out.pc + 4)) :
                 (ras_hit)       ? ras_target :
                 (btb_hit)       ? btb_target_out :
                 (ifu_pc + 4);
```

修复后 Control Flow CPI 从 6.39 降至 5.08，总 CPI 从 4.99 降至 4.71（提升 5.6%）。
