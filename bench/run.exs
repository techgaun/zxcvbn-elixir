# this gives us a rough idea of performance
# comparison with executing js with node binary
# is most likely to not reflect actual real data
# but still gives us a good reference
node_script = "#{File.cwd!()}/zxcvbn.js"

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
    "aaaaaa",
    String.duplicate("aQs", 50),
    String.duplicate("sam", 50)
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
    "ZXCVBN.zxcvbn" => fn password -> ZXCVBN.zxcvbn(password) end,
    "zxcvbn-javascript" => fn password ->
      {_r, 0} = System.cmd(node_script, [password])
    end
  },
  inputs: passwords,
  time: 20,
  formatters: [
    Benchee.Formatters.HTML
  ]
)
