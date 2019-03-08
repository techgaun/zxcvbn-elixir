# zxcvbn-elixir
> Elixir implementation of [zxcvbn](https://github.com/dropbox/zxcvbn) by dropbox

## Installation

```elixir
def deps do
  [
    {:zxcvbn, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
import ZXCVBN
zxcvbn("Some Password")
```
