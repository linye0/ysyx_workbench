.PHONY: sim clean

ARGS := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))

all:
	@echo "Write this Makefile by your self."

sim:
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	@set -- $(MAKECMDGOALS);
	verilator -Wno-fatal ./vsrc/$(word 1, $(ARGS)).v ./csrc/$(word 2, $(ARGS)).cpp --top-module $(word 1, $(ARGS)) --cc --trace --exe
	make -C obj_dir -f V$(word 1, $(ARGS)).mk V$(word 1, $(ARGS))
	./obj_dir/V$(word 1, $(ARGS))

include ../Makefile
