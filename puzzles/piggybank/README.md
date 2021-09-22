# Piggybank Smart Coin

This is the piggybank smart coin from the video tutorial [Coin Life Cycle and Testing](https://chialisp.com/docs/tutorials/coin_lifecycle_and_testing).

## Prerequisites

You should have a Chia full node and wallet node connected to testnet7 and fully synced:

[Install Chia](https://github.com/Chia-Network/chia-blockchain/wiki/INSTALL)

[How to connect to the Testnet](https://github.com/Chia-Network/chia-blockchain/wiki/How-to-connect-to-the-Testnet)

You need to install the official [Chia Dev Tools](https://github.com/Chia-Network/chia-dev-tools).

Your wallet needs some coins so you can create any and you can get some from the [Chia faucet](https://chia-faucet.com/testnet).

## Walkthrough

We need two smart coins: the `piggybank` itself keeping track of how much money has been deposited into it and a `deposit` smart coin used to make the deposit.


```
$ tree .
.
├── deposit.clib
├── deposit.clsp
├── deposit_test.clsp
├── Makefile
├── piggybank.clib
├── piggybank.clsp
├── piggybank_test.clsp
├── README.md
└── spend-bundle.json
```

Let's go over the piggybank smart coin first:

`piggybank.clsp` this is our main entry point where we include the necessary libraries and just call the piggybank factory function with the relevant arguments.

```
;;;; Piggybank

;;; A piggybank smart coin.
;;;
;;; Precommitted values:
;;;
;;; TARGET-AMOUNT: amount in mojos before payout
;;; CASH-OUT-PUZZLE-HASH: payout address
;;;
;;; my-puzzle-hash: hash of the piggybank w/ precommitted values
;;; my-amount: current amount of the savings in the piggybank
;;; new-amount: new amount including newly deposited amount
;;;
;;; DISCLAIMER: This version of the piggybank also suffers from the
;;; flash loan of god attack and is just for educational purposes.
(mod (TARGET-AMOUNT CASH-OUT-PUZZLE-HASH my-puzzle-hash my-amount new-amount)

     (include "omega.clib")
     (include "piggybank.clib")

     (piggybank TARGET-AMOUNT CASH-OUT-PUZZLE-HASH my-puzzle-hash my-amount new-amount))
```

`piggybank.clib` this is where our library functions are. We separate these out so we can test them and in case we need a piggybank as an inner puzzle, we can more easily include it.

At the heart is a `cond` statement determining first whether this is a valid spend (new amount needs to exceed the existing amount) and then if we are depositing money into the piggybank or whether we trigger withdrawing to the cash out puzzle.
```
;;;; Piggybank

;;; Piggybank smart coin library
(
 (defun-inline withdraw (cash-out-puzzle-hash new-amount my-puzzle-hash my-amount)
   (list
    (assert-amount my-amount)
    (assert-puzzle-hash my-puzzle-hash)
    (coin cash-out-puzzle-hash new-amount)
    (coin my-puzzle-hash 0)
    (announce-coin new-amount)))

 (defun-inline deposit (new-amount my-puzzle-hash my-amount)
   (list
    (assert-amount my-amount)
    (assert-puzzle-hash my-puzzle-hash)
    (coin my-puzzle-hash new-amount)
    (announce-coin new-amount)))

 (defun-inline piggybank (target-amount
                          cash-out-puzzle-hash
                          my-puzzle-hash
                          my-amount
                          new-amount)
   (cond
     (not (> new-amount my-amount))
     (throw)

     (> new-amount target-amount)
     (withdraw cash-out-puzzle-hash new-amount my-puzzle-hash my-amount)

     else
     (deposit new-amount my-puzzle-hash my-amount)))
 )
```

`piggybank_test.clsp` is where we define our tests. We include our testing and piggybank libraries, define some testing values and helper functions.

Our test cases test the three branches of our `cond` statement by feeding in various values and testing that the outcome is as expected.

This works very well since there are no side effects except throwing the exception. Including `omega-testing.clib` will stub out the actual exception and return a list with the first element as the string `exception` that we can test for.

Otherwise, we just evaluate the list of conditions and make sure the relevant condition is included as expected.
```
;;;; Piggybank

;;; Piggybank smart coin tests
(mod ()
     (include "omega-testing.clib")
     (include "piggybank.clib")

     (defconstant TARGET-AMOUNT 100)
     (defconstant MY-AMOUNT 10)
     (defconstant NEW-AMOUNT-ABOVE 110)
     (defconstant NEW-AMOUNT-BELOW 90)

     (defconstant CASH-OUT-PUZZLE-HASH 0xf00dcafe)
     (defconstant MY-PUZZLE-HASH 0xdeadbeef)

     (defun has-reset-piggybank-coin (x)
       (equal (coin MY-PUZZLE-HASH 0) x))

     (defun has-piggybank-cash-out-coin (x)
       (equal (coin CASH-OUT-PUZZLE-HASH NEW-AMOUNT-ABOVE) x))

     (defun has-new-piggybank-coin (x)
       (equal (coin MY-PUZZLE-HASH NEW-AMOUNT-BELOW) x))

     (list
      "piggybank tests"

      (test "throws when new amount too low"
            (assert
             (contains "exception" (piggybank _ _ _ 100 -100) )
             (contains "exception" (piggybank _ _ _ 100 10))
             (contains "exception" (piggybank _ _ _ 100 100))))

      (test "deposit coin when below or at target"
            (assert
             (not
              (some has-reset-piggybank-coin
                    (piggybank TARGET-AMOUNT _
                               MY-PUZZLE-HASH MY-AMOUNT NEW-AMOUNT-BELOW)))
             (not
              (some has-reset-piggybank-coin
                    (piggybank TARGET-AMOUNT _
                               MY-PUZZLE-HASH MY-AMOUNT TARGET-AMOUNT)))))

      (test "withdraw when above target"
            (assert
             (some has-piggybank-cash-out-coin
                   (piggybank TARGET-AMOUNT CASH-OUT-PUZZLE-HASH
                              MY-PUZZLE-HASH MY-AMOUNT NEW-AMOUNT-ABOVE))
             (some has-reset-piggybank-coin
                   (piggybank TARGET-AMOUNT CASH-OUT-PUZZLE-HASH
                              MY-PUZZLE-HASH MY-AMOUNT NEW-AMOUNT-ABOVE))))))
```

Let's run the tests to make sure it's all working as expected. This is going to take a while, so if you haven't had your coffee, this would be a good time or just open another terminal to keep going.

```
$ time make piggybank-test
"brun" "`"run" -i "../../lib" -i . piggybank_test.clsp`"
("piggybank tests" "throws when new amount too low: PASS" "deposit coin: PASS" "withdraw when above target: PASS")

real    5m1.273s
user    5m1.070s
sys     0m0.193s
```

Alright, tests are looking good. So let's go ahead and compile the piggybank to its low level hex representation -

```
$ time make piggybank-compile
cdv clsp build -i "../../lib" -i . piggybank.clsp
Beginning compilation of piggybank.clsp...
...Compilation finished

real    1m51.609s
user    1m51.402s
sys     0m0.153s
```

We can see the clvm assembly code by disassembling the hex file -

```
$ time make piggybank-disassemble
cdv clsp disassemble piggybank.clsp.hex
(a (q 2 (i (not (> 95 47)) (q 8 ()) (q 2 (i (> 95 5) (q 4 (c 8 (c 47 ())) (c (c 12 (c 23 ())) (c (c 10 (c 11 (c 95 ()))) (c (c 10 (c 23 (q ()))) (c (c 14 (c 95 ())) ()))))) (q 4 (c 8 (c 47 ())) (c (c 12 (c 23 ())) (c (c 10 (c 23 (c 95 ()))) (c (c 14 (c 95 ())) ()))))) 1)) 1) (c (q (73 . 72) 51 . 60) 1))

real    0m1.582s
user    0m1.515s
sys     0m0.066s
```

Now we want to commit to our `TARGET-AMOUNT` and `CASH-OUT-PUZZLE-HASH` before deploying the smart coin.

Let's also use our own wallet as the cash out puzzle. This is our address in bech32m format.

```
$ make wallet-address
chia wallet get_address
txch19eajc26ztf3gjhyhlns3k7j8v22ln4uasju6chu9vv8fcf94ylnqr3uz7l
```

We need to convert this to a puzzle hash that we can commit to -

```
$ make wallet-puzzlehash ADDRESS=txch19eajc26ztf3gjhyhlns3k7j8v22ln4uasju6chu9vv8fcf94ylnqr3uz7l
cdv decode txch19eajc26ztf3gjhyhlns3k7j8v22ln4uasju6chu9vv8fcf94ylnqr3uz7l
2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6
```

Now we're ready to curry in the values we want to commit to -

```
$ make piggybank-curry TARGET-AMOUNT=1000 CASH-OUT-PUZZLE-HASH=0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6
cdv clsp curry piggybank.clsp.hex -a 1000 -a 0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6
(a (q 2 (q 2 (i (not (> 95 47)) (q 8 ()) (q 2 (i (> 95 5) (q 4 (c 8 (c 47 ())) (c (c 12 (c 23 ())) (c (c 10 (c 11 (c 95 ()))) (c (c 10 (c 23 (q ()))) (c (c 14 (c 95 ())) ()))))) (q 4 (c 8 (c 47 ())) (c (c 12 (c 23 ())) (c (c 10 (c 23 (c 95 ()))) (c (c 14 (c 95 ())) ()))))) 1)) 1) (c (q (73 . 72) 51 . 60) 1)) (c (q . 1000) (c (q . 0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6) 1)))
```

This looks good so we go ahead and now calculate the treehash of this puzzle -

```
$ make piggybank-treehash TARGET-AMOUNT=1000 CASH-OUT-PUZZLE-HASH=0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6
cdv clsp curry piggybank.clsp.hex -a 1000 -a 0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6 --treehash
e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662
```

Now we are going to do the reverse and create an address from the puzzle hash we can use as the target address for our wallet -

```
$ make piggybank-address TREEHASH=e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662
cdv encode e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 --prefix txch
txch1a88f53dqnfk7lyd75dkyd6u54d96p4qwgpjsw3g395kse7dzye3q4wm2sf
```

We are now going to send a 0 amount coin to this address and this will create our smart coin -

```
$ make create-piggybank ADDRESS=txch1a88f53dqnfk7lyd75dkyd6u54d96p4qwgpjsw3g395kse7dzye3q4wm2sf
chia wallet send -a 0 -t txch1a88f53dqnfk7lyd75dkyd6u54d96p4qwgpjsw3g395kse7dzye3q4wm2sf --override
Submitting transaction...
Transaction submitted to nodes: [('5a1dc4b48e9da813357e38eb16f06b224acacdb9b4ec1c188cd35380bdc7050f', 1, None)]
Do chia wallet get_transaction -f 3749913351 -tx 0xee65aabbd68c03d3baec07553bb381a4c2552a66eab823e5c1a41f635aec009b to get status

```

We can check the mempool of our node to see the pending transaction the wallet created. Instead of calling this a transaction, it would be more accurate to refer to it as a spend bundle -

```
$ make mempool
cdv rpc mempool
{
    "ee65aabbd68c03d3baec07553bb381a4c2552a66eab823e5c1a41f635aec009b": {
        "additions": [
            {
                "amount": 1750000000000,
                "parent_coin_info": "0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                "puzzle_hash": "0x3fea165eb79a4cc98bfbf747273845032375142e4f7d300b7b841b1e1171da69"
            },
            {
                "amount": 0,
                "parent_coin_info": "0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"
            }
        ],
       "cost": 10916860,
        "fee": 0,
        "npc_result": {
            "clvm_cost": 416860,
            "error": null,
            "npc_list": [
                {
                    "coin_name": "0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                    "conditions": [
                        [
                            "0x32",
                            [
                                {
                                    "opcode": "AGG_SIG_ME",
                                    "vars": [
                                        "0xa693aa675176aff067286f0697e2814dc3124944f171b88c37c3cc51961d411b0a06a1c3d54838441cb33b84d686a8e3",
                                        "0x471577a0c5a00f7306c7bce81d917127f9ff44cfd3797faffd627d96e647e3df"
                                    ]
                                }
                            ]
                        ],
                        [
                            "0x33",
                            [
                                {
                                    "opcode": "CREATE_COIN",
                                    "vars": [
                                        "0x3fea165eb79a4cc98bfbf747273845032375142e4f7d300b7b841b1e1171da69",
                                        "0x01977420dc00"
                                    ]
                                },
                                {
                                    "opcode": "CREATE_COIN",
                                    "vars": [
                                        "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662",
                                        "0x00"
                                    ]
                                }
                            ]
                        ]
                    ],
                    "puzzle_hash": "0x4257b2e6b7a3d0bafefcb7ec7601b645dcd0af8597708281945c41fbd1f44ab4"
                }
            ]
        },
"program": "0xff01ffffffa0117816bf8f01cfea414140de5dae222300000000000000000000000000094362ffff02ffff01ff02ffff01ff02ffff03ff0bffff01ff02ffff03ffff09
ff05ffff1dff0bffff1effff0bff0bffff02ff06ffff04ff02ffff04ff17ff8080808080808080ffff01ff02ff17ff2f80ffff01ff088080ff0180ffff01ff04ffff04ff04ffff04ff05ffff04ff
ff02ff06ffff04ff02ffff04ff17ff80808080ff80808080ffff02ff17ff2f808080ff0180ffff04ffff01ff32ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff06ffff04ff02ffff04
ff09ff80808080ffff02ff06ffff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080ffff04ffff01b0a693aa675176aff067286f0697e2814dc3124944f171b8
8c37c3cc51961d411b0a06a1c3d54838441cb33b84d686a8e3ff018080ff8601977420dc00ffff80ffff01ffff33ffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a2
2662ff8080ffff33ffa03fea165eb79a4cc98bfbf747273845032375142e4f7d300b7b841b1e1171da69ff8601977420dc0080ffff3cffa0bf677726df845961f143b02bc20e435ddd9ba968c90b
52a1c32383664eaebd1f8080ff8080808080",
        "removals": [
            {
                "amount": 1750000000000,
                "parent_coin_info": "0x117816bf8f01cfea414140de5dae222300000000000000000000000000094362",
                "puzzle_hash": "0x4257b2e6b7a3d0bafefcb7ec7601b645dcd0af8597708281945c41fbd1f44ab4"
            }
        ],
        "spend_bundle": {
            "aggregated_signature": "0xa59e28c4ad64b2536d8aa6a1bf22714e7d6e4b80bc557ea3c36ada94382ed69240ed639cd02f418ecc91b8fd0dbdc8ae121c4724d8212f3e3a520
771af75b04f74896e5587f7e80f07d398a58509f7fcb286d92438cb4c7054f41fa6c2913a7d",
            "coin_spends": [
                {
                    "coin": {
                        "amount": 1750000000000,
                        "parent_coin_info": "0x117816bf8f01cfea414140de5dae222300000000000000000000000000094362",
                        "puzzle_hash": "0x4257b2e6b7a3d0bafefcb7ec7601b645dcd0af8597708281945c41fbd1f44ab4"
                    },
                    "puzzle_reveal": "0xff02ffff01ff02ffff01ff02ffff03ff0bffff01ff02ffff03ffff09ff05ffff1dff0bffff1effff0bff0bffff02ff06ffff04ff02ffff04ff17
ff8080808080808080ffff01ff02ff17ff2f80ffff01ff088080ff0180ffff01ff04ffff04ff04ffff04ff05ffff04ffff02ff06ffff04ff02ffff04ff17ff80808080ff80808080ffff02ff17ff
2f808080ff0180ffff04ffff01ff32ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff06ffff04ff02ffff04ff09ff80808080ffff02ff06ffff04ff02ffff04ff0dff8080808080ffff
01ff0bffff0101ff058080ff0180ff018080ffff04ffff01b0a693aa675176aff067286f0697e2814dc3124944f171b88c37c3cc51961d411b0a06a1c3d54838441cb33b84d686a8e3ff018080",
                    "solution": "0xff80ffff01ffff33ffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662ff8080ffff33ffa03fea165eb79a4cc98bfbf
747273845032375142e4f7d300b7b841b1e1171da69ff8601977420dc0080ffff3cffa0bf677726df845961f143b02bc20e435ddd9ba968c90b52a1c32383664eaebd1f8080ff8080"
                }
            ]
        },
        "spend_bundle_name": "0xee65aabbd68c03d3baec07553bb381a4c2552a66eab823e5c1a41f635aec009b"
    }
}
```

Once the spend bundle made its way into the blockchain, we can then go ahead and look for the coin record by its puzzle hash. If this returns no results, it might still be processing so just wait a couple minutes.

```
$ make coinrecord PUZZLEHASH=e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662
cdv rpc coinrecords --by puzhash e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 -nd
{
    "6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143": {
        "coin": {
            "amount": 0,
            "parent_coin_info": "0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
            "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"
        },
        "coinbase": false,
        "confirmed_block_index": 623356,
        "spent": false,
        "spent_block_index": 0,
        "timestamp": 1632256414
    }
}
```

Our piggybank smart coin is now deployed on the blockchain and ready to accept deposits.

`deposit.clsp` is our main entry point for the deposit smart coin where we include the relevant libraries and call the deposit factory function.

```
;;;; Deposit

;;; A deposit smart coin used with the piggybank smart coin.
;;;
;;; Precommitted values:
;;;
;;; PUBKEY: public key used to sign messages
;;; coin-id: the coin id of the piggybank
;;; new-amount: the new amount of the piggybank after depositing
(mod (PUBKEY coin-id new-amount)

     (include "omega.clib")
     (include "deposit.clib")

     (deposit PUBKEY coin-id new-amount))
```

`deposit.clib`
```
;;;; Deposit

;;; Deposit smart coin library.
(
 (defun-inline hash (coin-id new-amount)
   (sha256 coin-id new-amount))

 (defun conditions (pubkey hash)
   (list
    (assert-coin-announcement hash)
    (sign-unsafe pubkey hash)))

 (defun-inline deposit (pubkey coin-id new-amount)
   (conditions pubkey (hash coin-id new-amount)))
 )
```
Here the `hash` function creates the hash of the piggybank coin id and its new amount. Since we require the hash for both the announcement and as the message we want to sign, we calculate it once and pass it to our `conditions` function.

`deposit_test.clsp` are our tests for the deposit smart coin and should be pretty straight forward.

```
(mod ()
     (include "omega-testing.clib")
     (include "deposit.clib")

     (defconstant PUBKEY 0xdeadbeef)
     (defconstant COIN-ID 0xbabecafe)
     (defconstant HASH 0xabcdef)
     (defconstant NEW-AMOUNT 100)

     (defun has-coin-announcement (x)
       (equal (assert-coin-announcement HASH) x))

     (defun has-signature (x)
       (equal (sign-unsafe PUBKEY HASH) x))

     (list
      "deposit tests"

      (test "hash value"
            (assert (= (hash COIN-ID NEW-AMOUNT)
                       (sha256 COIN-ID NEW-AMOUNT))))

      (test "asserts coin announcement"
            (assert
             (some has-coin-announcement
                   (conditions PUBKEY HASH))))

      (test "asserts signature"
            (assert
             (some has-signature
                   (conditions PUBKEY HASH))))))
```

Let's make sure the tests pass -

```
$ time make deposit-test
"brun" "`"run" -i "../../lib" -i . deposit_test.clsp`"
("deposit tests" "hash value: PASS" "asserts coin announcement: PASS" "asserts signature: PASS")

real    5m7.873s
user    5m7.622s
sys     0m0.216s
```

Looking good. Again, let's go ahead and compile it -

```
$ time make deposit-compile
cdv clsp build -i "../../lib" -i . deposit.clsp
Beginning compilation of deposit.clsp...
...Compilation finished

real    1m39.358s
user    1m39.137s
sys     0m0.211s
```

Let's disassemble it -

```
$ make deposit-disassemble
cdv clsp disassemble deposit.clsp.hex
(a (q 2 14 (c 2 (c 5 (c (sha256 11 23) ())))) (c (q 49 61 4 (c 10 (c 11 ())) (c (c 4 (c 5 (c 11 ()))) ())) 1))
```

Before we can commit to the public key, we first need to find it. We are looking for the master public key.

```
$ make wallet-pubkey
chia keys show
Showing all public keys derived from your private keys:

Fingerprint: 3749913351
Master public key (m): b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d
Farmer public key (m/12381/8444/0/0): aad7b869d26be91bfbe61e30155449ca7e0c69a3cb0b88eeac51e9beef1de4945c671e0029e9b86048426eabad7f7acc
Pool public key (m/12381/8444/1/0): 804606847d9675865b2f4a18543858eb2b232cce1e2503f7c411e231517a6aa9ec08afc40c8041df051157a8b0f2ad39
First wallet address: txch1gftm9e4h50gt4lhuklk8vqdkghwdptu9jacg9qv5t3qlh505f26q8jjjna
```

Let's curry in our arguments -

```
$ make deposit-curry PUBKEY=0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d
cdv clsp curry deposit.clsp.hex -a 0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d
(a (q 2 (q 2 14 (c 2 (c 5 (c (sha256 11 23) ())))) (c (q 49 61 4 (c 10 (c 11 ())) (c (c 4 (c 5 (c 11 ()))) ())) 1)) (c (q . 0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d) 1))
```

And create the treehash with the public key committed -

```
$ make deposit-treehash PUBKEY=0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d
cdv clsp curry deposit.clsp.hex -a 0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d --treehash
6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc
```

We translate the treehash to an address we can use for our wallet -

```
$ make deposit-address TREEHASH=6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc
cdv encode 6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc --prefix txch
txch1dyjdr3pjh54q3mymc8j7992qdtmy4aeegpzaejw2q6dz2ukec0wqkryhc4
```

And we are ready to create the deposit smart coin with a value of 100 mojos -

```
$ make create-deposit ADDRESS=txch1dyjdr3pjh54q3mymc8j7992qdtmy4aeegpzaejw2q6dz2ukec0wqkryhc4
chia wallet send -a 0.000000000100 -t txch1dyjdr3pjh54q3mymc8j7992qdtmy4aeegpzaejw2q6dz2ukec0wqkryhc4 --override
Submitting transaction...                                                                                                                                   Transaction submitted to nodes: [('5a1dc4b48e9da813357e38eb16f06b224acacdb9b4ec1c188cd35380bdc7050f', 1, None)]
Do chia wallet get_transaction -f 3749913351 -tx 0x62bd412a2d63c08a0ada8f55ab49bd742ecd4216fb12195d41b889b145d88d04 to get status
```

We can again check the mempool -

```
$ make mempool
cdv rpc mempool
{
    "62bd412a2d63c08a0ada8f55ab49bd742ecd4216fb12195d41b889b145d88d04": {
        "additions": [
            {
                "amount": 100,
                "parent_coin_info": "0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                "puzzle_hash": "0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc"
            },
            {
                "amount": 1749999999900,
                "parent_coin_info": "0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                "puzzle_hash": "0xfb23efdafe69ebbb5a689675d920d85f3be7c09c5d7ea81299d212cca0d8eda5"
            }
        ],
        "cost": 10916862,                                                                                                                                           "fee": 0,
        "npc_result": {
            "clvm_cost": 416862,
            "error": null,
            "npc_list": [
                {
                    "coin_name": "0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                    "conditions": [
                        [
                            "0x32",
                            [
                                {
                                    "opcode": "AGG_SIG_ME",
                                    "vars": [
                                        "0xa693aa675176aff067286f0697e2814dc3124944f171b88c37c3cc51961d411b0a06a1c3d54838441cb33b84d686a8e3",
                                        "0x487d4b949a96ff7a6a8938ab0c6ba975c1ecba698a17ccdf031366ea1abeabc3"
                                    ]
                                }
                            ]
                        ],
                        [
                            "0x33",
                            [
                                {
                                    "opcode": "CREATE_COIN",
                                    "vars": [
                                        "0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc",
                                        "0x64"
                                    ]
                                },                                                                                                                 [22/1997]
                                {
                                    "opcode": "CREATE_COIN",
                                    "vars": [
                                        "0xfb23efdafe69ebbb5a689675d920d85f3be7c09c5d7ea81299d212cca0d8eda5",
                                        "0x01977420db9c"
                                    ]
                                }
                            ]
                        ]
                    ],
                    "puzzle_hash": "0x4257b2e6b7a3d0bafefcb7ec7601b645dcd0af8597708281945c41fbd1f44ab4"
                }
            ]
        },
        "program": "0xff01ffffffa0117816bf8f01cfea414140de5dae22230000000000000000000000000009250cffff02ffff01ff02ffff01ff02ffff03ff0bffff01ff02ffff03ffff09
ff05ffff1dff0bffff1effff0bff0bffff02ff06ffff04ff02ffff04ff17ff8080808080808080ffff01ff02ff17ff2f80ffff01ff088080ff0180ffff01ff04ffff04ff04ffff04ff05ffff04ff
ff02ff06ffff04ff02ffff04ff17ff80808080ff80808080ffff02ff17ff2f808080ff0180ffff04ffff01ff32ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff06ffff04ff02ffff04
ff09ff80808080ffff02ff06ffff04ff02ffff04ff0dff8080808080ffff01ff0bffff0101ff058080ff0180ff018080ffff04ffff01b0a693aa675176aff067286f0697e2814dc3124944f171b8
8c37c3cc51961d411b0a06a1c3d54838441cb33b84d686a8e3ff018080ff8601977420dc00ffff80ffff01ffff33ffa06924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9
c3dcff6480ffff33ffa0fb23efdafe69ebbb5a689675d920d85f3be7c09c5d7ea81299d212cca0d8eda5ff8601977420db9c80ffff3cffa037a172cb576924ea6fb01b8cc393d14c105a0e83e3b1
b097305162c221ef35aa8080ff8080808080",
        "removals": [
            {
                "amount": 1750000000000,
                "parent_coin_info": "0x117816bf8f01cfea414140de5dae22230000000000000000000000000009250c",
                "puzzle_hash": "0x4257b2e6b7a3d0bafefcb7ec7601b645dcd0af8597708281945c41fbd1f44ab4"
            }
        ],
        "spend_bundle": {
            "aggregated_signature": "0x98254b68de40a38914f6c5b88a89cbad59fa3cd4d7493b67e6434e112b8ad56af0d8c0dc272993fbf8fe436d5a09d7ba017ed0cfc0b5475504daf
72467ffc01244d71fe491766d51c13598a921ffd6772631b03f02886d46fb696b329e2f8df6",
            "coin_spends": [
                {
                    "coin": {
                        "amount": 1750000000000,
                        "parent_coin_info": "0x117816bf8f01cfea414140de5dae22230000000000000000000000000009250c",
                        "puzzle_hash": "0x4257b2e6b7a3d0bafefcb7ec7601b645dcd0af8597708281945c41fbd1f44ab4"
                    },
                    "puzzle_reveal": "0xff02ffff01ff02ffff01ff02ffff03ff0bffff01ff02ffff03ffff09ff05ffff1dff0bffff1effff0bff0bffff02ff06ffff04ff02ffff04ff17
ff8080808080808080ffff01ff02ff17ff2f80ffff01ff088080ff0180ffff01ff04ffff04ff04ffff04ff05ffff04ffff02ff06ffff04ff02ffff04ff17ff80808080ff80808080ffff02ff17ff
2f808080ff0180ffff04ffff01ff32ff02ffff03ffff07ff0580ffff01ff0bffff0102ffff02ff06ffff04ff02ffff04ff09ff80808080ffff02ff06ffff04ff02ffff04ff0dff8080808080ffff
01ff0bffff0101ff058080ff0180ff018080ffff04ffff01b0a693aa675176aff067286f0697e2814dc3124944f171b88c37c3cc51961d411b0a06a1c3d54838441cb33b84d686a8e3ff018080",
                    "solution": "0xff80ffff01ffff33ffa06924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dcff6480ffff33ffa0fb23efdafe69ebbb5a689
675d920d85f3be7c09c5d7ea81299d212cca0d8eda5ff8601977420db9c80ffff3cffa037a172cb576924ea6fb01b8cc393d14c105a0e83e3b1b097305162c221ef35aa8080ff8080"
                }
            ]
        },
        "spend_bundle_name": "0x62bd412a2d63c08a0ada8f55ab49bd742ecd4216fb12195d41b889b145d88d04"
    }
}
```

Let's query the coin by its puzzle hash -

```
$ make coinrecord PUZZLEHASH=6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc
cdv rpc coinrecords --by puzhash 6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc -nd
{
    "d06b6fd9a9e5134da584d9fe21f723534c7bc10200dd307349b60e8345af7cda": {
        "coin": {
            "amount": 100,
            "parent_coin_info": "0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
            "puzzle_hash": "0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc"
        },
        "coinbase": false,
        "confirmed_block_index": 623517,
        "spent": false,
        "spent_block_index": 0,
        "timestamp": 1632259456
    }
}
```

We are now ready to create our spend bundle where we will spend the `deposit` smart coin and let the `piggybank` smart coin absorb its value.

`spend-bundle.json` is our skeleton json we need to fill out. The first coin will be our `piggybank` coin with amount `0` and the second coin our `deposit` coin with an amount of `100` mojos.

```
{
    "coin_spends": [
        {
            "coin": {
                "parent_coin_info": "",
                "puzzle_hash": "",
                "amount": 0
            },
            "puzzle_reveal": "",
            "solution": ""
        },
        {
            "coin": {
                "parent_coin_info": "",
                "puzzle_hash": "",
                "amount": 100
            },
            "puzzle_reveal": "",
            "solution": ""
        }
    ],
    "aggregated_signature": ""
}

```

Let's add the `parent_coint_info` and `puzzle_hash` values for each coin. We can get these values by querying the coinrecord.

```
{
    "coin_spends": [
        {
            "coin": {
                "parent_coin_info": "906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                "puzzle_hash": "e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662",
                "amount": 0
            },
            "puzzle_reveal": "",
            "solution": ""
        },
        {
            "coin": {
                "parent_coin_info": "a45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                "puzzle_hash": "6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc",
                "amount": 100
            },
            "puzzle_reveal": "",
            "solution": ""
        }
    ],
    "aggregated_signature": ""
}

```

To add the `piggybank` puzzle reveal, we need to again curry in our precommitted values. Instead of generating the treehash, we will serialize the puzzle.

```
$ make piggybank-reveal TARGET-AMOUNT=1000 CASH-OUT-PUZZLE-HASH=0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6
cdv clsp curry piggybank.clsp.hex -a 1000 -a 0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6 -x
ff02ffff01ff02ffff01ff02ffff03ffff20ffff15ff5fff2f8080ffff01ff08ff8080ffff01ff02ffff03ffff15ff5fff0580ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff0bffff04ff5fff80808080ffff04ffff04ff0affff04ff17ffff01ff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff17ffff04ff5fff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ff018080ff0180ffff04ffff01ffff4948ff333cff018080ffff04ffff018203e8ffff04ffff01a02e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6ff01808080
```

We can do the same for the `deposit` smart coin. Recall that we committed to our public key.

```
$ make deposit-reveal PUBKEY=0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d
cdv clsp curry deposit.clsp.hex -a 0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d -x
ff02ffff01ff02ffff01ff02ff0effff04ff02ffff04ff05ffff04ffff0bff0bff1780ff8080808080ffff04ffff01ff31ff3dff04ffff04ff0affff04ff0bff808080ffff04ffff04ff04ffff04ff05ffff04ff0bff80808080ff808080ff018080ffff04ffff01b0b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5dff018080
```

Let's update our spend bundle with these values -

```
{
    "coin_spends": [
        {
            "coin": {
                "parent_coin_info": "906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                "puzzle_hash": "e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662",
                "amount": 0
            },
            "puzzle_reveal": "ff02ffff01ff02ffff01ff02ffff03ffff20ffff15ff5fff2f8080ffff01ff08ff8080ffff01ff02ffff03ffff15ff5fff0580ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff0bffff04ff5fff80808080ffff04ffff04ff0affff04ff17ffff01ff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff17ffff04ff5fff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ff018080ff0180ffff04ffff01ffff4948ff333cff018080ffff04ffff018203e8ffff04ffff01a02e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6ff01808080",
            "solution": ""
        },
        {
            "coin": {
                "parent_coin_info": "a45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                "puzzle_hash": "6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc",
                "amount": 100
            },
            "puzzle_reveal": "ff02ffff01ff02ffff01ff02ff0effff04ff02ffff04ff05ffff04ffff0bff0bff1780ff8080808080ffff04ffff01ff31ff3dff04ffff04ff0affff04ff0bff808080ffff04ffff04ff04ffff04ff05ffff04ff0bff80808080ff808080ff018080ffff04ffff01b0b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5dff018080",
            "solution": ""
        }
    ],
    "aggregated_signature": ""
}
```

We are now ready to create the solution for the `piggybank`. Let's look at our smart coin again.

```
;;;; Piggybank

;;; A piggybank smart coin.
;;;
;;; Precommitted values:
;;;
;;; TARGET-AMOUNT: amount in mojos before payout
;;; CASH-OUT-PUZZLE-HASH: payout address
;;;
;;; my-puzzle-hash: hash of the piggybank w/ precommitted values
;;; my-amount: current amount of the savings in the piggybank
;;; new-amount: new amount including newly deposited amount
(mod (TARGET-AMOUNT CASH-OUT-PUZZLE-HASH my-puzzle-hash my-amount new-amount)

     (include "omega.clib")
     (include "piggybank.clib")

     (piggybank TARGET-AMOUNT CASH-OUT-PUZZLE-HASH my-puzzle-hash my-amount new-amount))
```
So what we need for the solution are the arguments we have not curried in: `my-puzzle-hash my-amount new-amount`.

```
$ make piggybank-solution TREEHASH=0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 MY-AMOUNT=0 NEW-AMOUNT=100
opc '(0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 0 100)'
ffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662ff80ff6480
```

Let's do the same for our `deposit` smart coin -

```
;;;; Deposit

;;; A deposit smart coin used with the piggybank smart coin.
;;;
;;; Precommitted values:
;;;
;;; PUBKEY: public key used to sign messages
;;; coin-id: the coin id of the piggybank
;;; new-amount: the new amount of the piggybank after depositing
(mod (PUBKEY coin-id new-amount)

     (include "omega.clib")
     (include "deposit.clib")

     (deposit PUBKEY coin-id new-amount))
```
Here we are looking for the `piggybank` `coin id` and the `new amount`.

```
$ make deposit-solution COIN-ID=0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143 NEW-AMOUNT=100
opc '(0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143 100)'
ffa06c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143ff6480
```

Great, let's add our solutions to our spend bundle.

```
{
    "coin_spends": [
        {
            "coin": {
                "parent_coin_info": "906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                "puzzle_hash": "e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662",
                "amount": 0
            },
            "puzzle_reveal": "ff02ffff01ff02ffff01ff02ffff03ffff20ffff15ff5fff2f8080ffff01ff08ff8080ffff01ff02ffff03ffff15ff5fff0580ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff0bffff04ff5fff80808080ffff04ffff04ff0affff04ff17ffff01ff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff17ffff04ff5fff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ff018080ff0180ffff04ffff01ffff4948ff333cff018080ffff04ffff018203e8ffff04ffff01a02e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6ff01808080",
            "solution": "ffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662ff80ff6480"
        },
        {
            "coin": {
                "parent_coin_info": "a45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                "puzzle_hash": "6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc",
                "amount": 100
            },
            "puzzle_reveal": "ff02ffff01ff02ffff01ff02ff0effff04ff02ffff04ff05ffff04ffff0bff0bff1780ff8080808080ffff04ffff01ff31ff3dff04ffff04ff0affff04ff0bff808080ffff04ffff04ff04ffff04ff05ffff04ff0bff80808080ff808080ff018080ffff04ffff01b0b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5dff018080",
            "solution": "ffa06c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143ff6480"
        }
    ],
    "aggregated_signature": ""
}
```
Now we are just missing the signature. Let's look at our `deposit` smart coin again since this is the only time we are signing anything.

```
;;;; Deposit

;;; Deposit smart coin library.
(
 (defun-inline hash (coin-id new-amount)
   (sha256 coin-id new-amount))

 (defun conditions (pubkey hash)
   (list
    (assert-coin-announcement hash)
    (sign-unsafe pubkey hash)))

 (defun-inline deposit (pubkey coin-id new-amount)
   (conditions pubkey (hash coin-id new-amount)))
 )
```
Here we can see that we use our `public key` to sign the hash of the `coin id` and the `new amount`. So let's go ahead and first create this same message -

```
$ make message COIN-ID=0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143 NEW-AMOUNT=100
run '(sha256 0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143 100)'
0x7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b
```

Before we can sign it, we also need our wallet's `fingerprint`. We can get it by looking at our keys again -

```
$ make wallet-pubkey
chia keys show
Showing all public keys derived from your private keys:

Fingerprint: 3749913351
Master public key (m): b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d
Farmer public key (m/12381/8444/0/0): aad7b869d26be91bfbe61e30155449ca7e0c69a3cb0b88eeac51e9beef1de4945c671e0029e9b86048426eabad7f7acc
Pool public key (m/12381/8444/1/0): 804606847d9675865b2f4a18543858eb2b232cce1e2503f7c411e231517a6aa9ec08afc40c8041df051157a8b0f2ad39
First wallet address: txch1gftm9e4h50gt4lhuklk8vqdkghwdptu9jacg9qv5t3qlh505f26q8jjjna
```

Now we can go ahead and sign the message -

```
$ make sign FINGERPRINT=3749913351 MESSAGE=7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b
chia keys sign -b -f 3749913351 -t 'm' -d 7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b
Public key: b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d
Signature: 812efdba8c38ae16fd780d93b6adee42854b977f585c0d591edae750f532887d6e56fc06e079cce85869e48e6f406ac816d9b92d0f88cc3943acab206266f1fc2c6096bc21f9e87a23683ab31af2b799da069b3887e376ea6255ff8859cd4e6a
```

Let's complete our `spend bundle` -

```
{
    "coin_spends": [
        {
            "coin": {
                "parent_coin_info": "906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                "puzzle_hash": "e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662",
                "amount": 0
            },
            "puzzle_reveal": "ff02ffff01ff02ffff01ff02ffff03ffff20ffff15ff5fff2f8080ffff01ff08ff8080ffff01ff02ffff03ffff15ff5fff0580ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff0bffff04ff5fff80808080ffff04ffff04ff0affff04ff17ffff01ff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff17ffff04ff5fff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ff018080ff0180ffff04ffff01ffff4948ff333cff018080ffff04ffff018203e8ffff04ffff01a02e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6ff01808080",
            "solution": "ffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662ff80ff6480"
        },
        {
            "coin": {
                "parent_coin_info": "a45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                "puzzle_hash": "6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc",
                "amount": 100
            },
            "puzzle_reveal": "ff02ffff01ff02ffff01ff02ff0effff04ff02ffff04ff05ffff04ffff0bff0bff1780ff8080808080ffff04ffff01ff31ff3dff04ffff04ff0affff04ff0bff808080ffff04ffff04ff04ffff04ff05ffff04ff0bff80808080ff808080ff018080ffff04ffff01b0b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5dff018080",
            "solution": "ffa06c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143ff6480"
        }
    ],
    "aggregated_signature": "812efdba8c38ae16fd780d93b6adee42854b977f585c0d591edae750f532887d6e56fc06e079cce85869e48e6f406ac816d9b92d0f88cc3943acab206266f1fc2c6096bc21f9e87a23683ab31af2b799da069b3887e376ea6255ff8859cd4e6a"
}
```

Let's inspect it to make sure we didn't make any mistakes -

```
$ make inspect
cdv inspect spendbundles spend-bundle.json -db -n testnet7
[{"aggregated_signature": "0x812efdba8c38ae16fd780d93b6adee42854b977f585c0d591edae750f532887d6e56fc06e079cce85869e48e6f406ac816d9b92d0f88cc3943acab206266f1fc2c6096bc21f9e87a23683ab31af2b799da069b3887e376ea6255ff8859cd4e6a", "coin_solutions": [{"coin": {"parent_coin_info": "0x906ed912b6452305fa79fc13208dc153c771
0853c5845f4d7a6aa26a0444061b", "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662", "amount": 0}, "puzzle_reveal": "0xff02ff
ff01ff02ffff01ff02ffff03ffff20ffff15ff5fff2f8080ffff01ff08ff8080ffff01ff02ffff03ffff15ff5fff0580ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04
ff17ff808080ffff04ffff04ff0affff04ff0bffff04ff5fff80808080ffff04ffff04ff0affff04ff17ffff01ff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ffff01ff
04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff17ffff04ff5fff80808080ffff04ffff04ff0effff04ff5fff808080ff8080808080
80ff018080ff0180ffff04ffff01ffff4948ff333cff018080ffff04ffff018203e8ffff04ffff01a02e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6ff01808080
", "solution": "0xffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662ff80ff6480"}, {"coin": {"parent_coin_info": "0xa45d9984341e4df60fd1837
39dc85780e433b2e1da876e973d4d0d83f6bbb795", "puzzle_hash": "0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc", "amount": 100}, "puzzle_rev
eal": "0xff02ffff01ff02ffff01ff02ff0effff04ff02ffff04ff05ffff04ffff0bff0bff1780ff8080808080ffff04ffff01ff31ff3dff04ffff04ff0affff04ff0bff808080ffff04ffff04f
f04ffff04ff05ffff04ff0bff80808080ff808080ff018080ffff04ffff01b0b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859
d5dff018080", "solution": "0xffa06c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143ff6480"}]}]

Debugging Information
---------------------
================================================================================
consuming coin (0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b 0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 ())
  with id 6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143


brun -y main.sym '(a (q 2 (q 2 (i (not (> 95 47)) (q 8 ()) (q 2 (i (> 95 5) (q 4 (c 8 (c 47 ())) (c (c 12 (c 23 ())) (c (c 10 (c 11 (c 95 ()))) (c (c 10 (c
23 (q ()))) (c (c 14 (c 95 ())) ()))))) (q 4 (c 8 (c 47 ())) (c (c 12 (c 23 ())) (c (c 10 (c 23 (c 95 ()))) (c (c 14 (c 95 ())) ()))))) 1)) 1) (c (q (73 . 7
2) 51 . 60) 1)) (c (q . 1000) (c (q . 0x2e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6) 1)))' '(0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e
40650745112d2d0cf9a22662 () 100)'

((ASSERT_MY_AMOUNT ()) (ASSERT_MY_PUZZLEHASH 0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662) (CREATE_COIN 0xe9ce9a45a09a6def91bea36c46eb
94ab4ba0d40e40650745112d2d0cf9a22662 100) (CREATE_COIN_ANNOUNCEMENT 100))

grouped conditions:

  (ASSERT_MY_AMOUNT ())

  (ASSERT_MY_PUZZLEHASH 0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662)

  (CREATE_COIN 0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 100)

  (CREATE_COIN_ANNOUNCEMENT 100)


-------
consuming coin (0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795 0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3d[8/1859]
  with id d06b6fd9a9e5134da584d9fe21f723534c7bc10200dd307349b60e8345af7cda


brun -y main.sym '(a (q 2 (q 2 14 (c 2 (c 5 (c (sha256 11 23) ())))) (c (q 49 61 4 (c 10 (c 11 ())) (c (c 4 (c 5 (c 11 ()))) ())) 1)) (c (q . 0xb980a0ed9a2d
74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d) 1))' '(0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78
143 100)'

((ASSERT_COIN_ANNOUNCEMENT 0x7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b) (AGG_SIG_UNSAFE 0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef61
4a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d 0x7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b))

grouped conditions:

  (ASSERT_COIN_ANNOUNCEMENT 0x7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b)

  (AGG_SIG_UNSAFE 0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d 0x7ae4d162ff89b70c61a4e4d0d17a11f274acb
e0782744d292117adced026142b)


-------

spent coins
  (0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b 0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 ())
      => spent coin id 6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143
  (0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795 0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc 100)
      => spent coin id d06b6fd9a9e5134da584d9fe21f723534c7bc10200dd307349b60e8345af7cda

created coins
  (0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143 0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 100)
      => created coin id 658522cd184023a13bbc4305852a465ff91b019720d1ade49e656d1815cdac86
created coin announcements
  ['0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143', '0x64'] =>
      7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b


zero_coin_set = []

created  coin announcements = ['7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b']

asserted coin announcements = ['7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b']

symdiff of coin announcements = []


================================================================================

aggregated signature check pass: True
pks: [<G1Element b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d>]
msgs: ['7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b']
  msg_data: ['']
  coin_ids: ['']
  add_data: ['7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b']
signature: 812efdba8c38ae16fd780d93b6adee42854b977f585c0d591edae750f532887d6e56fc06e079cce85869e48e6f406ac816d9b92d0f88cc3943acab206266f1fc2c6096bc21f9e87a2
3683ab31af2b799da069b3887e376ea6255ff8859cd4e6a
None
```

Looks like everything checked out, so let's go ahead and push our spend bundle -

```
$ make push-spend-bundle
cdv rpc pushtx spend-bundle.json
{
  "status": "SUCCESS",
  "success": true
}
```

Looks like it was accepted by our node, so let's check the `mempool` -

```
$ make mempool
cdv rpc mempool
{
    "97afb3e7168f74df54c79050751b92d513dd47f1886d37ce2001b90ce6d938dc": {
        "additions": [
            {
                "amount": 100,
                "parent_coin_info": "0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143",                                                                   "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"                                                                     }
        ],
        "cost": 11207289,
        "fee": 0,
        "npc_result": {
            "clvm_cost": 611289,
            "error": null,
            "npc_list": [
                {
                    "coin_name": "0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143",
                    "conditions": [
                        [
                            "0x33",
                            [
                                {
                                    "opcode": "CREATE_COIN",
                                    "vars": [
                                        "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662",
                                        "0x64"
                                    ]                                                                                                                                                       }
                            ]
                        ]
                    ],
                    "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"
                },
                {
                    "coin_name": "0xd06b6fd9a9e5134da584d9fe21f723534c7bc10200dd307349b60e8345af7cda",
                    "conditions": [
                        [
                            "0x31",
                            [
                                {
                                    "opcode": "AGG_SIG_UNSAFE",
                                    "vars": [
                                        "0xb980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5d",
                                        "0x7ae4d162ff89b70c61a4e4d0d17a11f274acbe0782744d292117adced026142b"
                                    ]
                                }                                                                                                                  [33/1992]
                            ]
                        ]
                    ],
                    "puzzle_hash": "0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc"
                }
            ]
        },
        "program": "0xff01ffffffa0906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061bffff02ffff01ff02ffff01ff02ffff03ffff20ffff15ff5fff2f8080ff
ff01ff08ff8080ffff01ff02ffff03ffff15ff5fff0580ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff0bffff04ff5fff
80808080ffff04ffff04ff0affff04ff17ffff01ff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff
04ff17ff808080ffff04ffff04ff0affff04ff17ffff04ff5fff80808080ffff04ffff04ff0effff04ff5fff808080ff808080808080ff018080ff0180ffff04ffff01ffff4948ff333cff018080
ffff04ffff018203e8ffff04ffff01a02e7b2c2b425a62895c97fce11b7a476295f9d79d84b9ac5f85630e9c24b527e6ff01808080ff80ffffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e
40650745112d2d0cf9a22662ff80ff648080ffffa0a45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795ffff02ffff01ff02ffff01ff02ff0effff04ff02ffff04ff05
ffff04ffff0bff0bff1780ff8080808080ffff04ffff01ff31ff3dff04ffff04ff0affff04ff0bff808080ffff04ffff04ff04ffff04ff05ffff04ff0bff80808080ff808080ff018080ffff04ff
ff01b0b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f77e681a6cd594f93664b895cb2f5859d5dff018080ff64ffffa06c1e3a8fd1f4492b3adcf87975cd117b5977
a61c94e5dff81bda9c4253d78143ff6480808080",
        "removals": [
            {
                "amount": 0,
                "parent_coin_info": "0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"
            },
            {
                "amount": 100,
                "parent_coin_info": "0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                "puzzle_hash": "0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc"
            }
        ],
        "spend_bundle": {
            "aggregated_signature": "0x812efdba8c38ae16fd780d93b6adee42854b977f585c0d591edae750f532887d6e56fc06e079cce85869e48e6f406ac816d9b92d0f88cc3943aca
b206266f1fc2c6096bc21f9e87a23683ab31af2b799da069b3887e376ea6255ff8859cd4e6a",
            "coin_spends": [
                {
                    "coin": {
                        "amount": 0,
                        "parent_coin_info": "0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
                        "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"
                    },
                    "puzzle_reveal": "0xff02ffff01ff02ffff01ff02ffff03ffff20ffff15ff5fff2f8080ffff01ff08ff8080ffff01ff02ffff03ffff15ff5fff0580ffff01ff04ffff
04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff0bffff04ff5fff80808080ffff04ffff04ff0affff04ff17ffff01ff80808080ffff04ffff
04ff0effff04ff5fff808080ff808080808080ffff01ff04ffff04ff08ffff04ff2fff808080ffff04ffff04ff0cffff04ff17ff808080ffff04ffff04ff0affff04ff17ffff04ff5fff80808080
ffff04ffff04ff0effff04ff5fff808080ff808080808080ff018080ff0180ffff04ffff01ffff4948ff333cff018080ffff04ffff018203e8ffff04ffff01a02e7b2c2b425a62895c97fce11b7a
476295f9d79d84b9ac5f85630e9c24b527e6ff01808080",
                    "solution": "0xffa0e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662ff80ff6480"
                },
                {
                    "coin": {
                        "amount": 100,
                        "parent_coin_info": "0xa45d9984341e4df60fd183739dc85780e433b2e1da876e973d4d0d83f6bbb795",
                        "puzzle_hash": "0x6924d1c432bd2a08ec9bc1e5e295406af64af7394045dcc9ca069a2572d9c3dc"
                    },
                    "puzzle_reveal": "0xff02ffff01ff02ffff01ff02ff0effff04ff02ffff04ff05ffff04ffff0bff0bff1780ff8080808080ffff04ffff01ff31ff3dff04ffff04ff0a
ffff04ff0bff808080ffff04ffff04ff04ffff04ff05ffff04ff0bff80808080ff808080ff018080ffff04ffff01b0b980a0ed9a2d74a437b2f47d0c7cc38833bca7aef614a8595f88bc7b22d92f
77e681a6cd594f93664b895cb2f5859d5dff018080",
                    "solution": "0xffa06c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143ff6480"
                }
            ]
        },
        "spend_bundle_name": "0x97afb3e7168f74df54c79050751b92d513dd47f1886d37ce2001b90ce6d938dc"
    }
}
```

Let's check our `piggybank` coin -

```
$ make coinrecord PUZZLEHASH=e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662
cdv rpc coinrecords --by puzhash e9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662 -nd
{
    "658522cd184023a13bbc4305852a465ff91b019720d1ade49e656d1815cdac86": {
        "coin": {
            "amount": 100,
            "parent_coin_info": "0x6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143",
            "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"
        },
        "coinbase": false,
        "confirmed_block_index": 623635,
        "spent": false,
        "spent_block_index": 0,
        "timestamp": 1632261963
    },
    "6c1e3a8fd1f4492b3adcf87975cd117b5977a61c94e5dff81bda9c4253d78143": {
        "coin": {
            "amount": 0,
            "parent_coin_info": "0x906ed912b6452305fa79fc13208dc153c7710853c5845f4d7a6aa26a0444061b",
            "puzzle_hash": "0xe9ce9a45a09a6def91bea36c46eb94ab4ba0d40e40650745112d2d0cf9a22662"
        },
        "coinbase": false,
        "confirmed_block_index": 623356,
        "spent": true,
        "spent_block_index": 623635,
        "timestamp": 1632256414
    }
}
```

We can see that we have successfully re-created the `piggybank` coin with a new value of `100` mojos. Its puzzle hash has not changed, so all the values we precommitted to remain the same.

You can repeat this process until you hit the target amount and trigger withdrawing. You can change the deposit amount in the `Makefile` to hit the target in fewer spends.

Of course you can also contribute to the above piggybank! Just make sure to query for the latest coinrecord first to ensure the `coin id` and `amount` match the state on the blockchain.
