defmodule ZXCVBNTest do
  use ExUnit.Case
  use ExUnitProperties

  @node_script "#{File.cwd!()}/zxcvbn.js"

  defp exec_node(string) do
    {r, 0} = System.cmd(@node_script, [string])
    Jason.decode!(r)
  end

  describe "zxcvbn/1" do
    property "handles given string" do
      check all str <- string(:ascii, max_length: 10, min_length: 1),
                times <- integer(1..20),
                times >= 0 do
        %{calc_time: calc_time, password: password, score: score} = result = ZXCVBN.zxcvbn(str)
        assert password === str
        assert calc_time > 0
        assert score >= 0

        official_result = exec_node(str)

        assert Map.get(official_result, "guesses") === Map.get(result, :guesses)
        assert get_in(official_result, ["feedback", "suggestions"]) === get_in(result, [:feedback, :suggestions])
        assert get_in(official_result, ["feedback", "warning"]) === get_in(result, [:feedback, :warning])
        assert Map.get(official_result, "score") === Map.get(result, :score)
      end
    end
  end
end
