#! /usr/bin/env bash

function func1() {

    echo 1-0

    if true; then
        echo "1-1"
    fi

    if true; then
        echo "1-2"
        return 0
    fi

    echo "1-3"
}

function func2() {
    echo "2-0"
}

func1

func2

if [[ ! -t 0 ]]; then
  while IFS= read -r domain; do
    subenum "$domain"
  done
fi
