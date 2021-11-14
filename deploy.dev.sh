#!/bin/bash

# Full reload
# bundle exec jekyll serve --force_polling -H 0.0.0.0 -P 4000

# Incremental (faster)
bundle exec jekyll serve --incremental --force_polling -H 0.0.0.0 -P 4000
