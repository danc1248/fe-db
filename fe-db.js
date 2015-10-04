(function() {
  window.FEDB = (function() {
    var Comparison, Database, Query, Table;
    if (!$) {
      throw new Error("jQuery is required for promises");
    }

    /*
    Database: holds our tables, usage:
    d = new Database()
    d.setTable("trees", schema, sample_data)
    d.getTable("trees").query(...).execute().then (results)->
      do stuff
     */
    Database = (function() {
      function Database() {
        this.tables = {};
      }

      Database.prototype.setTable = function(name, schema, data) {
        if (data == null) {
          data = [];
        }
        this.tables[name] = new Table(schema, data);
      };

      Database.prototype.getTable = function(name) {
        return this.tables[name];
      };

      return Database;

    })();

    /*
    Tables: hold our data and schema (unused)
    run queries on the table, or do a direct lookup using getByIndex
     */
    Table = (function() {
      function Table(schema1, data1) {
        this.schema = schema1;
        this.data = data1;
        this.indexes = {};
      }

      Table.prototype.addIndex = function(field) {
        var i, index, j, len, ref, row;
        index = {};
        ref = this.data;
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          row = ref[i];
          index[row[field]] = i;
        }
      };

      Table.prototype._hasIndex = function(field) {
        return !!this.indexes[field];
      };

      Table.prototype.getByIndex = function(field, value) {
        var i;
        i = this.indexes[field][value];
        return this.data[i];
      };

      Table.prototype._getData = function() {
        return this.data;
      };

      Table.prototype.query = function(field, operation, value) {
        var c, q;
        c = new Comparison(field, operation, value);
        q = new Query(this, c);
        return q;
      };

      return Table;

    })();

    /*
    Query: a query executes a series of comparisons on a table and returns the matches
    its sort of clunky right now, we'll have to change it based off of usage because I'm not really sure what we'll need it to do
     */
    Query = (function() {
      function Query(table, comparison) {
        this.table = table;
        this.comparison = comparison;
        this.andComparison = null;
        this.orComparison = null;
        this.orderByFn = null;
      }

      Query.prototype.and = function(field, operation, value) {
        this.andComparison = new Comparison(field, operation, value);
        return this;
      };

      Query.prototype.or = function(field, operation, value) {
        this.orComparison = new Comparison(field, operation, value);
        return this;
      };

      Query.prototype.orderBy = function(field, order) {
        if (order == null) {
          order = "ASC";
        }
        switch (order) {
          case "ASC":
          case "asc":
            this.orderByFn = function(a, b) {
              var aVal, bVal;
              aVal = a[field];
              bVal = b[field];
              if (aVal < bVal) {
                return -1;
              } else if (aVal > bVal) {
                return 1;
              } else {
                return 0;
              }
            };
            break;
          case "DESC":
          case "desc":
            this.orderByFn = function(a, b) {
              var aVal, bVal;
              aVal = a[field];
              bVal = b[field];
              if (aVal < bVal) {
                return 1;
              } else if (aVal > bVal) {
                return -1;
              } else {
                return 0;
              }
            };
            break;
          default:
            throw new Error("unknown ordering: " + order);
        }
        return this;
      };

      Query.prototype.execute = function() {
        var deferred;
        deferred = $.Deferred();
        setTimeout((function(_this) {
          return function() {
            var output;
            output = [];
            if (_this.andComparison) {
              output = _this._executeAnd();
            } else if (_this.orComparison) {
              output = _this._executeOr();
            } else if (_this.comparison.getOperation() === "=" && _this.table._hasIndex(_this.comparison.getField())) {
              output = _this._executeIndexed();
            } else {
              output = _this._executeBasic();
            }
            if (_this.orderByFn) {
              output = output.sort(_this.orderByFn);
            }
            return deferred.resolve(output);
          };
        })(this));
        return deferred.promise();
      };

      Query.prototype._executeBasic = function() {
        var j, len, output, ref, row;
        output = [];
        ref = this.table._getData();
        for (j = 0, len = ref.length; j < len; j++) {
          row = ref[j];
          if (this.comparison.compare(row)) {
            output.push(row);
          }
        }
        return output;
      };

      Query.prototype._executeAnd = function() {
        var j, len, output, ref, row;
        output = [];
        ref = this.table._getData();
        for (j = 0, len = ref.length; j < len; j++) {
          row = ref[j];
          if (this.comparison.compare(row) && this.andComparison.compare(row)) {
            output.push(row);
          }
        }
        return output;
      };

      Query.prototype._executeOr = function() {
        var j, len, output, ref, row;
        output = [];
        ref = this.table._getData();
        for (j = 0, len = ref.length; j < len; j++) {
          row = ref[j];
          if (this.comparison.compare(row) || this.orComparison.compare(row)) {
            output.push(row);
          }
        }
        return output;
      };

      Query.prototype._executeIndexed = function() {
        return this.table.getByIndex(this.field, this.value);
      };

      return Query;

    })();

    /*
    Comparison: used by the query to see if a values meet the criteria
     */
    Comparison = (function() {
      function Comparison(field1, operation1, value1) {
        this.field = field1;
        this.operation = operation1;
        this.value = value1;
        this.operationFn = null;
        this.setOperation(this.operation);
      }

      Comparison.prototype.getField = function() {
        return this.field;
      };

      Comparison.prototype.getOperation = function() {
        return this.operation;
      };

      Comparison.prototype.setOperation = function(operation1) {
        this.operation = operation1;
        switch (this.operation) {
          case "=":
            this.operationFn = function(a, b) {
              return a === b;
            };
            break;
          case "<>":
          case "!=":
            this.operationFn = function(a, b) {
              return a !== b;
            };
            break;
          case "<":
            this.operationFn = function(a, b) {
              return a < b;
            };
            break;
          case ">":
            this.operationFn = function(a, b) {
              return a > b;
            };
            break;
          case "<=":
            this.operationFn = function(a, b) {
              return a <= b;
            };
            break;
          case ">=":
            this.operationFn = function(a, b) {
              return a >= b;
            };
            break;
          default:
            throw new Error("operation not supported: " + this.operation);
        }
      };

      Comparison.prototype.compare = function(row) {
        return this.operationFn(row[this.field], this.value);
      };

      return Comparison;

    })();
    return {
      Database: Database,
      Table: Table,
      Query: Query,
      Comparison: Comparison
    };
  })();

}).call(this);
