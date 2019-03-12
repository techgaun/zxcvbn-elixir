defmodule ZXCVBN do
  @moduledoc """
  """

  import ZXCVBN.Utils,
    only: [
      time: 0
    ]

  alias ZXCVBN.{
    Feedback,
    Matching,
    Scoring,
    TimeEstimates
  }

  @spec zxcvbn(String.t(), [String.t()]) :: :ok
  def zxcvbn(string, user_inputs \\ []) do
    start = time()
    user_inputs = normalize_inputs(user_inputs)

    ranked_dictionaries =
      Map.new()
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
    |> Enum.map(&String.downcase/1)
  end
end
