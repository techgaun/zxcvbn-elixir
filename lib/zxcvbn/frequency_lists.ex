defmodule ZXCVBN.FrequencyLists do
  @moduledoc """
  Frequency Lists created by [this script][frequency-lists-script]

  [frequency-lists-script]: https://github.com/dropbox/zxcvbn/blob/cb040cd780e42adaafb998625c5a5c91db3dbaab/data-scripts/build_frequency_lists.py
  """

  import ZXCVBN.Utils, only: [file_to_list: 1]

  @external_resource passwords_file = "priv/frequency_lists/passwords.txt"
  @external_resource english_wikipedia_file = "priv/frequency_lists/english_wikipedia.txt"
  @external_resource female_names_file = "priv/frequency_lists/female_names.txt"
  @external_resource surnames_file = "priv/frequency_lists/surnames.txt"
  @external_resource us_tv_and_film_file = "priv/frequency_lists/us_tv_and_film.txt"
  @external_resource male_names_file = "priv/frequency_lists/male_names.txt"

  @passwords file_to_list(passwords_file)
  @english_wikipedia file_to_list(english_wikipedia_file)
  @female_names file_to_list(female_names_file)
  @surnames file_to_list(surnames_file)
  @us_tv_and_film file_to_list(us_tv_and_film_file)
  @male_names file_to_list(male_names_file)

  def frequency_lists do
    %{
      passwords: @passwords,
      english_wikipedia: @english_wikipedia,
      female_names: @female_names,
      surnames: @surnames,
      us_tv_and_film: @us_tv_and_film,
      male_names: @male_names
    }
  end
end
