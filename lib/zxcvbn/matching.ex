defmodule ZXCVBN.Matching do
  @moduledoc """
  Matching module
  """
  import ZXCVBN.AdjacencyGraphs, only: [adjacency_graph: 0]
  import ZXCVBN.FrequencyLists, only: [frequency_lists: 0]

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

  # internal sorting
  defp _sort(list) do
    list
    |> Enum.sort(fn x1, x2 ->
      {x1[:i], x2[:j]} >= {x2[:i], x2[:j]}
    end)
  end
end
