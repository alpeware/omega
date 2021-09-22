###
# Makefile
#
#
###
.PHONY: piggybank-test deposit-test piggybank-compile piggybank-disassemble wallet-address wallet-treehash piggybank-curry piggybank-treehash piggybank-address create-piggybank coinrecord piggybank-reveal piggybank-solution deposit-compile deposit-disassemble wallet-pubkey deposit-curry deposit-treehash deposit-address create-deposit deposit-reveal deposit-solution message sign push-spend-bundle inspect mempool

BRUN = "brun"
RUN = "run"
LIB = "../../lib"

all: piggybank-test deposit-test

piggybank-test:
	$(BRUN) "`$(RUN) -i $(LIB) -i . piggybank_test.clsp`"

deposit-test:
	$(BRUN) "`$(RUN) -i $(LIB) -i . deposit_test.clsp`"

piggybank-compile:
	cdv clsp build -i $(LIB) -i . piggybank.clsp

piggybank-disassemble:
	cdv clsp disassemble piggybank.clsp.hex

wallet-address:
	chia wallet get_address

wallet-puzzlehash:
	cdv decode $(ADDRESS)

piggybank-curry:
	cdv clsp curry piggybank.clsp.hex -a $(TARGET-AMOUNT) -a $(CASH-OUT-PUZZLE-HASH)

piggybank-treehash:
	cdv clsp curry piggybank.clsp.hex -a $(TARGET-AMOUNT) -a $(CASH-OUT-PUZZLE-HASH) --treehash

piggybank-address:
	cdv encode $(TREEHASH) --prefix txch

create-piggybank:
	chia wallet send -a 0 -t $(ADDRESS) --override

coinrecord:
	cdv rpc coinrecords --by puzhash $(PUZZLEHASH) -nd

piggybank-reveal:
	cdv clsp curry piggybank.clsp.hex -a $(TARGET-AMOUNT) -a $(CASH-OUT-PUZZLE-HASH) -x

piggybank-solution:
	opc '($(TREEHASH) $(MY-AMOUNT) $(NEW-AMOUNT))'

deposit-compile:
	cdv clsp build -i $(LIB) -i . deposit.clsp

deposit-disassemble:
	cdv clsp disassemble deposit.clsp.hex

wallet-pubkey:
	chia keys show

deposit-curry:
	cdv clsp curry deposit.clsp.hex -a $(PUBKEY)

deposit-treehash:
	cdv clsp curry deposit.clsp.hex -a $(PUBKEY) --treehash

deposit-address:
	cdv encode $(TREEHASH) --prefix txch

create-deposit:
	chia wallet send -a 0.000000000100 -t $(ADDRESS) --override

deposit-reveal:
	cdv clsp curry deposit.clsp.hex -a $(PUBKEY) -x

deposit-solution:
	opc '($(COIN-ID) $(NEW-AMOUNT))'

message:
	run '(sha256 $(COIN-ID) $(NEW-AMOUNT))'

sign:
	chia keys sign -b -f $(FINGERPRINT) -t 'm' -d $(MESSAGE)

push-spend-bundle:
	cdv rpc pushtx spend-bundle.json

inspect:
	cdv inspect spendbundles spend-bundle.json -db -n testnet7

mempool:
	cdv rpc mempool
