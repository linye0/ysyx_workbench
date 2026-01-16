# ICache 形式化验证使用指南

## 概述

本目录包含了对 `ysyx_25040131_icache` 模块进行形式化验证的代码和配置文件。

**验证目标**：证明 icache 的行为与直接访问存储器的行为一致。

**验证方法**：
- **REF（参考模型）**：直接从 mem 读取数据（0延迟，组合逻辑）
- **DUT（待测设计）**：通过 icache 访问 mem（有 cache 逻辑和状态机延迟）
- **断言**：在所有可能的输入序列下，REF 和 DUT 返回的数据必须一致

## 文件说明

```
formal/
├── icache_formal_tb.sv      # 形式化验证顶层模块
├── icache_formal.sby        # SymbiYosys 配置文件
└── README.md                # 本文件
```

## 前置要求

### 1. 安装 OSS CAD Suite

OSS CAD Suite 包含了所需的所有工具（Yosys, SymbiYosys, 各种求解器）。

**下载地址**：
- GitHub Release: https://github.com/YosysHQ/oss-cad-suite-build/releases

**安装步骤（Linux）**：

```bash
# 1. 下载最新版本（选择适合你系统的版本）
wget https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2024-01-15/oss-cad-suite-linux-x64-20240115.tgz

# 2. 解压
tar -xzf oss-cad-suite-linux-x64-20240115.tgz

# 3. 添加到 PATH（临时）
export PATH="/path/to/oss-cad-suite/bin:$PATH"

# 或者添加到 ~/.bashrc（永久）
echo 'export PATH="/path/to/oss-cad-suite/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. 验证安装
sby --version
yosys --version
```

### 2. 验证环境

```bash
# 测试 sby 是否正确安装
sby --help

# 测试 yosys 是否正确安装
yosys --version
```

## 使用方法

### 基本使用

```bash
# 进入 formal 目录
cd /home/lockedcore/ysyx/ysyx-workbench/npc/vsrc/formal

# 运行形式化验证（使用默认配置 depth=10）
sby -f icache_formal.sby
```

### 选择不同的验证深度

配置文件定义了多个任务，可以选择不同的验证深度：

```bash
# depth=5：快速测试，适合开发时频繁运行
sby -f icache_formal.sby depth5

# depth=10：默认配置，平衡速度和覆盖度
sby -f icache_formal.sby depth10

# depth=15：更深入的验证，可以处理更多请求
sby -f icache_formal.sby depth15

# depth=20：最深入的验证，求解时间较长
sby -f icache_formal.sby depth20
```

### 并行运行多个任务

```bash
# 同时运行所有任务
sby icache_formal.sby
```

## 结果解读

### 成功情况

如果验证通过，会看到类似的输出：

```
SBY 16:52:19 [icache_formal_depth10] engine_0: ##   0:00:05  Status: passed
SBY 16:52:19 [icache_formal_depth10] summary: Elapsed clock time [H:MM:SS (secs)]: 0:00:05 (5)
SBY 16:52:19 [icache_formal_depth10] summary: engine_0 (smtbmc) returned PASS
SBY 16:52:19 [icache_formal_depth10] DONE (PASS, rc=0)
```

**解释**：求解器在指定的深度内，遍历了所有可能的输入组合，没有找到违反断言的情况。这证明了在该深度范围内，icache 的实现是正确的。

### 失败情况

如果验证失败，会看到类似的输出：

```
SBY 16:52:19 [icache_formal_depth10] engine_0: ##   0:00:03  BMC failed!
SBY 16:52:19 [icache_formal_depth10] engine_0: ##   0:00:03  Assert failed in icache_formal_tb: data_match
SBY 16:52:19 [icache_formal_depth10] summary: counterexample trace: icache_formal_depth10/engine_0/trace.vcd
SBY 16:52:19 [icache_formal_depth10] summary:   failed assertion icache_formal_tb.data_match at icache_formal_tb.sv:198
SBY 16:52:19 [icache_formal_depth10] DONE (FAIL, rc=2)
```

**调试步骤**：

1. **查看反例波形**：
   ```bash
   # 使用 GTKWave 查看反例
   gtkwave icache_formal_depth10/engine_0/trace.vcd
   ```

2. **分析失败信息**：
   - 哪个断言失败了？（例如 `data_match`）
   - 在第几个周期失败？（例如 `in step 7`）
   - 失败时的输入是什么？（在波形中查看）

