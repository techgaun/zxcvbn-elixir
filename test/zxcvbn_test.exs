defmodule ZXCVBNTest do
  use ExUnit.Case
  use ExUnitProperties

  @node_script "#{File.cwd!()}/zxcvbn.js"

  defp exec_node(string) do
    {r, 0} = System.cmd(@node_script, [string])
    Jason.decode!(r)
  end

  describe "zxcvbn/1" do
    # TODO: add this test after fixing certain unicode characters handling
    # property "handles given string" do
    #   check all str <- string(:printable, max_length: 10, min_length: 2),
    #             times <- integer(1..20),
    #             times >= 0 do
    #     Application.put_env(:zxcvbn, :mode, :default)
    #     %{calc_time: calc_time, password: password, score: score} = result = ZXCVBN.zxcvbn(str)
    #     assert password === str
    #     assert calc_time > 0
    #     assert score >= 0
    #
    #     official_result = exec_node(str)
    #
    #     assert Map.get(official_result, "guesses") == Map.get(result, :guesses)
    #
    #     assert get_in(official_result, ["feedback", "suggestions"]) ===
    #              get_in(result, [:feedback, :suggestions])
    #
    #     assert get_in(official_result, ["feedback", "warning"]) ===
    #              get_in(result, [:feedback, :warning])
    #
    #     assert Map.get(official_result, "score") === Map.get(result, :score)
    #   end
    # end

    property "handles given ascii string in ascii mode" do
      check all(
              str <- string(:ascii, max_length: 10, min_length: 1),
              times <- integer(1..20),
              times >= 0
            ) do
        Application.put_env(:zxcvbn, :mode, :ascii)
        %{calc_time: calc_time, password: password, score: score} = result = ZXCVBN.zxcvbn(str)
        assert password === str
        assert calc_time > 0
        assert score >= 0

        official_result = exec_node(str)

        assert Map.get(official_result, "guesses") == Map.get(result, :guesses)

        assert get_in(official_result, ["feedback", "suggestions"]) ===
                 get_in(result, [:feedback, :suggestions])

        assert get_in(official_result, ["feedback", "warning"]) ===
                 get_in(result, [:feedback, :warning])

        assert Map.get(official_result, "score") === Map.get(result, :score)
      end
    end

    property "handles given ascii string in unicode mode" do
      check all(
              str <- string(:ascii, max_length: 10, min_length: 1),
              times <- integer(1..20),
              times >= 0
            ) do
        Application.put_env(:zxcvbn, :mode, :ascii)
        %{calc_time: calc_time, password: password, score: score} = result = ZXCVBN.zxcvbn(str)
        assert password === str
        assert calc_time > 0
        assert score >= 0

        official_result = exec_node(str)

        assert Map.get(official_result, "guesses") == Map.get(result, :guesses)

        assert get_in(official_result, ["feedback", "suggestions"]) ===
                 get_in(result, [:feedback, :suggestions])

        assert get_in(official_result, ["feedback", "warning"]) ===
                 get_in(result, [:feedback, :warning])

        assert Map.get(official_result, "score") === Map.get(result, :score)
      end
    end
  end

  test "README.md version is up to date" do
    app = :zxcvbn
    app_version = Application.spec(:zxcvbn, :vsn) |> to_string()
    readme = File.read!("README.md")
    [_, readme_version] = Regex.run(~r/{:#{app}, "(.+)"}/, readme)
    assert Version.match?(app_version, readme_version)
  end

  test "should translate feedback messages with gettext" do
    [
      %{locale: "en", expected: "Dates are often easy to guess"},
      %{locale: "fr", expected: "Les dates sont souvent faciles à deviner"}
    ]
    |> Enum.each(fn %{locale: locale, expected: expected} ->
      Gettext.with_locale(ZXCVBN.Gettext, locale, fn ->
        %{feedback: %{warning: ^expected}} = ZXCVBN.zxcvbn("20110101")
      end)
    end)
  end
end
