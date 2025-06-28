defmodule ZXCVBN.Matching do
  @moduledoc """
  Matching module
  """
  import ZXCVBN.AdjacencyGraphs, only: [adjacency_graph: 0]
  import ZXCVBN.FrequencyLists, only: [frequency_lists: 0]
  import ZXCVBN.Utils

  alias ZXCVBN.Scoring

  @frequency_lists frequency_lists()
  @adjacency_graphs adjacency_graph()

  def build_ranked_dict(ordered_list) do
    ordered_list
    |> Enum.with_index(1)
    |> Enum.into(%{})
  end

  def add_frequency_lists(ranked_dictionaries, frequency_lists \\ @frequency_lists) do
    Enum.reduce(frequency_lists, ranked_dictionaries, fn {name, lst}, ranked_dictionaries ->
      Map.put(ranked_dictionaries, name, build_ranked_dict(lst))
    end)
  end

  @l33t_table %{
    a: ["4", "@"],
    b: ["8"],
    c: ["(", "{", "[", "<"],
    e: ["3"],
    g: ["6", "9"],
    i: ["1", "!", "|"],
    l: ["1", "|", "7"],
    o: ["0"],
    s: ["$", "5"],
    t: ["+", "7"],
    x: ["%"],
    z: ["2"]
  }

  @date_max_year 2_050
  @date_min_year 1_000
  @date_splits %{
    # for length-4 strings, eg 1191 or 9111, two ways to split:
    "4" => [
      # 1 1 91 (2nd split starts at index 1, 3rd at index 2)
      {1, 2},
      # 91 1 1
      {2, 3}
    ],
    "5" => [
      # 1 11 91
      {1, 3},
      # 11 1 91
      {2, 3}
    ],
    "6" => [
      # 1 1 1991
      {1, 2},
      # 11 11 91
      {2, 4},
      # 1991 1 1
      {4, 5}
    ],
    "7" => [
      # 1 11 1991
      {1, 3},
      # 11 1 1991
      {2, 3},
      # 1991 1 11
      {4, 5},
      # 1991 11 1
      {4, 6}
    ],
    "8" => [
      # 11 11 1991
      {2, 4},
      # 1991 11 11
      {4, 6}
    ]
  }

  @matcher_types [
    :dictionary,
    :reverse_dictionary,
    :l33t,
    :spatial,
    :repeat,
    :sequence,
    :regex,
    :date
  ]

  @doc """
  omnimatch -- perform all matches
  """
  def omnimatch(password, ranked_dictionaries) do
    @matcher_types
    |> Enum.map(fn matcher_type ->
      apply(__MODULE__, :"#{matcher_type}_match", [password, ranked_dictionaries])
    end)
    |> List.flatten()
    |> _sort()
  end

  # dictionary match (common passwords, english, last names, etc)
  @doc false
  def dictionary_match(password, ranked_dictionaries) do
    length = strlen(password)
    password_lower = downcase(password)

    for {dictionary_name, ranked_dict} <- ranked_dictionaries,
        i <- 0..(length - 1),
        j <- i..(length - 1) do
      word = slice(password_lower, i, j + 1 - i)
      rank = Map.get(ranked_dict, word)

      unless is_nil(rank) do
        token = slice(password, i, j + 1 - i)

        %{
          pattern: :dictionary,
          i: i,
          j: j,
          token: token,
          matched_word: word,
          rank: rank,
          dictionary_name: dictionary_name,
          reversed: false,
          l33t: false
        }
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  @doc false
  def reverse_dictionary_match(password, ranked_dictionaries) do
    length = strlen(password)

    password
    |> String.reverse()
    |> dictionary_match(ranked_dictionaries)
    |> Enum.map(fn %{token: token} = match ->
      match
      |> Map.put(:token, String.reverse(token))
      |> Map.put(:reversed, true)
      |> Map.put(:i, length - 1 - match[:j])
      |> Map.put(:j, length - 1 - match[:i])
    end)
  end

  @doc false
  def l33t_match(password, ranked_dictionaries, l33t_table \\ @l33t_table) do
    for [_ | _] = sub <- enumerate_l33t_subs(relevant_l33t_subtable(password, l33t_table)) do
      subbed_password = translate(password, sub)

      for match <- dictionary_match(subbed_password, ranked_dictionaries) do
        token = slice(password, match[:i], match[:j] + 1 - match[:i])
        # only return the matches that contain an actual substitution
        if downcase(token) !== Map.get(match, :matched_word) do
          # subset of mappings in sub that are in use for this match
          token_graphemes = String.codepoints(token)

          match_sub =
            for {subbed_chr, chr} <- sub, subbed_chr in token_graphemes do
              {subbed_chr, chr}
            end

          sub_display =
            Enum.map_join(match_sub, ", ", fn {k, v} ->
              "#{k} -> #{v}"
            end)

          match
          |> Map.put(:l33t, true)
          |> Map.put(:token, token)
          |> Map.put(:sub, match_sub)
          |> Map.put(:sub_display, sub_display)
        end
      end
    end
    |> List.flatten()
    |> Enum.reject(fn
      nil ->
        true

      %{token: token} ->
        strlen(token) <= 1

      _ ->
        false
    end)
  end

  defp relevant_l33t_subtable(password, table) do
    password_chars = String.codepoints(password)

    for {letter, subs} <- table do
      relevant_subs =
        Enum.filter(subs, fn sub ->
          sub in password_chars
        end)

      case relevant_subs do
        [_ | _] ->
          {letter, relevant_subs}

        _ ->
          nil
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp enumerate_l33t_subs(table) do
    keys = Map.keys(table)
    l33t_helper(table, keys, [[]])
  end

  defp translate(string, chr_map) do
    for char <- String.codepoints(string) do
      if chr = Map.get(Enum.into(chr_map, %{}), char, false) do
        chr
      else
        char
      end
    end
    |> Enum.join("")
  end

  defp l33t_helper(table, [first_key | rest_keys], subs) do
    next_subs =
      table
      |> Map.get(first_key)
      |> Enum.reduce([], fn l33t_chr, next_subs ->
        Enum.reduce(subs, next_subs, fn sub, next_subs ->
          dup_l33t_index =
            sub
            |> Enum.with_index()
            |> Enum.reduce_while(-1, fn {{sub_l33t_chr, _value}, i}, dup_l33t_index ->
              if sub_l33t_chr === l33t_chr do
                {:halt, i}
              else
                {:cont, dup_l33t_index}
              end
            end)

          if dup_l33t_index === -1 do
            [[{l33t_chr, first_key} | sub] | next_subs]
          else
            sub_alternative = [{l33t_chr, first_key} | List.delete_at(sub, dup_l33t_index)]
            [sub, sub_alternative | next_subs]
          end
        end)
      end)

    subs = dedup(next_subs)
    l33t_helper(table, rest_keys, subs)
  end

  defp l33t_helper(_table, _keys, subs) do
    subs
  end

  def dedup(subs) do
    {deduped, _} =
      Enum.reduce(subs, {[], []}, fn sub, {deduped, members} ->
        assoc =
          sub
          |> Enum.into(%{}, fn {v, k} -> {k, v} end)
          |> Enum.sort()

        label =
          Enum.map_join(assoc, "-", fn {k, v} ->
            "#{k},#{v}"
          end)

        if label in members do
          {deduped, members}
        else
          {[sub | deduped], [label | members]}
        end
      end)

    deduped
  end

  # repeats (aaa, abcabcabc) and sequences (abcdef)
  @doc false
  def repeat_match(password, ranked_dictionaries) do
    greedy = ~r'(.+)\1+'
    lazy = ~r'(.+?)\1+'
    lazy_anchored = ~r'^(.+?)\1+$'

    length = strlen(password)

    Enum.reduce_while(0..(length - 1), [], fn i, matches ->
      part = slice(password, i, length - i)
      greedy_match = Regex.run(greedy, part)
      lazy_match = Regex.run(lazy, part)

      case greedy_match do
        [greedy_first, _] ->
          greedy_len = strlen(greedy_first)
          [lazy_first, _] = lazy_match
          lazy_len = strlen(lazy_first)

          {{i, j}, token, base_token} =
            if greedy_len > lazy_len do
              # greedy beats lazy for 'aabaab'
              #   greedy: [aabaab, aab]
              #   lazy:   [aa,     a]
              {
                regex_i_j(greedy, part, i),
                greedy_first,
                # greedy's repeated string might itself be repeated, eg.
                # aabaab in aabaabaabaab.
                # run an anchored lazy match on greedy's repeated string
                # to find the shortest repeated string
                Regex.run(lazy_anchored, greedy_first) |> List.last()
              }
            else
              {
                regex_i_j(lazy, part, i),
                lazy_first,
                List.last(lazy_match)
              }
            end

          # recursively match and score the base string
          base_analysis =
            Scoring.most_guessable_match_sequence(
              base_token,
              omnimatch(base_token, ranked_dictionaries)
            )

          match = %{
            pattern: :repeat,
            i: i,
            j: j,
            token: token,
            base_token: base_token,
            base_guesses: Map.get(base_analysis, :guesses),
            base_matches: Map.get(base_analysis, :sequence),
            repeat_count: trunc(strlen(token) / strlen(base_token))
          }

          {:cont, [match | matches]}

        _ ->
          {:halt, matches}
      end
    end)
  end

  @doc false
  def spatial_match(password, graphs \\ @adjacency_graphs, _ranked_dictionaries) do
    for {graph_name, graph} <- graphs do
      spatial_match_helper(password, graph, graph_name)
    end
  end

  @shifted_rx ~r'[~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?]'

  def spatial_match_helper(password, graph, graph_name) do
    length = strlen(password)

    password
    |> do_spatial_match(graph, graph_name, 0, length, [])
    |> List.flatten()
  end

  defp do_spatial_match(password, graph, graph_name, i, length, matches) when i < length - 1 do
    j = i + 1

    shifted_count =
      if graph_name in ~w(qwerty dvorak) and Regex.match?(@shifted_rx, String.at(password, i)) do
        # initial character is shifted
        1
      else
        0
      end

    {matches, i} = spatial_loop(password, i, j, graph, graph_name, shifted_count, matches)
    do_spatial_match(password, graph, graph_name, i, length, matches)
  end

  defp do_spatial_match(_, _, _, _, _, matches), do: matches

  defp spatial_loop(
         password,
         i,
         j,
         graph,
         graph_name,
         shifted_count,
         matches,
         turns \\ 0,
         last_direction \\ nil
       ) do
    prev_char = String.at(password, j - 1)
    found = false
    cur_direction = -1

    adjacents =
      graph
      |> is_map()
      |> if do
        Map.get(graph, prev_char, [])
      else
        []
      end

    length = strlen(password)

    # consider growing pattern by one character if j hasn't gone
    # over the edge.
    {_cur_direction, found, last_direction, turns, shifted_count} =
      if j < length do
        cur_char = String.at(password, j)

        Enum.reduce_while(
          adjacents,
          {cur_direction, found, last_direction, turns, shifted_count},
          fn adj, {cur_direction, found, last_direction, turns, shifted_count} ->
            cur_direction = cur_direction + 1

            if is_binary(adj) and cur_char in String.codepoints(adj) do
              found = true
              found_direction = cur_direction
              cur_char_index = adj |> :binary.match(cur_char) |> elem(0)
              # index 1 in the adjacency means the key is shifted,
              # 0 means unshifted: A vs a, % vs 5, etc.
              # for example, 'q' is adjacent to the entry '2@'.
              # @ is shifted w/ index 1, 2 is unshifted.
              shifted_count = if cur_char_index === 1, do: shifted_count + 1, else: shifted_count

              {turns, last_direction} =
                if last_direction === found_direction do
                  {turns, last_direction}
                else
                  # adding a turn is correct even in the initial case when last_direction is null:
                  # every spatial pattern starts with a turn.
                  {turns + 1, found_direction}
                end

              {:halt, {cur_direction, found, last_direction, turns, shifted_count}}
            else
              {:cont, {cur_direction, found, last_direction, turns, shifted_count}}
            end
          end
        )
      else
        {cur_direction, found, last_direction, turns, shifted_count}
      end

    if found do
      # if the current pattern continued, extend j and try to grow again
      spatial_loop(
        password,
        i,
        j + 1,
        graph,
        graph_name,
        shifted_count,
        matches,
        turns,
        last_direction
      )
    else
      # don't consider length 1 or 2 chains.
      if j - i > 2 do
        # ...and then start a new search for the rest of the password.
        {
          [
            %{
              pattern: :spatial,
              i: i,
              j: j - 1,
              token: slice(password, i..(j - 1)),
              graph: graph_name,
              turns: turns,
              shifted_count: shifted_count
            }
            | matches
          ],
          j
        }
      else
        {matches, j}
      end
    end
  end

  @max_delta 5

  def sequence_match(password, ranked_dictionaries) do
    if strlen(password) <= 1 do
      []
    else
      do_sequence_match(password, ranked_dictionaries)
    end
  end

  def do_sequence_match(password, _ranked_dictionaries) do
    # Identifies sequences by looking for repeated differences in unicode codepoint.
    # this allows skipping, such as 9753, and also matches some extended unicode sequences
    # such as Greek and Cyrillic alphabets.
    #
    # for example, consider the input 'abcdb975zy'
    #
    # password: a   b   c   d   b    9   7   5   z   y
    # index:    0   1   2   3   4    5   6   7   8   9
    # delta:      1   1   1  -2  -41  -2  -2  69   1
    #
    # expected result:
    # [(i, j, delta), ...] = [(0, 3, 1), (5, 7, -2), (8, 9, 1)]
    update = fn
      i, j, delta, password, matches
      when (j - i > 1 or (is_number(delta) and abs(delta) === 1)) and abs(delta) in 1..@max_delta ->
        token = slice(password, i, j + 1 - i)

        {sequence_name, sequence_space} =
          cond do
            Regex.match?(~r'^[a-z]+$', token) ->
              {"lower", 26}

            Regex.match?(~r'^[A-Z]+$', token) ->
              {"upper", 26}

            Regex.match?(~r'^\d+$', token) ->
              {"digits", 10}

            true ->
              {"unicode", 26}
          end

        [
          %{
            pattern: :sequence,
            i: i,
            j: j,
            token: token,
            sequence_name: sequence_name,
            sequence_space: sequence_space,
            ascending: delta > 0
          }
          | matches
        ]

      _i, _j, _delta, _password, matches ->
        matches
    end

    length = strlen(password)

    {matches, last_delta, i} =
      Enum.reduce(1..(length - 1), {[], nil, 0}, fn k, {matches, last_delta, i} ->
        delta =
          password
          |> slice(k - 1, 2)
          |> to_charlist()
          |> (fn [x, y] -> y - x end).()

        last_delta = if is_nil(last_delta), do: delta, else: last_delta

        if delta === last_delta do
          {matches, last_delta, i}
        else
          j = k - 1
          matches = update.(i, j, last_delta, password, matches)
          {matches, delta, j}
        end
      end)

    update.(i, length - 1, last_delta, password, matches)
  end

  def regex_match(password, regexen \\ %{recent_year: ~r'19\d\d|200\d|201\d'}, _ranked_dictionaries) do
    for {name, regex} <- regexen do
      for {start, byte_len} <- Regex.scan(regex, password, return: :index) |> List.flatten() do
        token = slice(password, start, byte_len)
        len = strlen(token)

        %{
          pattern: :regex,
          token: token,
          i: start,
          j: start + len - 1,
          regex_name: name
          # regex_match: # TODO: check back on this
        }
      end
    end
  end

  @maybe_date_no_separator ~r'^\d{4,8}$'
  @maybe_date_with_separator ~r'^(\d{1,4})([\s/\\_.-])(\d{1,2})\2(\d{1,4})$'

  @doc """
  a "date" is recognized as:
    any 3-tuple that starts or ends with a 2- or 4-digit year,
    with 2 or 0 separator chars (1.1.91 or 1191),
    maybe zero-padded (01-01-91 vs 1-1-91),
    a month between 1 and 12,
    a day between 1 and 31.

  note: this isn't true date parsing in that "feb 31st" is allowed,
  this doesn't check for leap years, etc.

  recipe:
  start with regex to find maybe-dates, then attempt to map the integers
  onto month-day-year to filter the maybe-dates into dates.
  finally, remove matches that are substrings of other matches to reduce noise.

  note: instead of using a lazy or greedy regex to find many dates over the full string,
  this uses a ^...$ regex against every substring of the password -- less performant but leads
  to every possible date match.
  """
  def date_match(password, _ranked_dictionaries) do
    date_no_separator_matches = date_no_separator_matches(password)
    date_with_separator_matches = date_with_separator_matches(password)

    matches =
      [date_no_separator_matches, date_with_separator_matches]
      |> List.flatten()

    Enum.reject(matches, &substring_date?(&1, matches))
  end

  # dates without separators are between length 4 '1191' and 8 '11111991'
  defp date_no_separator_matches(password) do
    length = strlen(password)

    for i <- Range.new(0, length - 4, 1), j <- Range.new(i + 3, i + 8, 1), i >= 0, j < length do
      token = slice(password, i..j)
      token_length = strlen(token)

      if Regex.match?(@maybe_date_no_separator, token) do
        candidates =
          for {k, l} <- Map.get(@date_splits, to_string(token_length)) do
            map_ints_to_dmy({
              slice_to_integer(token, 0, k),
              slice_to_integer(token, k, l),
              slice_to_integer(token, l)
            })
          end
          |> Enum.reject(&is_nil/1)

        if length(candidates) > 0 do
          # at this point: different possible dmy mappings for the same i,j
          # substring. match the candidate date that likely takes the fewest
          # guesses: a year closest to 2000. (scoring.REFERENCE_YEAR).
          #
          # ie, considering '111504', prefer 11-15-04 to 1-1-1504
          # (interpreting '04' as 2004)
          best_candidate =
            Enum.min_by(
              candidates,
              fn candidate ->
                abs(candidate[:year] - Scoring.reference_year())
              end,
              fn -> hd(candidates) end
            )

          %{
            pattern: :date,
            token: token,
            i: i,
            j: j,
            separator: ""
          }
          |> Map.merge(best_candidate)
        end
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  # dates with separators are between length 6 '1/1/91' and 10 '11/11/1991'
  defp date_with_separator_matches(password) do
    length = strlen(password)

    for i <- Range.new(0, length - 5, 1), j <- Range.new(i + 5, i + 10, 1), i >= 0, j < length do
      token = slice(password, i..j)

      rx_match = Regex.run(@maybe_date_with_separator, token)

      unless is_nil(rx_match) do
        [_, g1, separator, g2, g3] = rx_match

        dmy =
          map_ints_to_dmy({
            String.to_integer(g1),
            String.to_integer(g2),
            String.to_integer(g3)
          })

        unless is_nil(dmy) do
          %{
            pattern: :date,
            token: token,
            i: i,
            j: j,
            separator: separator
          }
          |> Map.merge(dmy)
        end
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  # internal sorting
  defp _sort(list) do
    list
    |> Stream.reject(&is_nil/1)
    |> Enum.sort(fn x1, x2 ->
      {x1[:i], x1[:j]} >= {x2[:i], x2[:j]}
    end)
  end

  defp regex_i_j(regex, string, offset) do
    {start, byte_len} = regex |> Regex.run(string, return: :index) |> hd()
    token = slice(string, start, byte_len)
    {offset + start, offset + strlen(token) - 1}
  end

  # date stuff

  @doc """
  given a 3-tuple, discard if:
    - middle int is over 31 (for all dmy formats, years are never allowed in
    the middle)
    - middle int is zero
    - any int is over the max allowable year
    - any int is over two digits but under the min allowable year
    - 2 ints are over 31, the max allowable day
    - 2 ints are zero
    - all ints are over 12, the max allowable month
  """
  def map_ints_to_dmy({_first, second, _third}) when second > 31 or second <= 0, do: nil

  def map_ints_to_dmy({first, second, third}) do
    {invalid?, over_12, over_31, under_1} =
      Enum.reduce_while([first, second, third], {false, 0, 0, 0}, fn
        int, {_invalid?, over_12, over_31, under_1}
        when int > 99 and int < @date_min_year
        when int > @date_max_year ->
          {:halt, {true, over_12, over_31, under_1}}

        int, {invalid?, over_12, over_31, under_1} when int > 31 ->
          {:cont, {invalid?, over_12, over_31 + 1, under_1}}

        int, {invalid?, over_12, over_31, under_1} when int > 12 ->
          {:cont, {invalid?, over_12 + 1, over_31, under_1}}

        int, {invalid?, over_12, over_31, under_1} when int <= 0 ->
          {:cont, {invalid?, over_12, over_31, under_1 + 1}}

        _, acc ->
          {:cont, acc}
      end)

    invalid? = invalid? or over_31 >= 2 or over_12 === 3 or under_1 >= 2

    unless invalid? do
      # first look for a four digit year: yyyy + daymonth or daymonth + yyyy
      possible_four_digit_splits = [
        {third, {first, second}},
        {first, {second, third}}
      ]

      case maybe_extract_four_digit_year_date(possible_four_digit_splits) do
        map when is_map(map) ->
          map

        :invalid ->
          nil

        nil ->
          maybe_extract_non_four_digit_year_date(possible_four_digit_splits)
      end
    end
  end

  # for a candidate that includes a four-digit year,
  # when the remaining ints don't match to a day and month,
  # it is not a date.
  defp maybe_extract_four_digit_year_date(possible_four_digit_splits) do
    Enum.reduce_while(possible_four_digit_splits, nil, fn
      {y, dm}, _dmy when y >= @date_min_year and y <= @date_max_year ->
        dm = map_ints_to_dm(dm)

        if is_map(dm) do
          {:halt, Map.put(dm, :year, y)}
        else
          {:halt, nil}
        end

      _, dmy ->
        {:cont, dmy}
    end)
  end

  # given no four-digit year, two digit years are the most flexible int to
  # match, so try to parse a day-month out of ints[0..1] or ints[1..0]
  defp maybe_extract_non_four_digit_year_date(possible_four_digit_splits) do
    possible_four_digit_splits
    |> Enum.map(fn {y, dm} -> {two_to_four_digit_year(y), dm} end)
    |> maybe_extract_four_digit_year_date()
  end

  defp map_ints_to_dm(ints) do
    reversed = ints |> Tuple.to_list() |> Enum.reverse() |> List.to_tuple()

    [ints, reversed]
    |> Enum.find_value(fn
      {d, m} when d >= 1 and d <= 31 and m >= 1 and m <= 12 ->
        %{day: d, month: m}

      _ ->
        nil
    end)
  end

  defp two_to_four_digit_year(year) do
    cond do
      year > 99 ->
        year

      year > 50 ->
        # 87 -> 1987
        year + 1900

      true ->
        # 15 -> 2015
        year + 2000
    end
  end

  defp slice_to_integer(string, start) do
    length = strlen(string)
    slice_to_integer(string, start, length)
  end

  defp slice_to_integer(string, start, end_index) do
    string
    |> slice(start..(end_index - 1))
    |> String.to_integer()
  end

  defp substring_date?(%{i: i, j: j} = match, matches) do
    Enum.reduce_while(matches, false, fn
      other, substring? when match === other ->
        {:cont, substring?}

      %{i: other_i, j: other_j}, _substring?
      when other_i <= i and other_j >= j ->
        {:halt, true}

      _, substring? ->
        {:cont, substring?}
    end)
  end
end
