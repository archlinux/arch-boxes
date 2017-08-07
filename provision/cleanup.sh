#!/bin/bash

set -e
set -x

# clear package cache
yes | sudo pacman -Scc
