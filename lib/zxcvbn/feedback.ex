defmodule ZXCVBN.Feedback do
  @moduledoc """
  Feedback module to produce warning and suggestions
  """
  import ZXCVBN.Gettext

  import ZXCVBN.Utils,
    only: [
      strlen: 1
    ]

  import ZXCVBN.Scoring,
    only: [
      re_start_upper: 0,
      re_all_upper: 0
    ]

  @empty_feedback %{
    warning: "",
    suggestions: []
  }

  defp default_feedback() do
    %{
      warning: "",
      suggestions: [
        dgettext("feedback", "Use a few words, avoid common phrases"),
        dgettext("feedback", "No need for symbols, digits, or uppercase letters")
      ]
    }
  end

  def get_feedback(_score, []) do
    default_feedback()
  end

  def get_feedback(score, _sequence) when score > 2 do
    @empty_feedback
  end

  def get_feedback(_score, sequence) do
    longest_match = Enum.max_by(sequence, fn %{token: token} -> strlen(token) end)

    %{warning: warning, suggestions: suggestions} =
      get_match_feedback(longest_match, length(sequence) === 1)

    extra_feedback = dgettext("feedback", "Add another word or two. Uncommon words are better.")

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
            dgettext("feedback", "Straight rows of keys are easy to guess")
          else
            dgettext("feedback", "Short keyboard patterns are easy to guess")
          end

        %{
          warning: warning,
          suggestions: [
            dgettext("feedback", "Use a longer keyboard pattern with more turns")
          ]
        }

      :repeat ->
        base_token = Map.get(match, :base_token)

        warning =
          if strlen(base_token) === 1 do
            dgettext("feedback", "Repeats like \"aaa\" are easy to guess")
          else
            dgettext(
              "feedback",
              "Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\""
            )
          end

        %{
          warning: warning,
          suggestions: [
            dgettext("feedback", "Avoid repeated words and characters")
          ]
        }

      :sequence ->
        %{
          warning: dgettext("feedback", "Sequences like abc or 6543 are easy to guess"),
          suggestions: [
            dgettext("feedback", "Avoid sequences")
          ]
        }

      :regex ->
        if match.regex_name === "recent_year" do
          %{
            warning: dgettext("feedback", "Recent years are easy to guess"),
            suggestions: [
              dgettext("feedback", "Avoid recent years"),
              dgettext("feedback", "Avoid years that are associated with you")
            ]
          }
        else
          @empty_feedback
        end

      :date ->
        %{
          warning: dgettext("feedback", "Dates are often easy to guess"),
          suggestions: [
            dgettext("feedback", "Avoid dates and years that are associated with you")
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
          dgettext("feedback", "A word by itself is easy to guess")

        dictionary_name in ~w(surnames male_names female_names)a ->
          if sole_match? do
            dgettext("feedback", "Names and surnames by themselves are easy to guess")
          else
            dgettext("feedback", "Common names and surnames are easy to guess")
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
            dgettext("feedback", "This is a top-10 common password")

          rank when rank <= 100 ->
            dgettext("feedback", "This is a top-100 common password")

          _ ->
            dgettext("feedback", "This is a very common password")
        end

      Map.get(match, :guesses_log10) <= 4 ->
        dgettext("feedback", "This is similar to a commonly used password")

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
        dgettext("feedback", "Capitalization doesn't help very much")

      Regex.match?(re_all_upper(), word) and String.downcase(word) !== word ->
        # all uppercase suggestion
        dgettext("feedback", "All-uppercase is almost as easy to guess as all-lowercase")

      true ->
        nil
    end
  end

  defp reversed_suggestion(%{token: word} = match) do
    if Map.get(match, :reversed, false) and strlen(word) >= 4 do
      dgettext("feedback", "Reversed words aren't much harder to guess")
    end
  end

  defp l33t_suggestion(%{l33t: l33t}) when l33t === true do
    dgettext("feedback", "Predictable substitutions like '@' instead of 'a' don't help very much")
  end

  defp l33t_suggestion(_), do: nil
end
