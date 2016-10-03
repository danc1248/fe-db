###
Database: holds our tables, usage:
d = new Database()
d.setTable("trees", schema, sample_data)
d.getTable("trees").query(...).execute().then (results)->
  do stuff
###

Schema = require "./schema.coffee"
Table = require "./table.coffee"

class Database
  constructor: ->
    @tables = {}

  setTable: (name, schemaObj, data = [])->
    schema = new Schema(schemaObj, name)
    @tables[name] = new Table(schema, data)
    return @

  # @return a table instance for querying or whatever
  getTable: (name)->
    if @tables[name] is undefined
      throw new Error "Unknown table: #{name}"
    else
      return @tables[name]

module.exports = Database