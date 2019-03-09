defmodule ZXCVBN.TimeEstimates do
  @moduledoc """
  Calculate various attacking times
  """

  def estimate_attack_times(guesses) do
    crack_times_seconds = %{
      online_throttling_100_per_hour: guesses / (100 / 3600),
      online_no_throttling_10_per_second: guesses / 10,
      offline_slow_hashing_1e4_per_second: guesses / 1.0e4,
      offline_fast_hashing_1e10_per_second: guesses / 1.0e10
    }

    crack_times_display =
      for {scenario, seconds} <- crack_times_seconds, into: %{} do
        {scenario, display_time(seconds)}
      end

    %{
      crack_times_seconds: crack_times_seconds,
      crack_times_display: crack_times_display,
      score: guesses_to_score(guesses)
    }
  end

  @delta 5
  @too_guessable_threshold 1.0e3 + @delta
  @very_guessable_threshold 1.0e6 + @delta
  @somewhat_guessable_threshold 1.0e8 + @delta
  @safely_unguessable_threshold 1.0e10 + @delta

  defp guesses_to_score(guesses) do
    cond do
      guesses < @too_guessable_threshold ->
        # risky password: "too guessable"
        0

      guesses < @very_guessable_threshold ->
        # modest protection from throttled online attacks: "very guessable"
        1

      guesses < @somewhat_guessable_threshold ->
        # modest protection from unthrottled online attacks: "somewhat guessable"
        2

      guesses < @safely_unguessable_threshold ->
        # modest protection from offline attacks: "safely unguessable"
        # assuming a salted, slow hash function like bcrypt, scrypt, PBKDF2, argon, etc
        3

      true ->
        4
    end
  end

  @minute 60
  @hour @minute * 60
  @day @hour * 24
  @month @day * 31
  @year @month * 12
  @century @year * 100

  defp display_time(seconds) do
    {display_num, display_str} =
      cond do
        seconds < 1 ->
          {nil, "less than a second"}

        seconds < @minute ->
          base = trunc(seconds)
          {base, "#{base} second"}

        seconds < @hour ->
          base = trunc(seconds / @minute)
          {base, "#{base} minute"}

        seconds < @day ->
          base = trunc(seconds / @hour)
          {base, "#{base} hour"}

        seconds < @month ->
          base = trunc(seconds / @day)
          {base, "#{base} day"}

        seconds < @year ->
          base = trunc(seconds / @month)
          {base, "#{base} month"}

        seconds < @century ->
          base = trunc(seconds / @year)
          {base, "#{base} year"}

        true ->
          {nil, "centuries"}
      end

    if is_integer(display_num) and display_num != 1 do
      "#{display_str}s"
    else
      display_str
    end
  end
end
