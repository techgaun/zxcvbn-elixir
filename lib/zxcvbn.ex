defmodule ZXCVBN do
  @moduledoc """
  """

  alias ZXCVBN.{
    Feedback,
    Matching,
    Scoring,
    TimeEstimates
  }

  @spec zxcvbn(String.t(), [String.t()]) :: :ok
  def zxcvbn(string, user_inputs \\ []) do
    user_inputs = normalize_inputs(user_inputs)
    :ok
  end

  defp normalize_inputs(user_inputs) do
    user_inputs
    |> Stream.map(&to_string/1)
    |> Enum.map(&String.downcase/1)
  end
end
