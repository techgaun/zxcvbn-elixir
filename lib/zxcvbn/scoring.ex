defmodule ZXCVBN.Scoring do
  @moduledoc """
  Score calculation
  """

  import ZXCVBN.Utils
  import ZXCVBN.AdjacencyGraphs, only: [adjacency_graph: 0]

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
    matches_by_j =
      matches
      |> Enum.map(fn m ->
        List.update_at(matches_by_j, m[:j], &(&1 ++ [m]))
      end)
      |> Enum.map(fn list ->
        Enum.sort(list, &(&1[:i] >= &2[:i]))
      end)

    placeholder = List.duplicate(%{}, 10)
    optimal = %{
      m: placeholder,
      pi: placeholder,
      g: placeholder
    }
  end

  defp estimate_guesses(%{guesses: guesses}, _password) when not is_nil(guesses) do
    guesses
  end

  defp estimate_guesses(%{token: token, pattern: pattern, guesses: guesses} = match, password) do
    token_len = String.length(token)

    min_guesses =
      if token_len < String.length(password) do
        if token_len === 1, do: @min_submatch_guesses_single_char, else: @min_submatch_guesses_multi_char
      else
        1
      end

    guesses = apply(__MODULE__, :"#{pattern}_guesses", [match])
    guesses = max(guesses, min_guesses)
    # guesses_log10 = :math.log10(guesses) # seems to be calculated but unused
    guesses
  end

  @doc false
  def bruteforce_guesses(%{token: token} = _match) do
    token_len = String.length(token)
    guesses = pow(@bruteforce_cardinality, token_len)
    # small detail: make bruteforce matches at minimum one guess bigger than
    # smallest allowed submatch guesses, such that non-bruteforce submatches
    # over the same [i..j] take precedence.
    min_guesses =
      if token_len === 1 do
        @min_submatch_guesses_single_char + 1
      else
        @min_submatch_guesses_multi_char + 1
      end

    max(guesses, min_guesses)
  end

  @doc false
  def repeat_guesses(%{base_guesses: base_guesses, repeat_count: repeat_count} = _match) do
    base_guesses * repeat_count
  end

  @doc false
  def sequence_guesses(%{token: token} = match) do
    first_chr = String.first(token)
    # lower guesses for obvious starting points
    base_guesses =
      cond do
        first_chr in ["a", "A", "z", "Z", "0", "1", "9"] ->
          4

        Regex.match?(~r/\d/, first_chr) ->
          10

        true ->
          # could give a higher base for uppercase,
          # assigning 26 to both upper and lower sequences is more
          # conservative.
          26
      end

    base_guesses = if is_nil(Map.get(match, :ascending)), do: base_guesses * 2, else: base_guesses

    base_guesses * String.length(token)
  end

  @char_class_bases %{
    alpha_lower: 26,
    alpha_upper: 26,
    alpha: 52,
    alphanumeric: 62,
    digits: 10,
    symbols: 33
  }
  @char_class_bases_names Map.keys(@char_class_bases)

  @doc false
  def regex_guesses(%{token: token} = match) do
    char_class_base = Map.get(match, :regex_name)
    cond do
      char_class_base in @char_class_bases_names ->
        pow(@char_class_bases[char_class_base], String.length(token))

      char_class_base === 'recent_year' ->
        # conservative estimate of year space: num years from `@reference_year`.
        # if year is close to `@reference_year`, estimate a year space of
        # `@min_year_space`
        year_space =
          match
          |> Map.get(:regex_match)
          |> hd()
          |> String.to_integer()
          |> Kernel.-(@reference_year)
          |> abs()

        max(year_space, @min_year_space)

      true ->
        nil
    end
  end

  @doc false
  def date_guesses(%{year: year} = match) do
    year_space =
      year
      |> Kernel.-(@reference_year)
      |> abs()
      |> max(@min_year_space)

    guesses = year_space * 365

    if Map.get(match, :separator), do: guesses * 4, else: guesses
  end

  @qwerty_graph adjacency_graph()[:qwerty]
  @keypad_graph adjacency_graph()[:keypad]
  @keyboard_average_degree calc_average_degree(@qwerty_graph)
  # slightly different for keypad/mac keypad, but close enough
  @keypad_average_degree calc_average_degree(@keypad_graph)
  @keyboard_starting_positions map_size(@qwerty_graph)
  @keypad_starting_positions map_size(@keypad_graph)

  def spatial_guesses(%{graph: graph, token: token} = match) do
    {s, d} =
      if graph in ["qwerty", "dvorak"] do
        {@keyboard_starting_positions, @keyboard_average_degree}
      else
        {@keypad_starting_positions, @keypad_average_degree}
      end

    l = String.length(token)
    t = Map.get(match, :turns)

    # estimate the number of possible patterns w/ length L or less with t turns
    # or less.
    guesses =
      Enum.reduce(2..l, 0, fn i, guesses ->
        possible_turns = min(t, i - 1)
        1..possible_turns
        |> Enum.map(fn j ->
          nCk(i - 1, j - 1) * s * pow(d, j)
        end)
        |> Enum.sum()
        |> Kernel.+(guesses)
      end)

    if s = Map.get(match, :shifted_count) do
      u = l - s # unshifted count

      if s === 0 or u === 0 do
        guesses * 2
      else
        1..(min(s, u))
        |> Enum.map(& nCk(s + u, &1))
        |> Kernel.*(guesses)
      end
    else
      guesses
    end

    # add extra guesses for shifted keys. (% instead of 5, A instead of a.)
    # math is similar to extra guesses of l33t substitutions in dictionary
    # matches.
  end

  @doc false
  def dictionary_guesses(%{rank: rank} = match) do
    match =
      match
      |> Map.put(:base_guesses, rank)
      |> Map.put(:uppercase_variations, uppercase_variations(match))
      |> Map.put(:l33t_variations, l33t_variations(match))

    reversed_variations = if Map.get(match, :reversed, false), do: 2, else: 1

    (
      match[:base_guesses] * match[:uppercase_variations] *
        match[:l33t_variations] * reversed_variations
    )
  end

  @start_upper ~r'^[A-Z][^A-Z]+$'
  @end_upper ~r'^[^A-Z]+[A-Z]$'
  @all_upper ~r'^[^a-z]+$'
  @all_lower ~r'^[^A-Z]+$'

  defp uppercase_variations(%{token: word} = _match) do
    cond do
      Regex.match?(@all_lower, word) or String.downcase(word) === word ->
        1

      Enum.any?([@start_upper, @end_upper, @all_upper], & Regex.match?(&1, word)) ->
        2

      true ->
        {u, l} =
          word
          |> to_charlist()
          |> Enum.reduce({0, 0}, fn
            chr, {u, l} when chr in ?A..?Z ->
              {u + 1, l}
            chr, {u, l} when chr in ?a..?z ->
              {u, l + 1}

            _chr, {u, l} -> {u, l}
          end)

        Enum.reduce(1..min(u, l), 0, fn i, variations ->
          variations + nCk(u + l, i)
        end)
    end
  end

  defp l33t_variations(%{token: token, sub: sub, l33t: l33t} = _match) when not is_nil(l33t) do
    Enum.reduce(sub, 1, fn {subbed, unsubbed}, variations ->
      # lower-case match.token before calculating: capitalization shouldn't
      # affect l33t calc.
      {s, u} =
        token
        |> String.downcase()
        |> to_charlist()
        |> Enum.reduce({0, 0}, fn
          chr, {s, u} when chr === subbed ->
            {s + 1, u}
          chr, {s, u} when chr === unsubbed ->
            {s, u + 1}

          _chr, {s, u} ->
            {s, u}
        end)

      if s === 0 or u === 0 do
        # for this sub, password is either fully subbed (444) or fully
        # unsubbed (aaa) treat that as doubling the space (attacker needs
        # to try fully subbed chars in addition to unsubbed.)
        variations * 2
      else
        # this case is similar to capitalization:
        # with aa44a, U = 3, S = 2, attacker needs to try unsubbed + one
        # sub + two subs
        p = min(u, s)
        1..p
        |> Enum.map(& nCk(u + s, &1))
        |> Enum.sum()
        |> Kernel.*(variations)
      end
    end)
  end

  defp l33t_variations(_match), do: 1
end
