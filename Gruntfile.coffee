module.exports = (grunt)->

  # Project configuration.
  grunt.initConfig {
    pkg: grunt.file.readJSON "package.json"

    # for running tests in nodejs using jasmine
    jasmine_nodejs:
      options:
        specNameSuffix: "spec.coffee"
        useHelpers: false
        stopOnFailure: false
      default: 
        specs: ["spec/*"]

  }

  # Load the plugins
  grunt.loadNpmTasks "grunt-jasmine-nodejs"

  # Default task(s).
  grunt.registerTask "test", ["jasmine_nodejs:default"]
