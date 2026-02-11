UMATTER_MOD_DIR := $(USERMOD_DIR)

SRC_USERMOD_C += $(UMATTER_MOD_DIR)/src/mod_umatter.c
SRC_USERMOD_C += $(UMATTER_MOD_DIR)/src/mod_umatter_core.c
SRC_USERMOD_C += $(UMATTER_MOD_DIR)/src/umatter_core_runtime.c
CFLAGS_USERMOD += -I$(UMATTER_MOD_DIR)/include
