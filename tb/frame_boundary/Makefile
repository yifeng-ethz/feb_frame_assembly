SHELL := /bin/bash

QUESTA_HOME ?= /data1/questaone_sim/questasim
QUESTA_BIN ?= $(QUESTA_HOME)/linux_x86_64
ETH_LIC_SERVER := 8161@lic-mentor.ethz.ch
export LM_LICENSE_FILE := $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE := $(ETH_LIC_SERVER)
export SALT_LICENSE_SERVER := $(ETH_LIC_SERVER)
VLIB := $(QUESTA_BIN)/vlib
VMAP := $(QUESTA_BIN)/vmap
VCOM := $(QUESTA_BIN)/vcom
VSIM := $(QUESTA_BIN)/vsim

TB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
IP_ROOT := $(abspath $(TB_DIR)/../..)
WORK_DIR ?= $(TB_DIR)/work
MODELSIM_INI := $(WORK_DIR)/questa.ini
QUESTA_ENV := env -u QSIM_INI -u MODELSIM

.RECIPEPREFIX := >
.PHONY: all compile run clean

all: run

$(WORK_DIR):
>mkdir -p $(WORK_DIR)
>cd $(WORK_DIR) && $(VLIB) work
>cd $(WORK_DIR) && $(QUESTA_ENV) $(VMAP) -c > /dev/null
>cd $(WORK_DIR) && $(QUESTA_ENV) $(VMAP) -modelsimini questa.ini work work > /dev/null

compile: $(WORK_DIR)
>cd $(WORK_DIR) && $(QUESTA_ENV) $(VCOM) -2008 -modelsimini questa.ini -work work $(TB_DIR)/sim_models.vhd
>cd $(WORK_DIR) && $(QUESTA_ENV) $(VCOM) -2008 -modelsimini questa.ini -work work $(IP_ROOT)/search_for_extreme3.vhd
>cd $(WORK_DIR) && $(QUESTA_ENV) $(VCOM) -2008 -modelsimini questa.ini -work work $(IP_ROOT)/feb_frame_assembly.vhd
>cd $(WORK_DIR) && $(QUESTA_ENV) $(VCOM) -2008 -modelsimini questa.ini -work work $(TB_DIR)/tb_feb_frame_boundary.vhd

run: compile
>cd $(WORK_DIR) && $(QUESTA_ENV) $(VSIM) -modelsimini questa.ini -c -work work tb_feb_frame_boundary -l run.log -do "run -all; quit -f"

clean:
>rm -rf $(WORK_DIR) transcript vsim.wlf
