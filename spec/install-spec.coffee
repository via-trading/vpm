path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'

describe 'apm install', ->
  atomHome = null

  beforeEach ->
    spyOnToken()
    silenceOutput()

    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome

  describe "when installing an atom package", ->
    server = null

    beforeEach ->
      app = express()
      app.get '/node/v0.10.3/node-v0.10.3.tar.gz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node-v0.10.3.tar.gz')
      app.get '/node/v0.10.3/node.lib', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node.lib')
      app.get '/node/v0.10.3/x64/node.lib', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'node_x64.lib')
      app.get '/tarball/test-module-1.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-1.0.0.tgz')
      app.get '/tarball/test-module2-2.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module2-2.0.0.tgz')
      app.get '/packages/test-module', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-test-module.json')
      app.get '/packages/test-module2', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-test-module2.json')
      app.get '/packages/test-module-with-symlink', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'install-test-module-with-symlink.json')
      app.get '/tarball/test-module-with-symlink-5.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-with-symlink-5.0.0.tgz')
      app.get '/tarball/test-module-with-bin-2.0.0.tgz', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'test-module-with-bin-2.0.0.tgz')

      server =  http.createServer(app)
      server.listen(3000)

      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_NODE_URL = "http://localhost:3000/node"
      process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
      process.env.ATOM_NODE_VERSION = 'v0.10.3'

    afterEach ->
      server.close()

    describe 'when an invalid URL is specified', ->
      it 'logs an error and exits', ->
        callback = jasmine.createSpy('callback')
        apm.run(['install', "not-a-module"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
          expect(callback.mostRecentCall.args[0]).not.toBeUndefined()

    describe 'when a package name is specified', ->
      it 'installs the package', ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        fs.makeTreeSync(testModuleDirectory)
        existingTestModuleFile = path.join(testModuleDirectory, 'will-be-deleted.js')
        fs.writeFileSync(existingTestModuleFile, '')
        expect(fs.existsSync(existingTestModuleFile)).toBeTruthy()

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(existingTestModuleFile)).toBeFalsy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(callback.mostRecentCall.args[0]).toBeNull()

    describe 'when multiple package names are specified', ->
      it 'installs all packages', ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        testModule2Directory = path.join(atomHome, 'packages', 'test-module2')

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module", "test-module2", "test-module"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'index2.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'package.json'))).toBeTruthy()
          expect(callback.mostRecentCall.args[0]).toBeNull()

      it "installs them in order and stops on the first failure", ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        testModule2Directory = path.join(atomHome, 'packages', 'test-module2')

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module", "test-module-bad", "test-module2"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'index2.js'))).toBeFalsy()
          expect(fs.existsSync(path.join(testModule2Directory, 'package.json'))).toBeFalsy()
          expect(callback.mostRecentCall.args[0]).not.toBeUndefined()

    describe 'when no path is specified', ->
      it 'installs all dependent modules', ->
        moduleDirectory = path.join(temp.mkdirSync('apm-test-module-'), 'test-module-with-dependencies')
        wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module-with-dependencies'), moduleDirectory)
        process.chdir(moduleDirectory)
        callback = jasmine.createSpy('callback')
        apm.run(['install'], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(path.join(moduleDirectory, 'node_modules', 'test-module', 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(moduleDirectory, 'node_modules', 'test-module', 'package.json'))).toBeTruthy()
          expect(callback.mostRecentCall.args[0]).toBeUndefined()

    describe "when the packages directory does not exist", ->
      it "creates the packages directory and any intermediate directories that do not exist", ->
        atomHome = temp.path('apm-home-dir-')
        process.env.ATOM_HOME = atomHome
        expect(fs.existsSync(atomHome)).toBe false

        callback = jasmine.createSpy('callback')
        apm.run(['install', 'test-module'], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(atomHome)).toBe true

    describe "when the package contains symlinks", ->
      it "copies them correctly from the temp directory", ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module-with-symlink')

        callback = jasmine.createSpy('callback')
        apm.run(['install', "test-module-with-symlink"], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.isFileSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()

          if process.platform is 'win32'
            expect(fs.isFileSync(path.join(testModuleDirectory, 'node_modules', '.bin', 'abin'))).toBeTruthy()
          else
            expect(fs.realpathSync(path.join(testModuleDirectory, 'node_modules', '.bin', 'abin'))).toBe fs.realpathSync(path.join(testModuleDirectory, 'node_modules', 'test-module-with-bin', 'bin', 'abin.js'))

    describe 'when a packages file is specified', ->
      it 'installs all the packages listed in the file', ->
        testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
        testModule2Directory = path.join(atomHome, 'packages', 'test-module2')
        packagesFilePath = path.join(__dirname, 'fixtures', 'packages.txt')

        callback = jasmine.createSpy('callback')
        apm.run(['install', '--packages-file', packagesFilePath], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'index2.js'))).toBeTruthy()
          expect(fs.existsSync(path.join(testModule2Directory, 'package.json'))).toBeTruthy()
          expect(callback.mostRecentCall.args[0]).toBeNull()

      it 'calls back with an error when the file does not exist', ->
        badFilePath = path.join(__dirname, 'fixtures', 'not-packages.txt')

        callback = jasmine.createSpy('callback')
        apm.run(['install', '--packages-file', badFilePath], callback)

        waitsFor 'waiting for install to complete', 600000, ->
          callback.callCount is 1

        runs ->
          expect(callback.mostRecentCall.args[0]).not.toBeNull()
