MAKEFLAGS+=w
PYTHON=uv --project util/ run
QUARTUS_DIR = C:/intelFPGA_lite/17.0/quartus/bin64
PROJECT = Arcade-TaitoF2
CONFIG = Arcade-TaitoF2
MISTER = root@mister-dev
OUTDIR = output_files

# Use wsl for submakes on windows
ifeq ($(OS),Windows_NT)
MAKE = wsl make
endif

RBF = $(OUTDIR)/$(CONFIG).rbf

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

SRCS_FULL = \
	$(call rwildcard,sys,*.v *.sv *.vhd *.vhdl *.qip *.sdc) \
	$(call rwildcard,rtl,*.v *.sv *.vhd *.vhdl *.qip *.sdc) \
	$(wildcard *.sdc *.v *.sv *.vhd *.vhdl *.qip)

SRCS = $(filter-out %_auto_ss.v,$(SRCS_FULL))

$(OUTDIR)/Arcade-TaitoF2-Fast.rbf: $(SRCS)
	$(QUARTUS_DIR)/quartus_sh --flow compile $(PROJECT) -c Arcade-TaitoF2-Fast

$(OUTDIR)/Arcade-TaitoF2.rbf: $(SRCS)
	$(QUARTUS_DIR)/quartus_sh --flow compile $(PROJECT) -c Arcade-TaitoF2

deploy.done: $(RBF)
	scp $(RBF) $(MISTER):/media/fat/_Development/cores/TaitoF2.rbf
	echo done > deploy.done

deploy: deploy.done


mister/%: releases/% deploy.done
	scp "$<" $(MISTER):/media/fat/_Development/
	ssh $(MISTER) "echo 'load_core _Development/$(notdir $<)' > /dev/MiSTer_cmd"

mister: mister/F2.mra
mister/finalb: mister/Final\ Blow\ (World).mra
mister/dinorex: mister/Dino\ Rex\ (World).mra
mister/qjinsei: mister/Quiz\ Jinsei\ Gekijoh\ (Japan).mra


rbf: $(OUTDIR)/$(CONFIG).rbf

sim:
	$(MAKE) -j8 -C sim sim

sim/run:
	$(MAKE) -j8 -C sim run

sim/test:
	$(MAKE) -j8 -C testroms
	$(MAKE) -j8 -C sim run

debug:
	$(MAKE) -j8 -C testroms debug

picorom:
	$(MAKE) -j8 -C testroms picorom


rtl/jt10_auto_ss.v:
	$(PYTHON) util/state_module.py jt10 rtl/jt10_auto_ss.v rtl/jt12/jt49/hdl/*.v rtl/jt12/hdl/adpcm/*.v rtl/jt12/hdl/*.v rtl/jt12/hdl/mixer/*.v

rtl/tv80_auto_ss.v:
	$(PYTHON) util/state_module.py tv80s rtl/tv80_auto_ss.v rtl/tv80/*.v


.PHONY: sim sim/run sim/test mister debug picorom rtl/jt10_auto_ss.v rtl/tv80_auto_ss.v

MRA_finalb=F2

