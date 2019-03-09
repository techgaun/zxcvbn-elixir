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
    Enum.map(user_inputs, &String.downcase/1)
  end
end
