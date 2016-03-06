###
Tables: hold our data and schema
run queries on the table, or do a direct lookup using getByIndex
###

Query = require "./query.coffee"

class Table
  constructor: (@schema, @data)->
    @schema._validateData(@data)
    @indexes = {}
    for index in @schema._getIndexes()
      @indexes[index] = @__addIndex(index)

  _getSchema: ->
    return @schema

  # Creates a unique index on a field for fast lookups
  # @indexes[field] = { value : data array index, ... }
  # indexes must be added after the data is initialized
  # indexes must be unique
  __addIndex: (field)->
    index = {}
    for row, i in @data
      if index[row[field]] is undefined
        index[row[field]] = i
      else
        throw new Error "non unique index: #{field}; value: #{row[field]}"
    return index

  # is this field indexed?
  # @return boolean
  _hasIndex: (field)->
    return !!@indexes[field]

  # quick lookup of an indexed field
  # @param: string field that we are querying
  # @param: mixed value that we are searching on
  # @return row found by unique index
  getByIndex: (field, value)->
    if @indexes[field] isnt undefined
      if @indexes[field][value] isnt undefined
        i = @indexes[field][value]
        return @data[i]
      else
        # could be an error?
        return null
    else
      throw new Error "getByIndex called on non-indexed field: #{field}, #{value}"

  # used by the query function to execute the query
  _getData: -> return @data

  # run a query on the table - shorthand for creating a new comparison and saving it as a query
  # @param: String field we are searching on, null for special case "*"
  # @param: String operator to pass to comparison, can be "*" for find all case
  # @return Query object for chaining commands:
  # usage:
  # table.query("field", "=").execute(5)
  # the execute function returns a promise
  query: ->
    q = new Query(@)
    return q

module.exports = Table