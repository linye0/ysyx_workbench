STUID = ysyx_25040131
STUNAME = 林烨

# DO NOT modify the following code!!!

TRACER = tracer-ysyx
GITFLAGS = -q --author='$(TRACER) <tracer@ysyx.org>' --no-verify --allow-empty

YSYX_HOME = $(NEMU_HOME)/..
WORK_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)
WORK_INDEX = $(YSYX_HOME)/.git/index.$(WORK_BRANCH)
TRACER_BRANCH = $(TRACER)

LOCK_DIR = $(YSYX_HOME)/.git/

# prototype: git_soft_checkout(branch)
define git_soft_checkout
	git checkout --detach -q && git reset --soft $(1) -q -- && git checkout $(1) -q --
endef

# prototype: git_commit(msg)
define git_commit
	-@flock $(LOCK_DIR) $(MAKE) -C $(YSYX_HOME) .git_commit MSG='$(1)'
	-@sync $(LOCK_DIR)
endef

PERF_LOG = $(YSYX_HOME)/npc/perf_record.log

perf:
	@echo "run performance evaluation."
	@touch $(NEMU_HOME)/src/npc/npc.c
	@$(MAKE) -C $(YSYX_HOME)/am-kernels/benchmarks/microbench RECORD=y ARCH=riscv32-ysyxsoc run mainargs=train

perf_commit: perf
	@echo "Appending Git Commit ID and merging into previous commit..."
	@if [ -f $(PERF_LOG) ]; then \
		CUR_COMMIT=$$(git rev-parse --short HEAD); \
		echo "Matched Commit ID   : $$CUR_COMMIT" >> $(PERF_LOG); \
		echo "====================================================================" >> $(PERF_LOG); \
		echo "" >> $(PERF_LOG); \
		git add $(PERF_LOG); \
		git commit -m "chore(perf): update performance log for commit $$CUR_COMMIT"; \
		echo "Success: Performance data with Commit ID [$$CUR_COMMIT] merged."; \
	else \
		echo "Error: $(PERF_LOG) not found!"; \
		exit 1; \
	fi

.git_commit:
	-@while (test -e .git/index.lock); do sleep 0.1; done;               `# wait for other git instances`
	-@git branch $(TRACER_BRANCH) -q 2>/dev/null || true                 `# create tracer branch if not existent`
	-@cp -a .git/index $(WORK_INDEX)                                     `# backup git index`
	-@$(call git_soft_checkout, $(TRACER_BRANCH))                        `# switch to tracer branch`
	-@git add . -A --ignore-errors                                       `# add files to commit`
	-@(echo "> $(MSG)" && echo $(STUID) $(STUNAME) && uname -a && uptime `# generate commit msg`) \
	                | git commit -F - $(GITFLAGS)                        `# commit changes in tracer branch`
	-@$(call git_soft_checkout, $(WORK_BRANCH))                          `# switch to work branch`
	-@mv $(WORK_INDEX) .git/index                                        `# restore git index`

.clean_index:
	rm -f $(WORK_INDEX)

_default:
	@echo "Please run 'make' under subprojects."

.PHONY: .git_commit .clean_index _default perf perf_commit
