# Chisel CPU 重构项目

本目录包含使用 Chisel 重构的 CPU 设计代码。

## 目录结构

```
chisel/
├── build.sc              # Mill 构建配置文件
├── .mill-version         # Mill 版本配置
├── src/
│   ├── main/
│   │   └── scala/
│   │       └── ysyx/     # 主包
│   │           ├── GenerateVerilog.scala  # Verilog 生成主类
│   │           ├── Ysyx25040131Cpu.scala  # 顶层 CPU 模块
│   │           ├── alu/                   # ALU 相关模块
│   │           ├── pc/                    # PC 相关模块
│   │           └── ...                    # 其他模块
│   └── test/
│       └── scala/
│           └── ysyx/      # 测试代码
└── README.md
```

## 使用方法

### 1. 安装 Mill

```bash
# 使用 coursier 安装（推荐）
curl -L https://github.com/com-lihaoyi/mill/releases/download/0.11.5/0.11.5 > mill && chmod +x mill

# 或使用包管理器
# Ubuntu/Debian
sudo apt install mill
```

### 2. 编译项目

在 `chisel/` 目录下执行：

```bash
mill cpu.compile
```

### 3. 生成 Verilog

生成 Verilog 文件到项目根目录的 `vsrc/` 文件夹：

```bash
mill cpu.verilog
```

或者直接运行主类：

```bash
mill cpu.runMain ysyx.GenerateVerilog
```

### 4. 运行测试

```bash
mill test.test
```

## 模块映射

| Verilog 模块 | Chisel 模块 | 路径 |
|------------|------------|------|
| ysyx_25040131_cpu | Ysyx25040131Cpu | `ysyx/Ysyx25040131Cpu.scala` |
| ysyx_25040131_alu | Ysyx25040131Alu | `ysyx/alu/Ysyx25040131Alu.scala` |
| ysyx_25040131_pc | Ysyx25040131Pc | `ysyx/pc/Ysyx25040131Pc.scala` |
| ... | ... | ... |

## 重构思路

1. **模块化设计**：保持与原有 Verilog 模块的一一对应关系，便于验证和调试
2. **类型安全**：利用 Scala 的类型系统，减少运行时错误
3. **参数化设计**：使用 Chisel 的参数化特性，便于配置和扩展
4. **测试驱动**：使用 ChiselTest 进行单元测试和集成测试

## 注意事项

- 生成的 Verilog 文件会输出到项目根目录的 `vsrc/` 文件夹
- 确保生成的模块名与原有 Verilog 模块名一致，以便与现有 C++ 代码集成
- 使用 DPI-C 接口时，需要确保函数签名匹配

