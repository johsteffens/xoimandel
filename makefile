TARGET = bin/xoimandel

CC       = gcc
XC_DIR   = ../xoico
BETH_DIR = ../beth
SRC_DIR  = src
XO_DIR   = xo
XC       = $(XC_DIR)/bin/xoico
C_FLAGS   = -Wall -O3 -std=c11 `pkg-config --cflags gtk+-3.0`
LD_FLAGS  = -lm -lpthread -latomic `pkg-config --libs gtk+-3.0`
XC_FLAGS  = -O $(XO_DIR)

XC_CFGS = \
	xoimandel_app_xoico.cfg

INCLUDES = \
	-I $(BETH_DIR)/lib/bcore \
	-I $(BETH_DIR)/lib/bmath \
	-I $(XO_DIR)

XSRCS = \
	$(wildcard $(SRC_DIR)/*.x)

HDRS = \
	$(wildcard $(BETH_DIR)/lib/bcore/*.h) \
	$(wildcard $(BETH_DIR)/lib/bmath/*.h) \
	$(wildcard $(SRC_DIR)/*.h) \
	$(wildcard $(XO_DIR)/*.h)

SRCS = \
	$(wildcard $(BETH_DIR)/lib/bcore/*.c) \
	$(wildcard $(BETH_DIR)/lib/bmath/*.c) \
	$(wildcard $(SRC_DIR)/*.c) \
	$(wildcard $(XO_DIR)/*.c)

.PHONY: clean
.PHONY: cleanall
.PHONY: run
.PHONY: pass2

$(TARGET): $(XC) $(HDRS) $(SRCS) $(XSRCS) $(XC_CFGS) $(BETH_LIB)
	mkdir -p $(dir $(TARGET) )
	mkdir -p $(XO_DIR)
	$(XC) $(XC_FLAGS) $(XC_CFGS)
	$(MAKE) pass2 # second pass to capture changes by xoico

pass2:  $(HDRS) $(SRCS) $(BETH_LIB)
	$(CC) -o $(TARGET) $(C_FLAGS) $(INCLUDES) $(SRCS) $(LD_FLAGS)

$(XC):
	$(MAKE) -C $(XC_DIR)

run: $(TARGET)
	$(TARGET)

clean:
	rm -rf bin
	rm -rf $(XO_DIR)

cleanall:
	$(MAKE) -C $(XC_DIR) clean
	$(MAKE) clean
