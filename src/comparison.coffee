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
      # not super efficient:
      when "IN", "in"
        @operationFn = (a, b)-> return (b.indexOf(a) isnt -1)
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
    # console.log "comparing this:", row[@field], value
    return @operationFn(row[@field], value)

module.exports = Comparison