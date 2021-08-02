defmodule ZXCVBN.MessageFormatter do
  def format(str), do: apply(formatter(), :format, [str])

  defp formatter do
    Application.get_env(:zxcvbn, :message_formatter, ZXCVBN.DefaultMessageFormatter)
  end
end
