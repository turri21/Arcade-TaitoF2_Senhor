MAKEFLAGS+=w

sim:
	$(MAKE) -j8 -C sim sim

run:
	$(MAKE) -j8 -C sim run

.PHONY: sim run
