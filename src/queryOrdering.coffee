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


module.exports = QueryOrdering