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

  def strlen_bruteforce(string) do
    string
    |> to_charlist()
    |> Enum.reduce(0, fn
      i, len when i >= 0 and i <= 65535 ->
        len + 1

      _i, len ->
        len + 2
    end)
  end

  def strlen(string) do
    case mode() do
      :default ->
        String.length(string)

      _ ->
        byte_size(string)
    end
  end

  def slice(string, l..r//_) do
    slice(string, l, r - l + 1)
  end

  def slice(string, start_pos, len) do
    case mode() do
      :default ->
        String.slice(string, start_pos, len)

      _ ->
        binary_part(string, start_pos, len)
    end
  end

  def downcase(string) do
    String.downcase(string, mode())
  end

  @spec factorial(integer) :: integer
  def factorial(n) do
    do_factorial(n, 1)
  end

  defp do_factorial(n, fac) when n in 0..1, do: fac
  defp do_factorial(n, fac), do: do_factorial(n - 1, fac * n)

  @spec pow(number, number) :: number
  def pow(n, k), do: pow(n, k, 1)
  defp pow(_, 0, acc), do: acc
  defp pow(n, k, acc), do: pow(n, k - 1, n * acc)

  def calc_average_degree(graph) do
    graph
    |> Enum.reduce(0, fn {_key, neighbors}, sum ->
      neighbors
      |> Stream.filter(&(not is_nil(&1)))
      |> Enum.count()
      |> Kernel.+(sum)
    end)
    |> Kernel./(map_size(graph) * 1.0)
  end

  defp mode, do: Application.get_env(:zxcvbn, :mode, :default)
end
