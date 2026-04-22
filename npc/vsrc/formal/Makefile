# ============================================================================
# ICache 形式化验证 Makefile
# ============================================================================

.PHONY: all formal clean help quick deep

# 默认目标
all: formal

# 运行形式化验证（默认 depth=10）
formal:
	@./run_formal.sh 10

# 快速验证（depth=5，适合开发时频繁运行）
quick:
	@./run_formal.sh 5

# 中等深度验证（depth=10，默认）
medium:
	@./run_formal.sh 10

# 深度验证（depth=15）
deep:
	@./run_formal.sh 15

# 最深验证（depth=20，可能需要较长时间）
deepest:
	@./run_formal.sh 20

# 清理所有验证结果
clean:
	@echo "Cleaning formal verification results..."
	@rm -rf icache_formal_depth*
	@echo "Done."

# 查看帮助
help:
	@echo "ICache 形式化验证 Makefile"
	@echo ""
	@echo "可用目标："
	@echo "  make           - 运行默认验证 (depth=10)"
	@echo "  make formal    - 运行默认验证 (depth=10)"
	@echo "  make quick     - 快速验证 (depth=5)"
	@echo "  make medium    - 中等深度验证 (depth=10)"
	@echo "  make deep      - 深度验证 (depth=15)"
	@echo "  make deepest   - 最深验证 (depth=20)"
	@echo "  make clean     - 清理验证结果"
	@echo "  make help      - 显示此帮助信息"
	@echo ""
	@echo "直接使用脚本："
	@echo "  ./run_formal.sh [depth]"
	@echo ""
	@echo "或使用 sby 命令："
	@echo "  sby -f icache_formal.sby depth10"

