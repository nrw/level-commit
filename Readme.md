# level-commit [![build status](https://secure.travis-ci.org/nrw/level-commit.png)](http://travis-ci.org/nrw/level-commit)

Track the change history of a leveldb instance.

[![testling badge](https://ci.testling.com/nrw/level-commit.png)](https://ci.testling.com/nrw/level-commit)

## Example

``` js
var level = require('level-test')()
var concat = require('concat-stream')
var db = level('db1', {valueEncoding: 'json'})
var committer = require('level-commit')(db)

committer.commit({a: 1}, {user: 'sam'}, function(err){
  if (err) return
  // success!
})

// later
committer.history(function (err, history) {
  if (err) return
  // commits are tracked in the history
  // history = [
  //   {
  //     patch: {a: 1},
  //     user: 'sam',
  //     ts: '1914-05-16T05:44:36.155Z' // when the commit was added
  //   }
  // ]
})

db.readStream({start: 'a', end: 'a'}).pipe(concat(function(body){
  // commits alter the database contents
  // body = [
  //   {key: 'a', value: 1}
  // ]
}))

```

## Methods

### var committer = commit(db, opts={})

`db` is a `levelup` instance.

#### options

- `opts.depth = 0` the depth of key that should be used as a prefix for each property.
  This is passed to [`level-objectify`](https://www.npmjs.org/package/level-objectify)
- `opts.separator = '\xff'` the string to use to separate sections of the prefix.
- `opts.timestamp = 'ts'` the key to store the timestamp on.
- `opts.prefix = 'commit' + opts.separator` the string to prefix the commit document's key with.
    ``` js
    // To store commits in a sublevel, prefix with:
    opts.prefix = '\xffpath\xff\xffto\xff\xffsublevel\xffcommit\xff'
    ```


### committer.current( fn(err, obj) )

The callback function will be passed any error and an object that is the result
of combining the patches of all commits in order with `.applyPatch()` from
[`patcher`](https://www.npmjs.org/package/patcher).

### committer.commit( patch={}, meta={}, fn(err) )

**patch**  
The patch to commit. Create one with `.computePatch()` from [`patcher`](https://www.npmjs.org/package/patcher).

**meta**  
Key-value pairs to include with the commit. Use any valid object key except `patch` and `opts.timestamp`, which will
be overwritten by the patch provided in the first argument and the provided setting respectively.

**fn(err)**  
A callback function for when the commit is complete. All writes are completed
in a single batch operation in leveldb. A failure here means the commit and all
side-effects failed.

### committer.history( fn(err, history) )

The callback function will receive any error and the commit history for this
instance in the order it was committed (oldest first).

### committer.batch( fn(meta, batch, callback(err, batch)) )

Pass a function that will receive the `meta` information about a commit and the
`batch` of operations that are about to occur as well as a callback to invoke
with any error and the batch of operations to trigger.

``` js
// this batch function splits documents into sublevels
var committer = require('level-commit')(db, {depth: 1})

// note: you must augment your db with `level-sublevel` for this to work!
committer.batch(function(meta, batch, cb){
  admin = db.sublevel(meta.ship).sublevel('pegasus.admin')
  open = db.sublevel(meta.ship).sublevel('pegasus.public')

  batch.forEach(function (op) {
    op.prefix = op.key.slice(0,1) === 'u' ? admin : open
  })

  cb(null, batch)
})

data = {
  user: {
    lee: {name: 'Lee Adama'}
  }
  gear: {
    viper1: {serial: 15513}
  }
}

committer.commit(data, {user: 'sam', ship: 'battlestar'}, function (err) {
  if (err) return

  // db.sublevel('battlestar').sublevel('pegasis.admin') now contains:
  // [{key: 'user\xfflee', value: {name: 'Lee Adama'}}]

  // db.sublevel('battlestar').sublevel('pegasis.public') now contains:
  // [{key: 'gear\xffviper1', value: {serial: 15513}}]
})
```

## License

MIT
