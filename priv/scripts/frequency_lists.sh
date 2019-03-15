#!/bin/bash

wget 'https://raw.githubusercontent.com/dropbox/zxcvbn/master/src/frequency_lists.coffee'

grep 'passwords: ' frequency_lists.coffee | cut -d'"' -f2 | tr ',' '\n' > ../frequency_lists/passwords.txt
grep 'english_wikipedia: ' frequency_lists.coffee | cut -d'"' -f2 | tr ',' '\n' > ../frequency_lists/english_wikipedia.txt
grep 'female_names: ' frequency_lists.coffee | cut -d'"' -f2 | tr ',' '\n' > ../frequency_lists/female_names.txt
grep 'surnames: ' frequency_lists.coffee | cut -d'"' -f2 | tr ',' '\n' > ../frequency_lists/surnames.txt
grep 'us_tv_and_film: ' frequency_lists.coffee | cut -d'"' -f2 | tr ',' '\n' > ../frequency_lists/us_tv_and_film.txt
grep ' male_names: ' frequency_lists.coffee | cut -d'"' -f2 | tr ',' '\n' > ../frequency_lists/male_names.txt

rm -rf frequency_lists.coffee
