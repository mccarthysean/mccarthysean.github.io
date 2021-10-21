#!/bin/bash

bundle exec jekyll serve --incremental --force_polling -H 0.0.0.0 -P 4000
# bundle exec jekyll serve --incremental --force_polling -H localhost -P 4000
# bundle exec jekyll serve --config _config.yml,_config.dev.yml --incremental --watch --force_polling -H 127.0.0.1 -P 4000
# bundle exec jekyll serve --config _config.yml,_config.dev.yml --incremental --watch --force_polling -P 4000

