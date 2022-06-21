BETH_DIR = ../beth

DEPENDENCIES = \
  $(BETH_DIR)/lib/bmath \
  $(BETH_DIR)/lib/bcore
  
include $(BETH_DIR)/mk/app.mk

CFLAGS  += `pkg-config --cflags gtk+-3.0`
LDFLAGS += `pkg-config --libs gtk+-3.0`
# LIBS     +=
# RUN_ARGS += 

