import FS from "node:fs"
import FSP from "node:fs/promises"
import Path from "node:path"
import Coffee from "coffeescript"
import * as Fn from "@dashkite/joy/function"
import * as It from "@dashkite/joy/iterable"
import { program } from "commander"
import { JSONPath as jsonpath } from "jsonpath-plus"
import prettyYAML from "prettyoutput"
import prettyJSON from "jsome"
import YAML from "js-yaml"

read = ->

  handlers = {}

  process.stdin.on "data", ( data ) ->
    handlers.resolve data.toString()
  process.stdin.on "error", ( error ) ->
    handlers.reject error
  process.stdin.on "end", -> 
    handlers.resolve undefined

  loop
    try
      data = await new Promise ( resolve, reject ) ->
        Object.assign handlers, { resolve, reject}
      if data?
        yield data
      else break        
    catch error
      console.error error
      
lines = ( reactor ) ->
  do ({ lines, json } = {}) ->
    json = ""
    for await text from reactor
      json += text
      [ lines..., last ] = json.split "\n"
      if last?
        for line in lines
          yield line
        json = last
      else
        json += last

json = ( reactor ) ->
  do ({ json } = {}) ->
    for await json from reactor
      yield JSON.parse json

indent = ( text ) ->
  text
    .split "\n"
    .map ( line ) -> "  #{ line }"
    .join "\n"

compile = ( code, path ) ->
  Coffee.compile """
      ({ path }, _, $ ) -> 
      #{ indent code }
    """,
    bare: true
    inlineMap: true
    filename: path

fn = ( code ) -> eval code

transform = Fn.curry ( f, it ) ->
  for await x from it
    for await y from f x
      yield y

Filter =

  make: ( code, path ) ->
    Fn.curry fn compile code, path

  fromPath: ( path ) ->
    Filter.make ( await FSP.readFile path, "utf8" ), "/#{ path }"

Helpers = {
  path: jsonpath
}

Format = {
  select: ({ pretty, yaml }) ->
    if pretty
      if yaml
        Format.Pretty.yaml
      else
        Format.Pretty.json
    else if yaml
      Format.yaml
    else Format.json

  Pretty:
    yaml: ( x ) ->
      prettyYAML x, maxDepth: 99, alignKeyValues: false
    json: ( x ) -> if x? then prettyJSON x
  json: JSON.stringify
  yaml: YAML.dump
}

run = ( filter, { files, pretty, yaml }) ->

  filters = if filter? then [ Filter.make filter ] else []
  
  if files?
    for path in files
      filters.push await Filter.fromPath path
  
  state = {}

  do Fn.flow [
    read
    lines
    json
    Fn.flow filters.map ( filter ) -> transform filter Helpers, state
    It.map Format.select { pretty, yaml }
    It.each ( x ) -> console.log x
  ]
      
program
  .version do ({ path, json, pkg } = {}) ->
    path = Path.join __dirname, "..", "..", "..", "package.json"
    json = FS.readFileSync path, "utf8"
    pkg = JSON.parse json
    pkg.version
  .enablePositionalOptions()
  .description "JSON stream processor"
  .argument "[filter]", "Filter to use when processing input"
  .option "-f, --files <filename...>", "Read filters from a file"
  .option "-p, --pretty", "Pretty print output"
  .option "-y, --yaml", "Output YAML instead of JSON"
  .action run

program.parseAsync()
