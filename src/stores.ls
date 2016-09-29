require! {
  fs
  readline
  child_process
  request
  \stats-lite
  './container-manager.ls': con-man
}

const server-port = process.env.PORT or 8080

start-time = 0

run-test = do ->
  out = fs.create-write-stream 'data/stores.csv'
    ..write 'stores,name,timestamp,entries\n'

  store-count = 0

  (store-count-max) ->
    resolve, reject <-! new Promise!
    if store-count >= store-count-max
      resolve!
      return

    launch-store = "mongo-#store-count"
      |> -> con-man.launch-container \mongo:latest it

    launch-store
      .then (info) !->
        console.log info
        <-! set-timeout _, 2000
        # Persistent
        child_process.fork \src/write.ls [] env: PORT: info.port
          ..on \message !->
            out.write "#{store-count + 1},#{info.name},#{new Date! - start-time},#it\n"
      .then ->
        ++store-count
        run-test store-count-max
      .then resolve
      .catch reject

console.log 'Establishing communication with Docker daemon'
con-man.connect!
  .then ->
    # Kill any already running Databox containers
    console.log 'Killing any already running Databox containers'
    con-man.kill-all!
  .then ->
    # Create networks if they do not already exist
    console.log 'Checking driver and app networks'
    con-man.init-networks!
  .then ->
    # Launch Arbiter
    console.log 'Launching Arbiter container'
    con-man.launch-arbiter!
  .then (result) ->
    # TODO: Reject and catch
    throw new Error result.err if result.err?
    start-time := new Date!
    run-test 100
  .then ->
    console.log 'Done'
  .catch !-> console.log it