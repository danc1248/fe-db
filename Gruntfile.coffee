module.exports = (grunt)->

  # Project configuration.
  grunt.initConfig {
    pkg: grunt.file.readJSON "package.json"
    # compile all coffeescript files from the src directory into the web place
    coffee:
      compile:
        files:
          "fe-db.js": "src/**/*.coffee"

    # minify our javascript
    uglify:
      options:
        banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' +
        '<%= grunt.template.today("yyyy-mm-dd") %> */'
      default:
        files:
          "fe-db.min.js": "fe-db.js"

    # watch files for changes so we can compile in realtime
    watch:
      coffee:
        files: ["src/**/*.coffee"]
        tasks: ["coffee", "uglify"]
  }

  # Load the plugins
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-uglify"
  grunt.loadNpmTasks "grunt-contrib-watch"

  # Default task(s).
  grunt.registerTask "default", ["coffee", "uglify", "watch"]
