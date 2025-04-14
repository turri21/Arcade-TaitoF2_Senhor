MAKEFLAGS+=w

PYTHON=uv --project util/ run

sim:
	$(MAKE) -j8 -C sim sim

run:
	$(MAKE) -j8 -C sim run

rtl/jt10_auto_ss.v:
	$(PYTHON) util/state_module.py jt10 rtl/jt10_auto_ss.v rtl/jt12/jt49/hdl/*.v rtl/jt12/hdl/adpcm/*.v rtl/jt12/hdl/*.v rtl/jt12/hdl/mixer/*.v

rtl/tv80_auto_ss.v:
	$(PYTHON) util/state_module.py tv80s rtl/tv80_auto_ss.v rtl/tv80/*.v


.PHONY: sim run rtl/jt10_auto_ss.v rtl/tv80_auto_ss.v rtl/fx68k_auto_ss.sv
