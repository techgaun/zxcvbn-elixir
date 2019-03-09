defmodule ZXCVBN.Utils do
  @moduledoc """
  Helper functions
  """

  def file_to_list(file) do
    file
    |> File.read!()
    |> String.split("\n")
  end

  def time do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
  end

  @spec factorial(integer) :: integer
  def factorial(n) do
    do_factorial(n, 1)
  end

  defp do_factorial(n, fac) when n in 0..1, do: fac
  defp do_factorial(n, fac), do: do_factorial(n - 1, fac * n)

  @spec pow(integer, integer) :: integer
  def  pow(n, k), do: pow(n, k, 1)
  defp pow(_, 0, acc), do: acc
  defp pow(n, k, acc), do: pow(n, k - 1, n * acc)
end
