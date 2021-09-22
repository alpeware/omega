###
# Makefile
#
#
###
.PHONY: core crypto functional strings

BRUN = "brun"
RUN = "run"
LIB = "lib"
TESTS = "lib"

all: core crypto functional strings

core:
	$(BRUN) "`$(RUN) -i $(LIB) $(TESTS)/core_test.clsp`"

crypto:
	$(BRUN) "`$(RUN) -i $(LIB) $(TESTS)/crypto_test.clsp`"

functional:
	$(BRUN) "`$(RUN) -i $(LIB) $(TESTS)/functional_test.clsp`"

strings:
	$(BRUN) "`$(RUN) -i $(LIB) $(TESTS)/strings_test.clsp`"
