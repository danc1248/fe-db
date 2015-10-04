# database for managing static data.  Note that you cannot add or delete data, only initialize an entire set
# requires promise object

window.FEDB = do ->
  if not $
    throw new Error "jQuery is required for promises"

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

    setTable: (name, schema, data = [])->
      @tables[name] = new Table(schema, data)
      return

    # @return a table instance for querying or whatever
    getTable: (name)->
      return @tables[name]

  ###
  Tables: hold our data and schema (unused)
  run queries on the table, or do a direct lookup using getByIndex
  ###
  class Table
    constructor: (@schema, @data)->
      @indexes = {}

    # Creates a unique index on a field for fast lookups
    # @indexes[field] = { value : data array index, ... }
    # indexes must be added after the data is initialized
    # indexes must be unique, which we don't verify
    addIndex: (field)->
      index = {}
      for row, i in @data
        index[row[field]] = i
      return

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
    # @return Query Object for chaining options, ending in execute
    query: (field, operation, value)->
      c = new Comparison(field, operation, value)
      q = new Query(@, c)
      return q

  ###
  Query: a query executes a series of comparisons on a table and returns the matches
  its sort of clunky right now, we'll have to change it based off of usage because I'm not really sure what we'll need it to do
  ###
  class Query
    constructor: (@table, @comparison)->
      @andComparison = null
      @orComparison = null
      @orderByFn = null

    # add another comparison that both this and the base must be met
    # doens't support more then 2 total comparisons because I'm lazy
    # return Query for chaining
    and: (field, operation, value)->
      @andComparison = new Comparison(field, operation, value)
      return @

    # add a comparison that this OR the base must be met
    # same notes as AND
    or: (field, operation, value)->
      @orComparison = new Comparison(field, operation, value)
      return @

    orderBy: (field, order = "ASC")->
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

      return @

    # execute the query!!
    # this is async so as not to block, returns a promise
    execute: ->
      deferred = $.Deferred()

      setTimeout =>
        output = []

        if @andComparison
          output = @_executeAnd()

        else if @orComparison
          output = @_executeOr()

        else if @comparison.getOperation() is "=" and @table._hasIndex(@comparison.getField())
          output = @_executeIndexed()

        else 
          output = @_executeBasic()

        if @orderByFn
          output = output.sort(@orderByFn)

        deferred.resolve output

      return deferred.promise()

    _executeBasic: ->
      output = []
      for row in @table._getData()
        if @comparison.compare(row)
          output.push row
      return output

    _executeAnd: ->
      output = []
      for row in @table._getData()
        if @comparison.compare(row) and @andComparison.compare(row)
          output.push row
      return output

    _executeOr: ->
      output = []
      for row in @table._getData()
        if @comparison.compare(row) or @orComparison.compare(row)
          output.push row
      return output

    _executeIndexed: ->
      return @table.getByIndex(@field, @value)

  ###
  Comparison: used by the query to see if a values meet the criteria
  ###
  class Comparison
    # valid operations: =, <>, !=, <, >, <=, >=
    constructor: (@field, @operation, @value)->
      @operationFn = null
      @setOperation(@operation)

    getField: -> return @field
    getOperation: -> return @operation

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
        else
          throw new Error "operation not supported: #{@operation}"
      return

    compare: (row)->
      return @operationFn(row[@field], @value)

  return {
    Database: Database
    Table: Table
    Query: Query
    Comparison: Comparison
  }