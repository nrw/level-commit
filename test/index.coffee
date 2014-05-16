test = require 'tape'
sublevel = require 'level-sublevel'
concat = require 'concat-stream'
level = require('level-test')()

commit = require '../'

DB = (n) -> level 'level-commit'+n, valueEncoding: 'json'

db = DB(0)
committer = commit db

data1 =
  user:
    lee: {name: 'Lee Adama', passcode: '346'}
    kara: {name: 'Kara Thrace', passcode: '123'}
  gear:
    viper1: {serial: 144450}
    viper2: {serial: 342411}

test 'base state', (t) ->
  committer.current (err, prev) ->
    t.notOk err
    t.same prev, {}
    t.end()

test 'basic commit', (t) ->
  committer.commit {a: 1}, {user: 'sam'}, (err) ->
    t.notOk err
    t.end()

test 'reads commit', (t) ->
  committer.current (err, prev) ->
    t.notOk err
    t.same prev, {a: 1}
    t.end()

test 'another commit', (t) ->
  committer.commit {b: 1, $r: 'a'}, {user: 'kara'}, (err) ->
    t.notOk err
    t.end()

test 'reads current', (t) ->
  committer.current (err, prev) ->
    t.notOk err
    t.same prev, {b: 1}
    t.end()

test 'another commit', (t) ->
  committer.commit {c: 1, d: {e: f: 'g'}}, {user: 'kara'}, (err) ->
    t.notOk err
    t.end()

test 'reads current', (t) ->
  committer.current (err, prev) ->
    t.notOk err
    t.same prev, {b: 1, c: 1, d: {e: f: 'g'}}
    t.end()

test 'reads history', (t) ->
  committer.history (err, history) ->
    t.notOk err
    t.same history[0].patch, {a:1}
    t.same history[0].user, 'sam'
    t.same history[1].patch, {b: 1, $r: 'a'}
    t.same history[1].user, 'kara'
    t.same history[2].patch, {c: 1, d: {e: f: 'g'}}
    t.same history[2].user, 'kara'
    t.end()

# reset db
test 'commits in sublevel', (t) ->
  db = sublevel DB(2)
  committer = commit db, prefix: '\xffbattlestar\xff\xffgalactica\xffcommit'

  committer.current (err, prev) ->
    t.notOk err
    t.same prev, {}
    t.end()

test 'commits in sublevel', (t) ->
  committer.commit {a: 1}, {user: 'sam'}, (err) ->
    t.notOk err
    t.end()

test 'reads commit', (t) ->
  committer.current (err, prev) ->
    t.notOk err
    t.same prev, {a: 1}
    t.end()

test 'access commit in sublevel', (t) ->
  db.sublevel('battlestar')
    .sublevel('galactica')
    .readStream().pipe concat (body) ->
      t.equal body[0].value.user, 'sam'
      t.same body[0].value.patch, {a: 1}
      t.equal body.length, 1
      t.end()

test 'custom batch modification', (t) ->
  db = sublevel DB(3)
  committer = commit db,
    prefix: '\xffbattlestar\xff\xffpegasus.admin\xffcommit', depth: 1

  committer.batch (meta, batch, cb) ->
    admin = db.sublevel(meta.ship).sublevel('pegasus.admin')
    open = db.sublevel(meta.ship).sublevel('pegasus.public')

    for op in batch
      op.prefix = switch op.key.slice(0,1)
        when 'u' then admin
        else open

    cb null, batch

  committer.commit data1, {user: 'sam', ship: 'battlestar'}, (err) ->
    t.notOk err
    t.end()

test 'split docs', (t) ->
  t.plan 9

  db.sublevel('battlestar')
    .sublevel('pegasus.admin')
    .readStream().pipe concat (body) ->

      t.equal body.length, 3
      t.same body[0].value.patch, data1
      t.equal body[1].key, 'user\xffkara'
      t.equal body[1].value.name, 'Kara Thrace'
      t.equal body[2].value.name, 'Lee Adama'

  db.sublevel('battlestar')
    .sublevel('pegasus.public')
    .readStream().pipe concat (body) ->
      t.equal body[0].key, 'gear\xffviper1'
      t.equal body[0].value.serial, 144450
      t.equal body[1].value.serial, 342411
      t.equal body.length, 2