3. **修复 bug**：
   - 根据反例修改 icache 实现
   - 重新运行验证

## 验证覆盖的场景

形式化验证工具会自动遍历以下场景：

### 1. Cache 命中和缺失
- ✅ 第一次访问某地址（必然缺失）
- ✅ 重复访问相同地址（应该命中）
- ✅ 访问映射到同一 cache 块的不同地址（测试替换）

### 2. 各种地址模式
- ✅ 顺序地址访问
- ✅ 随机地址访问
- ✅ 跳跃式地址访问

### 3. AXI 握手延迟
- ✅ 总线立即响应（block_ar=0, block_r=0）
- ✅ 总线延迟响应（block_ar=1 或 block_r=1）
- ✅ 各种延迟组合

### 4. 连续请求
- ✅ 单个请求
- ✅ 多个连续请求（depth 越大，能测试的请求越多）

## 性能考虑

### 验证时间与深度的关系

| Depth | 预期时间 | 能测试的请求数 | 建议用途 |
|-------|---------|--------------|---------|
| 5     | 秒级     | 1-2个        | 快速开发迭代 |
| 10    | 秒-分钟级 | 2-3个        | 日常验证 |
| 15    | 分钟级   | 3-4个        | 深入验证 |
| 20    | 分钟-小时级 | 4-5个      | 完整验证 |
| >30   | 可能很长 | 更多          | 不推荐（状态空间爆炸）|

### 优化建议

1. **从小深度开始**：先用 depth=5 快速测试基本功能
2. **逐步增加**：功能基本正确后，再增加深度
3. **选择合适的求解器**：`boolector` 通常比 `z3` 快
4. **减小设计规模**：存储器大小已经限制为 128B，足够测试基本功能

## 常见问题

### Q1: 验证时间过长怎么办？

**A**: 尝试以下方法：
- 减小验证深度（depth）
- 简化设计（减小 INDEX_WIDTH）
- 使用更快的求解器（boolector）

### Q2: 如何添加自定义断言？

**A**: 在 `icache_formal_tb.sv` 中添加：
```systemverilog
always @(*) begin
    if (!reset && your_condition) begin
        your_assertion: assert(your_property);
    end
end
```

### Q3: 如何增加覆盖率目标？

**A**: 在 `icache_formal_tb.sv` 中添加：
```systemverilog
always @(*) begin
    if (interesting_condition) begin
        interesting_scenario: cover(1);
    end
end
```

### Q4: 验证通过了，但实际运行时还是有 bug？

**A**: 形式化验证只能证明在指定深度内的正确性。可能的原因：
- Depth 不够大，未覆盖到 bug 场景
- REF 模型本身有问题
- 断言不够完善
- 实际系统有形式化验证未建模的部分

## 进阶使用

### 生成覆盖率报告

```bash
# 运行覆盖率模式
sby -f icache_formal.sby cover
```

### 生成证明轨迹

```bash
# 添加到 .sby 配置中
[options]
mode prove
depth 20
```

### 使用不同的求解器

修改 `icache_formal.sby` 中的 `[engines]` 部分：

```ini
[engines]
# 尝试不同的求解器
smtbmc z3        # Z3 求解器
smtbmc yices     # Yices 求解器
smtbmc boolector # Boolector 求解器（推荐）
```

## 参考资料

- [SymbiYosys 官方文档](https://symbiyosys.readthedocs.io/)
- [Yosys 官方文档](https://yosyshq.net/yosys/)
- [形式化验证教程](https://zipcpu.com/tutorial/)
- [一生一芯讲义 - 形式化验证](https://ysyx.oscc.cc/)

## 故障排除

### 错误：找不到 sby 命令

```bash
# 检查 PATH 设置
echo $PATH

# 重新添加到 PATH
export PATH="/path/to/oss-cad-suite/bin:$PATH"
```

### 错误：无法读取文件

```bash
# 检查文件路径是否正确
ls -la icache_formal_tb.sv
ls -la ../frontend/ysyx_25040131_icache.sv

# 确保在 formal 目录下运行
pwd  # 应该显示 .../npc/vsrc/formal
```

### 错误：语法错误

```bash
# 单独测试 Yosys 是否能解析文件
yosys -p "read_verilog -sv -formal icache_formal_tb.sv"
```

## 联系方式

如有问题，请参考一生一芯项目的讨论区或 GitHub Issues。

