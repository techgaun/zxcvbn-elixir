defmodule ZXCVBN do
  @moduledoc """
  ZXCVBN is an Elixir implemenation of [ZXCVBN][zxcvbn-gh].
  The original paper is available [here][zxcvbn-paper].

  The usage is simple:

      iex> ZXCVBN.zxcvbn("password")
        %{
        calc_time: 51,
        crack_times_display: %{
          offline_fast_hashing_1e10_per_second: "less than a second",
          offline_slow_hashing_1e4_per_second: "less than a second",
          online_no_throttling_10_per_second: "less than a second",
          online_throttling_100_per_hour: "1 minute"
        },
        crack_times_seconds: %{
          offline_fast_hashing_1e10_per_second: 3.0e-10,
          offline_slow_hashing_1e4_per_second: 0.0003,
          online_no_throttling_10_per_second: 0.3,
          online_throttling_100_per_hour: 108.0
        },
        feedback: %{
          suggestions: ["Add another word or two. Uncommon words are better.",
           "Predictable substitutions like '@' instead of 'a' don't help very much"],
          warning: ""
        },
        guesses: 3,
        guesses_log10: 0.47712125471966244,
        password: "password",
        score: 0,
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

  You can also pass of list of user inputs
  that will act as additional dictionary.
  This is useful for checking if the password
  is not same or variant of associated user inputs.

      iex> ZXCVBN.zxcvbn("nepal", ["samar", "mustang", "nepal", "hello@example.com"])

  [zxcvbn-gh]: https://github.com/dropbox/zxcvbn
  [zxcvbn-paper]: https://www.usenix.org/system/files/conference/usenixsecurity16/sec16_paper_wheeler.pdf
  """

  import ZXCVBN.Utils,
    only: [
      time: 0,
      downcase: 1
    ]

  alias ZXCVBN.{
    Feedback,
    Matching,
    Scoring,
    TimeEstimates
  }

  @spec zxcvbn(String.t(), [String.t()]) :: map | :error
  def zxcvbn(string, user_inputs \\ [])

  def zxcvbn("", _user_inputs) do
    :error
  end

  def zxcvbn(string, user_inputs) do
    start = time()
    user_inputs = normalize_inputs(user_inputs)

    ranked_dictionaries =
      Map.new()
      |> Matching.add_frequency_lists()
      |> Map.put(:user_inputs, Matching.build_ranked_dict(user_inputs))

    matches = Matching.omnimatch(string, ranked_dictionaries)

    result =
      string
      |> Scoring.most_guessable_match_sequence(matches)
      |> Map.put(:calc_time, time() - start)

    result =
      result[:guesses]
      |> TimeEstimates.estimate_attack_times()
      |> Enum.reduce(result, fn {prop, val}, result ->
        Map.put(result, prop, val)
      end)

    Map.put(
      result,
      :feedback,
      Feedback.get_feedback(result[:score], result[:sequence])
    )
  end

  defp normalize_inputs(user_inputs) do
    user_inputs
    |> Stream.map(&to_string/1)
    |> Enum.map(&downcase/1)
  end
end
