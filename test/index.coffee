import assert from "@dashkite/assert"
import {test, success} from "@dashkite/amen"
import print from "@dashkite/amen-console"

import { command as exec } from "execa"

sh = ( command ) ->
  result = await exec command, 
    { stdout: "pipe", stderr: "pipe", shell: true }

do ->

  print await test "Dashkite Echo", [

    test "baseline", ->
      result = await sh "cat test/data/baseline.json |
        bin/sedna 'yield $.level if $.level == \"INFO\"'"
      lines = result.stdout.split "\n"
      for line in lines
        assert.equal "INFO", JSON.parse line

    test "path function", ->
      result = await sh "cat test/data/baseline.json |
        bin/sedna 'yield ( path \"$.[*].request\", $)[0]'"
      lines = result.stdout.split "\n"
      for line in lines when line != "undefined"
        value = JSON.parse line

  ]

  process.exit if success then 0 else 1
