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
    Table: 4
    Image: 5

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

    # other classes sometimes want to poke in and see what the data type is:
    # @param: string field
    # @return: Datatypes.*
    _getType: (field)->
      obj = @schema[field]
      if obj is undefined
        throw new Error "Unknown type: #{field}"
      else
        return obj.type

    # similarly, if you are joining on a table, you might want to lookup what its supposed to be joined on, as defined in the schema
    _getTableName: (field)->
      obj = @schema[field]
      if obj is undefined or obj.tableName is undefined
        throw new Error "Unknown table name: #{field}"
      else
        return obj.tableName

    # this class knows which fields are indexed, but does not build or use them at all
    # building indexes is handled at the table level
    # @return : Array of String names of fields that have indexes
    _getIndexes: ->
      return @indexes

    # When data is added to a table, you can validate it using this function, this step is optional because if your data is static, you don't need to validate it all he time
    # @param: array of objects to validate against the schema
    # @return: boolean
    _validateData: (data)->
      for row in data
        @__validateRow(row)
      return true

    # validate a single object from the array
    __validateRow: (row, index)->
      if @fields.length isnt Object.keys(row).length
        throw new Error "unmatched field count for row: #{index}"

      for field in @fields
        if row[field] is undefined
          throw new Error "Row not found: #{field} at #{index}"
        @__validateField(row[field], @schema[field], field)
      return true

    # validate a field from the single object
    # @param: mixed variable that we are validating
    # @param: object representing this field's schema
    # @param: string field name
    # @return: boolean
    __validateField: (unknown, schema, field)->
      if schema.type is DataTypes.Number and $.type(unknown) is "number"
        return true

      if schema.type is DataTypes.String and $.type(unknown) is "string"
        return true

      # this is based off of how airtable handles joins.  The field contains an array of string, which are their internal ID for the row at the table.  By convention, we are assuming that the name of he field is the same as the name of the table.
      if schema.type is DataTypes.Table and $.type(unknown) is "array"
        # we don't check if the table exists because we dont' want to constrain load order
        if schema.tableName is undefined
          schema.tableName = field
        return true

      # @TODO: this is modeled after airtable's attachments and I'm not exactly sure how its going to be used
      if schema.type is DataTypes.Image and $.type(unknown) is "object"
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
          throw new Error "non unique index: #{field}"
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
      if @indexes[field] isnt undefined and @indexes[field][value] isnt undefined
        i = @indexes[field][value]
        return @data[i]
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

  ###
  Query: a query executes a series of comparisons on a table and returns the matches
  its sort of clunky right now, we'll have to change it based off of usage because I'm not really sure what we'll need it to do
  ###
  class Query
    constructor: (@table)->
      @comparison = null
      @queryOrdering = null
      @join = null # { field: String, query: Query }

    # shorthand for setComparison
    where: (field, operator)->
      c = new Comparison(field, operator)
      return @setComparison(c)

    # shorthand for setQueryOrdering
    orderBy: (field, order = "ASC")->
      qo = new QueryOrdering(field, order)
      return @setQueryOrdering(qo)

    # shorthand for setJoin
    leftJoin: (field, database, tableName = null)->
      if @table._getSchema()._getType(field) is DataTypes.Table
        if tableName is null
          tableName = @table._getSchema()._getTableName(field)
        table = database.getTable(tableName)
        q = table.query().where("id", "=")
        return @setJoin(field, q)
      else
        throw new Error "Join only supported for DataType.Table: #{field}"

    # set the comparison class, which filters the search results
    # @param: Comparison
    # @return: this Query for chaining
    setComparison: (comparison)->
      if @comparison is null
        @comparison = comparison
      else
        throw new Error "Comparison already set"
      return @

    # define a QueryOrdering that will order the search results
    # @param: QueryOrdering
    # @return; this Query for chaining
    setQueryOrdering: (queryOrdering)->
      if @queryOrdering is null
        @queryOrdering = queryOrdering
      else
        throw new Error "QueryOrdering already set"
      return @

    # join another table onto this one, can only do one for now, althrough there isn't any reason why this couldn't be an array of joins
    # @param Query
    # @return ths Query for chaining
    setJoin: (field, query)->
      if @join is null
        @join = {
          field: field
          query: query
        }
      else
        throw new Error "Join already set, your dev is lazy and you cant do multiple joins"
      return @

    # execute the query!!
    # @param the search value to match the comparisons field against
    # @return this is async so as not to block, returns a promise
    execute: (value)->
      deferred = $.Deferred()

      setTimeout =>
        deferred.resolve @__execute(value)

      return deferred.promise()

    # the execute function is actually syncronus, and we recurse it for joins
    __execute: (value)->
      ## 1. Get the data using the Comparison:
      if @comparison isnt null
        # for an indexed field, we just grab the values by direct lookup, very fast:
        field = @comparison._getField()
        if @comparison._isSingleOperation() and @table._hasIndex(field)
          row = @table.getByIndex(field, value)
          results = [row]

        # otherwise we have to just lookup by hand, very slow
        else
          results = @table._getData().filter (row)=>
            return @comparison._compare(row, value)
      # no comparison? guess we're returning everything
      else
        results = JSON.parse(JSON.stringify(@table._getData()))

      ## 2. Join additional tables
      if @join isnt null
        # Note: the joinField is by definition of type DataTypes.Table and its value is an array of ids
        joinField = @join.field
        joinQuery = @join.query
        results = results.map (row)=>
          joinIds = row[joinField] # [foreignId, foreignId, ...]
          row[joinField] = joinIds.map (id)=>
            [results] = joinQuery.__execute(id) # assumes there is only one result
            return results
          return row

      ## 3. Order the results
      if @queryOrdering isnt null
        results = @queryOrdering._sortResults(results)

      return results

  ###
  For ordering queries, to keep the query object neater
  ###
  class QueryOrdering
    # @param field to order based on
    # @param String like mysql: asc, desc
    # sets @orderByFn which is basically just a js sort fn
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

    # sort the results based off of the order fn set in the constructor
    # @param Array to sort
    # @return sorted Array of course
    _sortResults: (results)->
      return results.sort @orderByFn


  ###
  Comparison: used by the query to see if a row should be included in the search results
  ###
  class Comparison
    # valid operations: =, <>, !=, <, >, <=, >=
    constructor: (@field, @operation)->
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

    # these two functions are used by the Query.execute method to determine if we can use the getByIndex function instead of looking up the results
    _getField: -> return @field
    _isSingleOperation: -> return @operation is "="

    # the action function!
    # @param Object of data, presumably contains "field" although we don't explicitly test this
    # @param Mixed value to use in the operationFn
    # @return: boolean if the row is valid or not
    _compare: (row, value)->
      return @operationFn(row[@field], value)

  return {
    Database: Database
    Table: Table
    Query: Query
    Comparison: Comparison
    Data: DataTypes
  }