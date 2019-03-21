passwords = %{
  "simple passwords" => [
    "sam",
    "thomas",
    "THOMAS",
    "1234567890"
  ],
  "date passwords" => [
    "1191",
    "11/11/2018",
    "samar1990",
    "Samar1990"
  ],
  "l33t passwords" => [
    "H3ll0 W0rld",
    "l33tm4n"
  ],
  "repeats" => [
    "abcabcabc",
    "aaaaaa"
  ],
  "spatial" => [
    "asdflkjh",
    "34567890"
  ],
  "Strong passwords" => [
    "This is Very COmpl3x Passw0rd",
    "RojAuwyLp3X6jUcmitHUNhkLFUFOin"
  ]
}

passwords =
  for {prefix, list} <- passwords, password <- list, into: %{} do
    {"#{prefix}::#{password}", password}
  end

Benchee.run(
  %{
    "ZXCVBN.zxcvbn" => fn password -> ZXCVBN.zxcvbn(password) end
  },
  inputs: passwords,
  time: 20,
  formatters: [
    Benchee.Formatters.HTML
  ]
)
