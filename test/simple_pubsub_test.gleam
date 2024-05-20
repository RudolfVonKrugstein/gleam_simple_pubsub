import gleam/erlang/process
import gleam/iterator
import gleam/list
import gleam/otp/task
import gleeunit
import gleeunit/should
import processgroups as pg
import simple_pubsub as ps

pub fn main() {
  let _ = pg.start_link()
  gleeunit.main()
}

pub type PubSubMessage {
  PubSubMessage
}

pub fn send_receive_test() {
  // setup
  let pubsub = ps.new_pubsub()
  let ps_subject = ps.subscribe(pubsub, process.self())

  // act
  ps.broadcast(pubsub, PubSubMessage)
  let recv_msg = ps.receive(ps_subject, 100)

  // test
  should.equal(recv_msg, Ok(PubSubMessage))
}

pub fn send_receive_multiple_test() {
  // setup
  let pubsub = ps.new_pubsub()
  let #(monitor, _) = ps.monitor(pubsub)
  let tasks =
    iterator.range(1, 10)
    |> iterator.map(fn(_) {
      // start the task
      let task =
        task.async(fn() {
          ps.subscribe(pubsub, process.self())
          |> ps.receive(100)
        })
      // wait for it to register
      let _ =
        pg.selecting_process_group_monitor(
          process.new_selector(),
          monitor,
          fn(a) { a.pids },
        )
        |> process.select(100)
      // return the task
      task
    })
    |> iterator.to_list

  // act
  ps.broadcast(pubsub, PubSubMessage)
  let res =
    tasks
    |> list.map(fn(t) {
      let assert Ok(msg) = task.await(t, 100)
      msg
    })

  // test
  should.equal(
    res,
    iterator.range(1, 10)
      |> iterator.map(fn(_) { PubSubMessage })
      |> iterator.to_list,
  )
}
