objectify = require 'level-objectify'
patcher = require 'patcher'
through = require 'through2'
reduce = require 'through2-reduce'
concat = require 'concat-stream'
cloneDeep = require 'lodash.clonedeep'

gid = require('gen-id')('XXXX')

module.exports = (db, opts = {}) ->
  opts.separator or= '\xff'
  opts.prefix or= 'commit' + opts.separator
  opts.timestamp or= 'ts'
  opts.depth or= 0

  opts.batch or= (doc, batch, cb) -> cb null, batch

  objectifier = objectify({depth: opts.depth})

  historyStream = ->
    start = opts.prefix
    end = start + opts.separator
    db.valueStream({start, end})

  current = (cb) ->
    write = (chunk, enc, cb) -> @push chunk.patch; cb()
    iter = (acc, h) -> patcher.applyPatch acc, h; acc

    stream = historyStream()
    stream.on 'error', cb

    stream
      .pipe(through.obj(write))
      .pipe reduce({objectMode: yes}, iter, {})
      .pipe concat (body) -> cb null, body[0]

  commit = (patch, meta, cb) ->
    value = {}
    value[k] = v for k, v of meta
    value.patch = patch
    value[opts.timestamp] = new Date().toISOString()

    key = opts.prefix + value[opts.timestamp]+'-'+gid.generate()

    doc = {key, value, type: 'put'}

    current (err, prev) ->
      return cb err if err
      next = cloneDeep(prev)
      patcher.applyPatch next, patch

      operations = objectifier.computeBatch prev, next

      opts.batch doc.value, operations, (err, ops) ->
        return cb err if err
        ops.push doc
        db.batch ops, cb

  batch = (fn) -> opts.batch = fn

  history = (cb) ->
    stream = historyStream()
    stream.on 'error', cb
    stream.pipe concat (body) -> cb null, body

  {current, commit, batch, history, historyStream}
