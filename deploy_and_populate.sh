#!/bin/bash

mix run --no-start -e  '
   contents = OMG.Eth.DevHelpers.prepare_env!() |> OMG.Eth.DevHelpers.create_conf_file()
   "~/config.exs" |> Path.expand() |> File.write!(contents)
 '
