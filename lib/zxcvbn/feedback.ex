defmodule ZXCVBN.Feedback do
  @moduledoc """
  Feedback module to produce warning and suggestions
  """

  import ZXCVBN.Utils,
    only: [
      strlen: 1
    ]

  import ZXCVBN.Scoring,
    only: [
      re_start_upper: 0,
      re_all_upper: 0
    ]

  @default_feedback %{
    warning: "",
    suggestions: [
      "Use a few words, avoid common phrases",
      "No need for symbols, digits, or uppercase letters"
    ]
  }

  @empty_feedback %{
    warning: "",
    suggestions: []
  }

  def get_feedback(_score, []) do
    @default_feedback
  end

  def get_feedback(score, _sequence) when score > 2 do
    @empty_feedback
  end

  def get_feedback(_score, sequence) do
    longest_match = Enum.max_by(sequence, fn %{token: token} -> strlen(token) end)

    %{warning: warning, suggestions: suggestions} =
      get_match_feedback(longest_match, length(sequence) === 1)

    extra_feedback = "Add another word or two. Uncommon words are better."

    %{
      warning: warning,
      suggestions: [extra_feedback | suggestions]
    }
  end

  def get_match_feedback(%{pattern: pattern} = match, sole_match?) do
    case pattern do
      :dictionary ->
        get_dictionary_match_feedback(match, sole_match?)

      :spatial ->
        # layout = String.upcase(match[:graph])
        warning =
          if Map.get(match, :turns) === 1 do
            "Straight rows of keys are easy to guess"
          else
            "Short keyboard patterns are easy to guess"
          end

        %{
          warning: warning,
          suggestions: [
            "Use a longer keyboard pattern with more turns"
          ]
        }

      :repeat ->
        base_token = Map.get(match, :base_token)

        warning =
          if strlen(base_token) === 1 do
            ~s(Repeats like "aaa" are easy to guess)
          else
            ~s(Repeats like "abcabcabc" are only slightly harder to guess than "abc")
          end

        %{
          warning: warning,
          suggestions: [
            "Avoid repeated words and characters"
          ]
        }

      :sequence ->
        %{
          warning: "Sequences like abc or 6543 are easy to guess",
          suggestions: [
            "Avoid sequences"
          ]
        }

      :regex ->
        if match.regex_name === "recent_year" do
          %{
            warning: "Recent years are easy to guess",
            suggestions: [
              "Avoid recent years",
              "Avoid years that are associated with you"
            ]
          }
        else
          @empty_feedback
        end

      :date ->
        %{
          warning: "Dates are often easy to guess",
          suggestions: [
            "Avoid dates and years that are associated with you"
          ]
        }

      :bruteforce ->
        @empty_feedback
    end
  end

  def get_dictionary_match_feedback(match, sole_match?) do
    dictionary_name = Map.get(match, :dictionary_name)

    warning =
      cond do
        dictionary_name === :passwords ->
          get_password_dictionary_match_feedback(match, sole_match?)

        dictionary_name === :english_wikipedia and sole_match? ->
          "A word by itself is easy to guess"

        dictionary_name in ~w(surnames male_names female_names)a ->
          if sole_match? do
            "Names and surnames by themselves are easy to guess"
          else
            "Common names and surnames are easy to guess"
          end

        true ->
          ""
      end

    suggestions = gather_suggestions(match)

    %{
      warning: warning,
      suggestions: suggestions
    }
  end

  defp get_password_dictionary_match_feedback(match, sole_match?) do
    cond do
      sole_match? and not Map.get(match, :l33t, false) and not Map.get(match, :reversed, false) ->
        case Map.get(match, :rank) do
          rank when rank <= 10 ->
            "This is a top-10 common password"

          rank when rank <= 100 ->
            "This is a top-100 common password"

          _ ->
            "This is a very common password"
        end

      Map.get(match, :guesses_log10) <= 4 ->
        "This is similar to a commonly used password"

      true ->
        ""
    end
  end

  defp gather_suggestions(match) do
    [
      uppercase_suggestion(match),
      reversed_suggestion(match),
      l33t_suggestion(match)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp uppercase_suggestion(%{token: word}) do
    cond do
      Regex.match?(re_start_upper(), word) ->
        # initialization uppercase suggestion
        "Capitalization doesn't help very much"

      Regex.match?(re_all_upper(), word) and String.downcase(word) !== word ->
        # all uppercase suggestion
        "All-uppercase is almost as easy to guess as all-lowercase"

      true ->
        nil
    end
  end

  defp reversed_suggestion(%{token: word} = match) do
    if Map.get(match, :reversed, false) and strlen(word) >= 4 do
      "Reversed words aren't much harder to guess"
    end
  end

  defp l33t_suggestion(%{l33t: l33t}) when l33t === true do
    "Predictable substitutions like '@' instead of 'a' don't help very much"
  end

  defp l33t_suggestion(_), do: nil
end
