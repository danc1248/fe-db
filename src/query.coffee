###
Query: a query executes a series of comparisons on a table and returns the matches
its sort of clunky right now, we'll have to change it based off of usage because I'm not really sure what we'll need it to do
###

DataTypes = require "./datatypes.coffee"
Comparison = require "./comparison.coffee"
QueryOrdering = require "./queryOrdering.coffee"

class Query
  # requires a reference to the table it is being executed on.  This is used to validate fields, and during execution, to get the data
  constructor: (@table)->
    @comparison = null
    @queryOrdering = null
    @join = null # { field: String, query: Query }
    @selectFields = null # [ array of field names to return ]
    @limitBy = null

  select: (@selectFields)->
    return @

  limit: (@limitBy)->
    return @

  # shorthand for setComparison
  where: (field, operator)->
    c = new Comparison(field, operator)
    return @setComparison(c)

  # shorthand for setQueryOrdering
  orderBy: (field, order = "ASC")->
    qo = new QueryOrdering(field, order)
    return @setQueryOrdering(qo)

  # shorthand for setJoin
  # this table demonstrates the proper way to construct a join query using "IN"
  leftJoin: (field, database, tableName = null, orderByField = null, order = null)->
    if @table._getSchema()._getType(field) is DataTypes.Table
      if tableName is null
        tableName = @table._getSchema()._getTableName(field)
      table = database.getTable(tableName)
      q = table.query().where("id", "in")
      if orderByField isnt null
        q.orderBy(orderByField, order)
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
  execute: (value, callback)->
    setTimeout =>
      try
        results = @__execute(value)
      catch e
        callback(e)
        return

      callback(null, results)

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
        # note: it is important that the data gets cloned in this filter function
        results = @table._getData().filter (row)=>
          return @comparison._compare(row, value)

    # no comparison? guess we're returning everything
    # we clone the data here to make sure it doesn't get modified.
    else
      results = JSON.parse(JSON.stringify(@table._getData()))

    ## 2. Join additional tables
    if @join isnt null
      # Note: the joinField is by definition of type DataTypes.Table and its value is an array of ids
      joinField = @join.field
      joinQuery = @join.query
      # for each row we expect an array of ids that need to be replaced with actual elements
      for row in results      
        joinIds = row[joinField] # [foreignId, foreignId, ...] to be replaced with rows

        joinResults = joinQuery.__execute(joinIds)
        # .map (id)=>
        #   [results] = joinQuery.__execute(id) # assumes there is only one result
        #   return results

        # # a query ordering attached to the join would sort each individual row by ordering, thus not doing anything
        # # what we assume the caller meant to do was order all the rows in the join, which we do here:
        # if joinQuery.queryOrdering isnt null
        #   joinResults = joinQuery.queryOrdering._sortResults(joinResults)

        row[joinField] = joinResults

    ## 3. Order the results
    if @queryOrdering isnt null
      results = @queryOrdering._sortResults(results)

    if @limitBy isnt null and results and results.length > @limitBy
      results = results[0..@limitBy-1]

    return results

module.exports = Query