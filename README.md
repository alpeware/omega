# omega
> Get all the Omega-3 fatty acids from your Chia

![GitHub contributors](https://img.shields.io/github/contributors/alpeware/omega?logo=GitHub)

## Goal
Omega aims to provide a standard library for Chialisp's high level language.

## Status
This is currently in ALPHA stage. The functions have not been tested on mainnet and have not been optimized for cost or performance. The goal is to get the community's feedback and work towards a first official release.

## Installing
For now, clone this repo and include `lib/omega.clib` in your Chialisp project -

```chialisp
(mod ()
  (include "omega.clib")

;; your code
)
```

Make sure to specify the directory when running your code -

`run -i omega/lib foo.clsp`

## Example
This is the rewritten piggybank example from the tutorial:

`puzzles/piggybank/piggybank.clsp`
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

`puzzles/piggybank.clib`
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

`puzzles/piggybank/piggybank_test.clsp`
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



Running the tests

```
$ time make -j2
"brun" "`"run" -i "../../lib" -i . piggybank_test.clsp`"
"brun" "`"run" -i "../../lib" -i . deposit_test.clsp`"
("piggybank tests" "throws when new amount too low: PASS" "deposit coin: PASS" "withdraw when above target: PASS")
("deposit tests" "hash value: PASS" "asserts coin announcement: PASS" "asserts signature: PASS")

real    5m3.032s
user    10m2.851s
sys     0m0.735s

```

See `puzzles/piggybank` for the full code example with a step-by-step walkthrough.

## Guide
The library is organized into the following modules:

- core
- functional
- conditions
- crypto
- strings


### Core

The standard operators are mapped to their full names in order to improve readability:

```
;; constants
(defconstant true 1)
(defconstant false 0)

;; core ops
(defun-inline < (a b) (and (not (= a b)) (not (> a b))))
(defun-inline <s (a b) (and (not (= a b)) (not (>s a b))))
(defun-inline apply (func args) (a func args))
(defun-inline cons (x xs) (c x xs))
(defun-inline dec (a) (- a 1))
(defun-inline first (xs) (f xs))
(defun-inline inc (a) (+ a 1))
(defun-inline listp (xs) (l xs))
(defun-inline rest (xs) (r xs))
(defun-inline second (xs) (f (r xs)))
(defun-inline third (xs) (f (r (r xs))))
```

```
(and e f g)
```

Evaluates arguments one at a time, from left to right. If any of the arguments returns logical `false`, returns `false` and doesn't evaluate any of the other expressions, otherwise it returns `true`.

```
(or e f g)
```

Evaluates arguments one at a time, from left to right. If any of the arguments returns logical `true`, returns `true` and doesn't evaluate any of the other expressions, otherwise it returns `false`.

```
(cond
  (= 100 200) false
  (= 200 300) false
  else true)
```

The `cond` form chains a series of tests to select a result expression.
Each test-expression is evaluated in order. If a test returns logical `true`,
`cond` evaluates and returns the value of the corresponding expression and doesn't
evaluate any of the other tests or expressions.

The last test-expression in a `cond` can be replaced by `else`. In terms of evaluation, `else` serves as a synonym for true, but it clarifies that the last clause is meant to catch all remaining cases.

```
(throw "guru meditation")
```

Throw is a wrapper around x.

There are two macros to help with testing: `assert` and `test`.

```
(assert (> 2 1) (= 100 200))
```

Assert evaluates its arguments in order and returns `false` if any of them evaluate
to `false`. Otherwise returns `true`.

```
(list
  (test "a test" (assert (= 100 100)))
  (test "another test" (assert (= 200 200))))
```

Test takes a string as its first argument and an expression as its second argument.
Throws an exception if the second argument returns `false` with the first argument
as the exception string. Otherwise returns the string.

Multiple tests can be added in a list and should be used with assert.

See tests for each module for more examples.

### Functional

```
(equal
  (list 100 200)
  (list 100 200))

;; true
```

Compares two lists and returns `true` if they contain the same atoms in the same order. Does not support nested lists.

```
(map
  constantly
  (list 100 200 300))

;; (1 1 1)
```

Returns the result of applying the function provided in the first argument to
the elements of the list in the second argument from first to last.

```
(filter
  odd?
  (list 100 101 102 103))

;; (101 103)
```
Returns the items from the list provided as the second argument for which the function in the first argument returns logical `true`.

```
(remove
  odd?
  (list 100 101 102 103))

;; (100 102)
```
Returns the items from the list provided as the second argument for which the function in the first argument returns logical `false`.

```
(reduce
  sum
  0
  (list 1 2 3 4 5))

;; 15
```

Returns the result of applying the function provided in the first argument to the initial value in the second argument and the first element of the list in the third argument, then applying the function to that result and the second item, etc.


```
(some
  odd?
  (list 100 101 102 103))

;; 101
```
Returns the first item from the list provided as the second argument for which the function in the first argument returns logical `true`.

```
(contains 200 (list 100 200 300))

;; true
```
Returns true if the first argument is present in the list provided as the second argument, otherwise returns false.

```
(count (list 100 200 300))

;; 3
```
Returns the number of items in the collection.

```
(range 0 10 2)

;; (0 2 4 6 8)
```
Returns a list of integers from start (inclusive) provided in the first argument to end (exclusive) provided in the second argument, by step provided as the third argument.

```
(append (list 100 200) (list 300 400))

;; (100 200 300 400)
```
Returns a list that contains all of the elements of the list in the first argument prepended to the list in the second argument in order.

```
(flatten (list 100 200 (list 300 400)))

;; (100 200 300 400)
```
Takes any nested combination of lists and returns their contents as a single, flat list.

```
(reverse (list 100 200 300))

;; (300 200 100)
```
Returns a list of the items provided in the list of the first argument in reverse order.

```
(last (list 100 200 300))

;; 300
```
Returns the last element of the list provided in the first argument.

```
(take 2 (list 100 200 300 400))

;; (100 200)
```
Returns a list of the first n elements of the list provided in the first argument.

```
(drop 2 (list 100 200 300 400))

;; (300 400)
```
Returns all but the first n elements of the list provided in the first argument.

```
(sort (list 300 100 200 500))

;; (100 200 300 500)
```
Returns the elements of the list provided as the first argument in sorted order using a merge sort.

### Conditions

Assert facts -

```
 (assert-coin-announcement (hash))

 (assert-puzzle-announcement (hash))

 (assert-amount (amount))

 (assert-coin-id (id))

 (assert-parent-id (id))

 (assert-puzzle-hash (puzzle-hash))

 (assert-relative-seconds (secs))

 (assert-absolute-seconds (secs))

 (assert-relative-height (height))

 (assert-absolute-height (height))
```

Create a new coin
```
 (coin (puzzle-hash amount))
```

Announce coins and puzzles

```
 (announce-coin (amount))

 (announce-puzzle (hash))
```

Sign messages
```
 (sign (pubkey message))

 (sign-unsafe (pubkey message))
```

### Crypto
```
(sha256tree (list "chia" (list "chialisp"))
```
Produces the sha256 hash of the sexp provided as the first argument by walking the tree in a depth first manner labeling branch nodes with a 2 and prepending the atoms of leaf nodes with a 1.

### Strings
```
(split "chia chialisp mojo" " ")

;; ("chia" "chialisp" "mojo")
```
Returns a list of the words in the string provided in the first argument, separated by the delimiter string provided in the second argument.

```
(starts-with? "chialisp" "chia")

;; true
```
Returns logical true if the string provided in the first argument starts with the string provided as the second argument.

```
(blank? "chia")

;; false
```
Returns logical true if the string provided as the first argument has length zero.

```
(upper-case "chialisp")

;; "CHIALISP"
```
Returns the result of converting the string provided as the first argument to upper-case.

```
(hex 127)

;; 7f
```
Returns the result of converting the byte provided as the first argument to its hexadecimal string representation.


## Running tests
There is a test suite included under tests. If any of the tests fail, it will throw an exception.

Please note that this currently takes a while to run all tests. Also note that you will have to pass the result from the stage2 compilation to the VM to fully execute the code.

There is a `Makefile` included to run the tests. You can use the `-j` option to run the tests in parallel:

```
$ time make -j4
"brun" "`"run" -i "lib" "lib"/core_test.clsp`"
"brun" "`"run" -i "lib" "lib"/crypto_test.clsp`"
"brun" "`"run" -i "lib" "lib"/functional_test.clsp`"
"brun" "`"run" -i "lib" "lib"/strings_test.clsp`"
("crypto tests" "sha256 tree: PASS")
("core tests" "atom is less than: PASS" "string is less than: PASS" "inc: PASS" "dec: PASS" "second: PASS" "third: PASS" "and: PASS" "or: PASS" "cond: PASS" "comment: PASS")
("strings tests" "split fn: PASS" "starts-with? fn: PASS" "blank? fn: PASS" "upper-case fn: PASS" "hex fn: PASS")
("functional tests" "equal fn: PASS" "map fn: PASS" "filter fn: PASS" "remove fn: PASS" "reduce fn: PASS" "some fn: PASS" "contains fn: PASS" "count fn: PASS" "range fn: PASS" "append fn: PASS" "flatten fn: PASS" "reverse fn: PASS" "last fn: PASS" "take fn: PASS" "drop fn: PASS" "sort fn: PASS")

real    11m48.580s
user    17m36.292s
sys     0m0.795s
```
## Style Guide
This is loosely based on Peter Norvig and Kent Pitman's [style guide](http://norvig.com/luv-slides.pdf) for Common Lisp.

### Formatting
Indentation should be two lines per form.

Lines should not exceed 100 columns.



### Comment Hierarchy
Comments that start with four semicolons, `;;;;`, should appear at the top of a file, explaining its purpose.

Comments starting with three semicolons, `;;;`, should be used to separate regions of the code.

Comments with two semicolons, `;;`, should describe regions of code within a function or some other top-level form, while single-semicolon comments, `;`, should just be short notes on a single line.

### Flow Control
Use `if` when you have a `true` branch and a `false` branch.

Use `cond` when you have several conditional branches.

`and`, `or` for boolean values only.

### Functional Abstraction
Every function should have
- A single specific purpose
- If possible, a generally useful purpose
- A meaningful name
- A structure that is simple to understand
- An interface that is simple yet general enough
- As few dependencies as possible
- A documentation string

### Control Abstraction
Most algorithms can be characterized as
- Searching
- Sorting
- Filtering
- Mapping
- Combining
- Counting

### Naming Conventions
- Be consistent
- Use lower case kebab case for variable names and upper case kebab case for constants
- Name functions verb-object or object-attribute
- Order arguments consistently
- Do not shadow a local variable with another
- Minimize abbreviations

## Open questions
- Slow compile times
- Namespaces
- Dependency management

## Contribute
Feel free to file issues and send pull requests.

## About Chialisp
[Chialisp](https://chialisp.com/) is a LISP dialect targeting the Chialisp VM. It is the primary language used to write smart contracts for the [Chia Network](https://www.chia.net/).

## Credits
Some descriptions and naming is borrowed from other LISPS namely Clojure, Scheme and Racket.

## Disclaimer
This is a community project and not officially affiliated with Chia Network.

## License
Copyright &copy; 2021 Alpeware

Licensed under the MIT License
