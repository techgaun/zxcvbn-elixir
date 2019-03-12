defmodule ZXCVBN.Matching do
  @moduledoc """
  Matching module
  """
  import ZXCVBN.AdjacencyGraphs, only: [adjacency_graph: 0]
  import ZXCVBN.FrequencyLists, only: [frequency_lists: 0]

  alias ZXCVBN.Scoring

  @frequency_lists frequency_lists()
  @adjacency_graphs adjacency_graph()

  defp build_ranked_dict(ordered_list) do
    ordered_list
    |> Enum.with_index(1)
    |> Enum.into(%{})
  end

  def add_frequency_lists(ranked_dictionaries, frequency_lists) do
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
    z: ["2"],
  }

  @regexen ~r'19\d\d|200\d|201\d'
  @date_max_year 2_050
  @date_min_year 1_000
  @date_splits %{
    "4": [  # for length-4 strings, eg 1191 or 9111, two ways to split:
      [1, 2],  # 1 1 91 (2nd split starts at index 1, 3rd at index 2)
      [2, 3],  # 91 1 1
    ],
    "5": [
      [1, 3],  # 1 11 91
      [2, 3],  # 11 1 91
    ],
    "6": [
      [1, 2],  # 1 1 1991
      [2, 4],  # 11 11 91
      [4, 5],  # 1991 1 1
    ],
    "7": [
      [1, 3],  # 1 11 1991
      [2, 3],  # 11 1 1991
      [4, 5],  # 1991 1 11
      [4, 6],  # 1991 11 1
    ],
    "8": [
      [2, 4],  # 11 11 1991
      [4, 6],  # 1991 11 11
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
    |> Enum.reduce([], fn matcher_type, matches ->
      [apply(__MODULE__, :"#{matcher_type}_match", [password, ranked_dictionaries]) | matches]
    end)
    |> List.flatten()
    |> _sort()
  end

  # dictionary match (common passwords, english, last names, etc)
  @doc false
  def dictionary_match(password, ranked_dictionaries) do
    length = String.length(password)
    password_lower = String.downcase(password)

    for {dictionary_name, ranked_dict} <- ranked_dictionaries,
    i <- 0..(length - 1), j <- i..(length - 1) do
      if (word = String.slice(password_lower, i, j + 1 - i)) in ranked_dict do
        token = String.slice(password_lower, i, j + 1 - i)
        rank = ranked_dict[word]
        %{
          pattern: 'dictionary',
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
    |> _sort()
  end

  @doc false
  def reverse_dictionary_match(password, ranked_dictionaries) do
    length = String.length(password)

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
    |> _sort()
  end

  @doc false
  def l33t_match(password, ranked_dictionaries, l33t_table \\ @l33t_table) do
    for sub <- enumerate_l33t_subs(relevant_l33t_subtable(password, l33t_table)) do
      subbed_password = translate(password, sub)

      for match <- dictionary_match(subbed_password, ranked_dictionaries) do
        token = String.slice(password, match[:i], match[:j] + 1 - match[:i])
        # only return the matches that contain an actual substitution
        if String.downcase(token) !== Map.get(match, :matched_word) do
          # subset of mappings in sub that are in use for this match
          token_graphemes = String.graphemes(token)
          match_sub =
            for {subbed_chr, chr} <- sub, subbed_chr in token_graphemes do
              {subbed_chr, chr}
            end

          sub_display = Enum.map_join(match_sub, ", ", fn {k, v} ->
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
    |> Enum.reject(fn
      nil -> true
      %{token: token} ->
        String.length(token) <= 1
      _ -> false
    end)
    |> _sort()
  end

  @greedy ~r'(.+)\1+'
  @lazy ~r'(.+?)\1+'
  @lazy_anchored ~r'^(.+?)\1+$'
  # repeats (aaa, abcabcabc) and sequences (abcdef)
  defp repeat_match(password, ranked_dictionaries) do
    length = String.length(password)
    Enum.reduce_while(0..length, [], fn i, matches ->
      [_, part] = String.split(password, i)
      greedy_match = Regex.run(@greedy, part)
      lazy_match = Regex.run(@lazy, part)

      case greedy_match do
        [greedy_first, _] ->
          greedy_len = String.length(greedy_first)
          [lazy_first, _] = lazy_match
          lazy_len = String.length(lazy_first)

          {{i, j}, token, base_token} =
            if greedy_len > lazy_len do
              # greedy beats lazy for 'aabaab'
              #   greedy: [aabaab, aab]
              #   lazy:   [aa,     a]
              {
                @greedy |> Regex.run(part, return: :index) |> hd(),
                greedy_first,
                # greedy's repeated string might itself be repeated, eg.
                # aabaab in aabaabaabaab.
                # run an anchored lazy match on greedy's repeated string
                # to find the shortest repeated string
                Regex.run(@lazy_anchored, greedy_first) |> List.last()
              }
            else
              {
                @lazy |> Regex.run(part, return: :index) |> hd(),
                lazy_first,
                List.last(lazy_match)
              }
            end

          # recursively match and score the base string
          base_analysis = most_guessable_match_sequence(
            base_token,
            omnimatch(password, ranked_dictionaries)
          )

          match =
            %{
              pattern: "repeat",
              i: i,
              j: j,
              token: token,
              base_token: base_token,
              base_guesses: Map.get(base_analysis, :base_guesses),
              base_matches: Map.get(base_analysis, :base_matches),
              repeat_count: String.length(token) / String.length(base_token)
            }

          {:cont, match}

        _ ->
          {:halt, matches}
      end
    end)
  end

  defp relevant_l33t_subtable(password, table) do
    password_chars = String.graphemes(password)

    for {letter, subs} <- table do
      relevant_subs = Enum.filter(subs, fn sub ->
        sub in password_chars
      end)

      case relevant_subs do
        [_ | _] ->
          {letter, relevant_subs}

        _ -> nil
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp enumerate_l33t_subs(table) do
    keys = Map.keys(table)

    subs = l33t_helper(table, keys, [[]])

    for sub <- subs, {l33t_chr, chr} <- sub, into: %{} do
      {l33t_chr, chr}
    end
  end

  defp translate(string, chr_map) do
    for char <- String.graphemes(string) do
      if chr = Map.get(chr_map, char, false) do
        chr
      else
        char
      end
    end
    |> Enum.join("")
  end

  defp l33t_helper(table, [first_key | rest_keys], subs) do
    next_subs =
      for l33t_chr <- Map.get(table, first_key), sub <- subs do
        dup_l33t_index = Enum.reduce(0..(length(sub) - 1), -1, fn i, dup_l33t_index ->
          if get_in(sub, [i, 0]) === l33t_chr do
            i
          else
            dup_l33t_index
          end
        end)

        if dup_l33t_index === -1 do
          "#{sub}#{l33t_chr}#{first_key}" |> String.graphemes()
        else
          sub_alternative = "#{sub}#{l33t_chr}#{first_key}" |> String.graphemes() |> Kernel.--([dup_l33t_index])

          [sub, sub_alternative]
        end
      end
      |> List.flatten()

    subs = dedup(next_subs)
    l33t_helper(table, rest_keys, subs)
  end

  defp l33t_helper(_table, _keys, subs) do
    subs
  end

  def dedup(subs) do
    Enum.reduce(subs, {[], []}, fn sub, {deduped, members} ->
      assoc =
        sub
        |> Enum.into(%{}, fn {v, k} -> {k, v} end)
        |> Enum.sort()

      label = Enum.map_join(assoc, "-", fn {k, v} ->
        "#{k},#{v}"
      end)

      if label in members do
        {deduped, members}
      else
        {[sub | deduped], [label | members]}
      end
    end)
  end

  # internal sorting
  defp _sort(list) do
    list
    |> Enum.sort(fn x1, x2 ->
      {x1[:i], x2[:j]} >= {x2[:i], x2[:j]}
    end)
  end
end
