defmodule ZXCVBNTest do
  use ExUnit.Case
  use ExUnitProperties

  describe "zxcvbn/1" do
    property "handles given string" do
      check all str <- string(:ascii, max_length: 10, min_length: 1),
                times <- integer(1..20),
                times >= 0 do
        %{calc_time: calc_time, password: password, score: score} = ZXCVBN.zxcvbn(str)
        assert password === str
        assert calc_time > 0
        assert score >= 0
      end
    end
  end
end
