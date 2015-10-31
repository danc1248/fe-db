# database for managing static data.  Note that you cannot add or delete data, only initialize an entire set
# requires promise object

window.FEDB = do ->
  if not $
    throw new Error "jQuery is required for promises"

  ###
  Constants for representing datatypes for validation, etc.
  ###
  DataTypes =
    Number: 1
    String: 2
    Enum: 3
    Table: 4

  ###
  Database: holds our tables, usage:
  d = new Database()
  d.setTable("trees", schema, sample_data)
  d.getTable("trees").query(...).execute().then (results)->
    do stuff
  ###
  class Database
    constructor: ->
      @tables = {}

    setTable: (name, schemaObj, data = [])->
      schema = new Schema(schemaObj, @)
      @tables[name] = new Table(schema, data)
      return @

    # @return a table instance for querying or whatever
    getTable: (name)->
      if @tables[name] is undefined
        throw new Error "Unknown table: #{name}"
      else
        return @tables[name]

  ###
  Holds table schema and does some validation etc.
  e.g.
  {
    id: {
      type: Number
      unique: true <-- add a unique index
    }
    age: Number
    name: String
    text: {
      type: String
    }
    gender: {
      type: Enum
      values: ["m", "f"]
    }
    hobbies: {
      type: Table
      target: "hobbies"
    }
  }
  ###
  class Schema
    # this schema could be on a complete form that we want to save:
    # { id: { type: Number, ...other properties }, ... other fields}
    # or it could be simple: { id: Number } in which case we have to extend it
    # database, schemas can reference other tables, so we need to keep track of original calling database so we can grab those tables
    constructor: (@schema, @database)->
      @indexes = []
      # look fo simple enteries and extend them:
      for field, mixed of @schema
        if $.type(mixed) isnt "object"
          @schema[field] = { type: mixed }
        else
          # currently only support unique indexes, beware!
          if mixed.unique is true
            @indexes.push field

      @fields = Object.keys(@schema)

    _getIndexes: ->
      return @indexes

    _validateData: (data)->
      for row in data
        @_validateRow(row)
      return true

    _validateRow: (row, index)->
      if @fields.length isnt Object.keys(row).length
        throw new Error "unmatched field count for row: #{index}"

      for field in @fields
        if row[field] is undefined
          throw new Error "Row not found: #{field} at #{index}"
        @_validateField(row[field], @schema[field], field)
      return true

    _validateField: (unknown, schema, field)->
      if schema.type is DataTypes.Number and $.type(unknown) is "number"
        return true

      if schema.type is DataTypes.String and $.type(unknown) is "string"
        return true

      if schema.type is DataTypes.Enum and schema.values.indexOf(unknown) isnt -1
        return true

      if schema.type is DataTypes.Table
        table = @database.getTable(schema.target)
        nested = table._getSchema()
        if nested._validateData(unknown)
          return true

      throw new Error "invalid type in data: #{field}: #{unknown}"


  ###
  Tables: hold our data and schema
  run queries on the table, or do a direct lookup using getByIndex
  ###
  class Table
    constructor: (@schema, @data)->
      @schema._validateData(@data)
      @indexes = {}
      for index in @schema._getIndexes()
        @indexes[index] = @_addIndex(index)


    _getSchema: ->
      return @schema

    # Creates a unique index on a field for fast lookups
    # @indexes[field] = { value : data array index, ... }
    # indexes must be added after the data is initialized
    # indexes must be unique, which we don't verify
    _addIndex: (field)->
      index = {}
      for row, i in @data
        if index[row[field]] is undefined
          index[row[field]] = i
        else
          throw new Error "non unique index: #{field}"
      return index

    # is this field indexed?
    # @return boolean
    _hasIndex: (field)->
      return !!@indexes[field]

    # quick lookup of an indexed field
    # @return row found by unique index
    getByIndex: (field, value)->
      i = @indexes[field][value]
      return @data[i]

    # used by the query function to execute the query
    _getData: -> return @data

    # run a query on the table
    # usage:
    # table.query("field", "=", 5).execute()
    # the execute function returns a promise
    # MIXED PARAMS:
    #   to query for all pass no params
    #   to use a default operation of "=" pass field and value
    #   pass 3 params for field, operation, value
    # @return Query Object for chaining options, ending in execute
    query: ->
      switch arguments.length
        when 0, 1
          c = new Comparison(null, "*", null)
        when 2
          c = new Comparison(arguments[0], "=", arguments[1])
        else
          c = new Comparison(arguments[0], arguments[1], arguments[2])

      q = new Query(@, c)
      return q

  ###
  Query: a query executes a series of comparisons on a table and returns the matches
  its sort of clunky right now, we'll have to change it based off of usage because I'm not really sure what we'll need it to do
  ###
  class Query
    constructor: (@table, @comparison)->
      @queryOrdering = null

    orderBy: (field, order = "ASC")->
      @queryOrdering = new QueryOrdering(field, order)
      return @

    # execute the query!!
    # @param the search value to match the comparisons field against
    # this is async so as not to block, returns a promise
    execute: (value)->
      deferred = $.Deferred()

      setTimeout =>
        # for an indexed field, we just grab the values by direct lookup, very fast:
        if @comparison._isSingleOperation() and @table._hasIndex(@comparison._getField())
          row = @table.getByIndex(@field, value)
          output = [row]

        # otherwise we have to just lookup by hand, very slow
        else
          output = @table._getData().filter (row)=>
            return @comparison._compare(row, value)

        if @queryOrdering
          output = @queryOrdering._sortResults(output)

        deferred.resolve output

      return deferred.promise()

  ###
  For ordering queries, to keep the query object neater
  ###
  class QueryOrdering
    constructor: (field, order)->
      switch order
        when "ASC", "asc"
          @orderByFn = (a, b)->
            aVal = a[field]
            bVal = b[field]
            if aVal < bVal
              return -1
            else if aVal > bVal
              return 1
            else
              return 0
        when "DESC", "desc"
          @orderByFn = (a, b)->
            aVal = a[field]
            bVal = b[field]
            if aVal < bVal
              return 1
            else if aVal > bVal
              return -1
            else
              return 0
        else
          throw new Error "unknown ordering: #{order}"

    _sortResults: (results)->
      return results.sort @orderByFn


  ###
  Comparison: used by the query to see if a values meet the criteria
  ###
  class Comparison
    # valid operations: =, <>, !=, <, >, <=, >=
    constructor: (@field, @operation, @value)->
      @operationFn = null
      @setOperation(@operation)

    _getField: -> return @field
    _isSingleOperation: -> return @operation is "="

    # separate function in case you want to change the default operation after initialization
    # inits the operation function, which is a comparison function between two values
    setOperation: (@operation)->
      switch @operation
        when "="
          @operationFn = (a, b)-> return a is b
        when "<>", "!="
          @operationFn = (a, b)-> return a isnt b
        when "<"
          @operationFn = (a, b)-> return a < b
        when ">"
          @operationFn = (a, b)-> return a > b
        when "<="
          @operationFn = (a, b)-> return a <= b
        when ">="
          @operationFn = (a, b)-> return a >= b
        when "*"
          @operationFn = -> return true
        else
          throw new Error "operation not supported: #{@operation}"
      return

    _compare: (row)->
      return @operationFn(row[@field], @value)

  return {
    Database: Database
    Table: Table
    Query: Query
    Comparison: Comparison
    Data: DataTypes
  }