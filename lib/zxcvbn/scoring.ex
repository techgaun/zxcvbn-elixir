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
        {r * n / d, n - 1}
      end)

    r
  end

  @doc """
  ------------------------------------------------------------------------------
  search --- most guessable match sequence -------------------------------------
  ------------------------------------------------------------------------------

  takes a sequence of overlapping matches, returns the non-overlapping sequence with
  minimum guesses. the following is a O(l_max * (n + m)) dynamic programming algorithm
  for a length-n password with m candidate matches. l_max is the maximum optimal
  sequence length spanning each prefix of the password. In practice it rarely exceeds 5 and the
  search terminates rapidly.

  the optimal "minimum guesses" sequence is here defined to be the sequence that
  minimizes the following function:

     g = l! * Product(m.guesses for m in sequence) + D^(l - 1)

  where l is the length of the sequence.

  the factorial term is the number of ways to order l patterns.

  the D^(l-1) term is another length penalty, roughly capturing the idea that an
  attacker will try lower-length sequences first before trying length-l sequences.

  for example, consider a sequence that is date-repeat-dictionary.
   - an attacker would need to try other date-repeat-dictionary combinations,
     hence the product term.
   - an attacker would need to try repeat-date-dictionary, dictionary-repeat-date,
     ..., hence the factorial term.
   - an attacker would also likely try length-1 (dictionary) and length-2 (dictionary-date)
     sequences before length-3. assuming at minimum D guesses per pattern type,
     D^(l-1) approximates Sum(D^i for i in [1..l-1]

  ------------------------------------------------------------------------------
  """
  def most_guessable_match_sequence(password, matches, exclude_additive? \\ false) do
    n = String.length(password) - 1
    # partition matches into sublists according to ending index j
    matches_by_j = Enum.into(0..n, %{}, & {&1, []})

    matches_by_j =
      matches
      |> Enum.reduce(matches_by_j, fn m, matches_by_j ->
        Map.update(matches_by_j, m[:j], [], &(&1 ++ [m]))
      end)
      |> Enum.into(%{}, fn {k, list} ->
        {k, Enum.sort(list, &(&1[:i] >= &2[:i]))}
      end)

    placeholder = Enum.into(0..n, %{}, & {&1, %{}})

    optimal = %{
      m: placeholder,
      pi: placeholder,
      g: placeholder
    }

    # helper: considers whether a length-l sequence ending at match m is better
    # (fewer guesses) than previously encountered sequences, updating state if
    # so.
    update = fn m, l, optimal ->
      k = m[:j]
      pi = estimate_guesses(m, password)

      pi =
        if l > 1 do
          # we're considering a length-l sequence ending with match m:
          # obtain the product term in the minimization function by
          # multiplying m's guesses by the product of the length-(l-1)
          # sequence ending just before m, at m.i - 1.
          pi * optimal[:pi][m[:i] - 1][l - 1]
        else
          pi
        end

      # calculate the minimization func
      g = factorial(l) * pi
      g = if exclude_additive?, do: g, else: g + pow(@min_guesses_before_growing_sequence, l - 1)

      # update state if new best.
      # first see if any competing sequences covering this prefix, with l or
      # fewer matches, fare better than this sequence. if so, skip it and
      # return.

      continue? =
        Enum.reduce_while(optimal[:g][k], true, fn {competing_l, competing_g}, acc ->
          cond do
            competing_l > l ->
              {:halt, true}

            competing_g <= g ->
              {:halt, false}

            true ->
              {:cont, acc}
          end
        end)

      if continue? do
        optimal
        |> put_in([:g, k, l], g)
        |> put_in([:m, k, l], m)
        |> put_in([:pi, k, l], pi)
      else
        optimal
      end
    end

    # helper: evaluate bruteforce matches ending at k.
    bruteforce_update = fn k, password, optimal ->
      # see if a single bruteforce match spanning the k-prefix is optimal.
      m = make_bruteforce_match(0, k, password)
      optimal = update.(m, 1, optimal)

      Enum.reduce(1..(k + 1), optimal, fn i, optimal ->
        # generate k bruteforce matches, spanning from (i=1, j=k) up to
        # (i=k, j=k). see if adding these new matches to any of the
        # sequences in optimal[i-1] leads to new bests.
        m = make_bruteforce_match(i, k, password)

        Enum.reduce(optimal[:m][i - 1], optimal, fn {l, last_m}, optimal ->
          # corner: an optimal sequence will never have two adjacent
          # bruteforce matches. it is strictly better to have a single
          # bruteforce match spanning the same region: same contribution
          # to the guess product with a lower length.
          # --> safe to skip those cases.
          if Map.get(last_m, :pattern) === :bruteforce do
            optimal
          else
            update.(m, l + 1, optimal)
          end
        end)
      end)
    end

    # helper: step backwards through optimal.m starting at the end,
    # constructing the final optimal match sequence.
    unwind = fn n, optimal ->
      k = n - 1
      # find the final best sequence length and score
      l = nil
      g = :infinity

      {l, _g} =
        Enum.reduce(optimal[:g][k], {l, g}, fn
          {candidate_l, candidate_g}, {_l, g} when candidate_g < g ->
            {candidate_l, candidate_g}

          _, {l, g} ->
            {l, g}
        end)

      optimal_match_sequence_fun(k, l, optimal, [])
    end

    optimal =
      Enum.reduce(0..(n - 1), optimal, fn k, optimal ->
        optimal =
          Enum.reduce(matches_by_j[k], optimal, fn m, optimal ->
            if m[:i] > 0 do
              Enum.reduce(0..optimal[:m][m[:i] - 1], optimal, fn l, optimal ->
                update.(m, l + 1, optimal)
              end)
            else
              update.(m, 1, optimal)
            end
          end)

        bruteforce_update.(k, password, optimal)
      end)

    optimal_match_sequence = unwind.(n, optimal)
    optimal_l = length(optimal_match_sequence)

    # corner: empty password
    guesses =
      if String.length(password) === 0 do
        1
      else
        optimal[:g][n - 1][optimal_l]
      end

    # final result object
    %{
      password: password,
      guesses: guesses,
      guesses_log10: :math.log10(guesses),
      sequence: optimal_match_sequence
    }
  end

  defp optimal_match_sequence_fun(-1, _l, _optimal, optimal_match_sequence),
    do: optimal_match_sequence

  defp optimal_match_sequence_fun(k, l, optimal, optimal_match_sequence) do
    m = optimal[:m][k][l]

    optimal_match_sequence_fun(
      m[:i] - 1,
      l - 1,
      optimal,
      [m | optimal_match_sequence]
    )
  end

  defp estimate_guesses(%{guesses: guesses}, _password) when not is_nil(guesses) do
    guesses
  end

  defp estimate_guesses(%{token: token, pattern: pattern} = match, password) do
    token_len = String.length(token)

    min_guesses =
      if token_len < String.length(password) do
        if token_len === 1,
          do: @min_submatch_guesses_single_char,
          else: @min_submatch_guesses_multi_char
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
      # unshifted count
      u = l - s

      if s === 0 or u === 0 do
        guesses * 2
      else
        1..min(s, u)
        |> Enum.map(&nCk(s + u, &1))
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

    match[:base_guesses] * match[:uppercase_variations] * match[:l33t_variations] *
      reversed_variations
  end

  @start_upper ~r'^[A-Z][^A-Z]+$'
  @end_upper ~r'^[^A-Z]+[A-Z]$'
  @all_upper ~r'^[^a-z]+$'
  @all_lower ~r'^[^A-Z]+$'

  def re_start_upper, do: @start_upper
  def re_all_upper, do: @all_upper

  defp uppercase_variations(%{token: word} = _match) do
    cond do
      Regex.match?(@all_lower, word) or String.downcase(word) === word ->
        1

      Enum.any?([@start_upper, @end_upper, @all_upper], &Regex.match?(&1, word)) ->
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

            _chr, {u, l} ->
              {u, l}
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
        |> Enum.map(&nCk(u + s, &1))
        |> Enum.sum()
        |> Kernel.*(variations)
      end
    end)
  end

  defp l33t_variations(_match), do: 1

  ### helper functions for `most_guessable_match_sequence`
  # helper: make bruteforce match objects spanning i to j, inclusive.
  defp make_bruteforce_match(i, j, password) do
    %{
      pattern: :bruteforce,
      token: String.slice(password, i, String.length(password) - j),
      i: i,
      j: j
    }
  end
end
