defmodule ZXCVBN.Scoring do
  @moduledoc """
  Score calculation
  """

  def calc_average_degree(graph) do
    graph
    |> Enum.reduce(0, fn {_key, neighbors}, sum ->
      sum + length(neighbors)
    end)
    |> Kernel./(length(graph) * 1.0)
  end

  @bruteforce_cardinality 10
  @min_guesses_before_growing_sequence 10_000
  @min_submatch_guesses_single_char 10
  @min_submatch_guesses_multi_char 50
  @min_year_space 20
  @reference_year Date.utc_today().year

  @doc """
  Reference: http://blog.plover.com/math/choose.html
  """
  def nCk(n, k) when k > n, do: 0
  def nCk(_n, 0), do: 1
  def nCk(n, k) do
    {r, _n} =
      Enum.reduce(1..(k + 1), {1, n}, fn d, {r, n} ->
        {((r * n) / d), n - 1}
      end)

    r
  end

  # ------------------------------------------------------------------------------
  # search --- most guessable match sequence -------------------------------------
  # ------------------------------------------------------------------------------
  #
  # takes a sequence of overlapping matches, returns the non-overlapping sequence with
  # minimum guesses. the following is a O(l_max * (n + m)) dynamic programming algorithm
  # for a length-n password with m candidate matches. l_max is the maximum optimal
  # sequence length spanning each prefix of the password. In practice it rarely exceeds 5 and the
  # search terminates rapidly.
  #
  # the optimal "minimum guesses" sequence is here defined to be the sequence that
  # minimizes the following function:
  #
  #    g = l! * Product(m.guesses for m in sequence) + D^(l - 1)
  #
  # where l is the length of the sequence.
  #
  # the factorial term is the number of ways to order l patterns.
  #
  # the D^(l-1) term is another length penalty, roughly capturing the idea that an
  # attacker will try lower-length sequences first before trying length-l sequences.
  #
  # for example, consider a sequence that is date-repeat-dictionary.
  #  - an attacker would need to try other date-repeat-dictionary combinations,
  #    hence the product term.
  #  - an attacker would need to try repeat-date-dictionary, dictionary-repeat-date,
  #    ..., hence the factorial term.
  #  - an attacker would also likely try length-1 (dictionary) and length-2 (dictionary-date)
  #    sequences before length-3. assuming at minimum D guesses per pattern type,
  #    D^(l-1) approximates Sum(D^i for i in [1..l-1]
  #
  # ------------------------------------------------------------------------------
  def most_guessable_match_sequence(password, matches, exclude_additive? \\ false) do
    n = String.length(password)
    # partition matches into sublists according to ending index j
    matches_by_j = List.duplicate([], n)
  end
end
