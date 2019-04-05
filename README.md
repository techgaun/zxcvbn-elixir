# zxcvbn-elixir [![Build Status](https://travis-ci.org/techgaun/zxcvbn-elixir.svg?branch=master)](https://travis-ci.org/techgaun/zxcvbn-elixir) [![Hex Version](https://img.shields.io/hexpm/v/zxcvbn.svg)](https://hex.pm/packages/zxcvbn)

> Elixir implementation of [zxcvbn](https://github.com/dropbox/zxcvbn) by dropbox

## Installation

```elixir
def deps do
  [
    {:zxcvbn, "~> 0.1.3"}
  ]
end
```

## Usage

```elixir
import ZXCVBN

# default without user inputs

zxcvbn("Some Password")

# with user inputs; useful for adding to dictionary (for eg. submitted form inputs;
# think someone using their e-mail address as password for example)
zxcvbn("Password1", ["user@email.com", "Nepal", "Kathmandu"])
```

### Usage Notes

- Ideally, when you are using ZXCVBN, pass the first 100-200 characters only for reasonable latency.

## Output Description

The result of running `ZXCVBN.zxcvbn/1` and `ZXCVBN.zxcvbn/2` is a map
except for when empty string is supplied as password (which returns `:error`).

Below is a sample result and description of each fields.

```elixir
%{
  # how long it took zxcvbn to calculate an answer,
  # in milliseconds.
  calc_time: 51,

  # same keys as result.crack_times_seconds,
  # with friendlier display string values:
  # "less than a second", "3 hours", "centuries", etc.

  crack_times_display: %{
    offline_fast_hashing_1e10_per_second: "less than a second",
    offline_slow_hashing_1e4_per_second: "less than a second",
    online_no_throttling_10_per_second: "less than a second",
    online_throttling_100_per_hour: "1 minute"
  },

  # dictionary of back-of-the-envelope crack time
  # estimations, in seconds, based on a few scenarios

  crack_times_seconds: %{
    # offline attack with user-unique salting but a fast hash
    # function like SHA-1, SHA-256 or MD5. A wide range of
    # reasonable numbers anywhere from one billion - one trillion
    # guesses per second, depending on number of cores and machines.
    # ballparking at 10B/sec.

    offline_fast_hashing_1e10_per_second: 3.0e-10,

    # offline attack. assumes multiple attackers,
    # proper user-unique salting, and a slow hash function
    # w/ moderate work factor, such as bcrypt, scrypt, PBKDF2.

    offline_slow_hashing_1e4_per_second: 0.0003,

    # online attack on a service that doesn't ratelimit,
    # or where an attacker has outsmarted ratelimiting.

    online_no_throttling_10_per_second: 0.3,

    # online attack on a service that ratelimits password auth attempts

    online_throttling_100_per_hour: 108.0
  },

  # verbal feedback to help choose better passwords. set when score <= 2.
  feedback: %{

    # a possibly-empty list of suggestions to help choose a less
    # guessable password. eg. 'Add another word or two'
    suggestions: ["Add another word or two. Uncommon words are better.",
     "Predictable substitutions like '@' instead of 'a' don't help very much"],

    # explains what's wrong, eg. 'this is a top-10 common password'.
    # not always set -- sometimes an empty string
    warning: ""
  },

  # estimated guesses needed to crack password
  guesses: 3,

  # order of magnitude of guesses
  guesses_log10: 0.47712125471966244,

  # input password
  password: "password",

  # Integer from 0-4 (useful for implementing a strength bar)
  # 0 too guessable: risky password. (guesses < 10^3)
  # 1 very guessable: protection from throttled online attacks. (guesses < 10^6)
  # 2 somewhat guessable: protection from unthrottled online attacks. (guesses < 10^8)
  # 3 safely unguessable: moderate protection from offline slow-hash scenario. (guesses < 10^10)
  # 4 very unguessable: strong protection from offline slow-hash scenario. (guesses >= 10^10)
  score: 0,

  # the list of patterns that zxcvbn based the
  # guess calculation on.
  sequence: [
    %{
      base_guesses: 2,
      dictionary_name: :passwords,
      guesses: 2,
      guesses_log10: 0.3010299956639812,
      i: 0,
      j: 7,
      l33t: false,
      l33t_variations: 1,
      matched_word: "password",
      pattern: :dictionary,
      rank: 2,
      reversed: false,
      token: "password",
      uppercase_variations: 1
    }
  ]
}
```

## Benchmark

The basic benchmark result can be seen by running:

```shell
mix run bench/run.exs
```

That will create html output on `benchmarks` directory.

## Test

The [zxcvbn.js](zxcvbn.js) is used to test the [correctness](test/zxcvbn_test.exs)
with the original implementation. ZXCVBN is a pure Elixir implementation
and not a wrapper on top of javascript version.

### Test Setup

```
npm install
mix test
```

## Author

- [Samar Acharya](https://github.com/techgaun)
