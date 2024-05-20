import gleam/dynamic
import gleam/erlang
import gleam/erlang/process
import gleam/list
import processgroups as pg

/// A pubsub, where process can subscribe and anyone can broadcast
pub type PubSub(message) {
  PubSub(tag: erlang.Reference)
}

/// A Subscription is crated by subscribing to a PubSub
/// and can be used to receive broadcast messages on the
/// owning thread.
pub type Subscription(message) {
  Subscription(pubsub: PubSub(message), owner: process.Pid)
}

/// Create a new pubsub
pub fn new_pubsub() -> PubSub(message) {
  PubSub(erlang.make_reference())
}

/// Subscribe a process to a PubSub.
pub fn subscribe(
  pubsub: PubSub(message),
  pid: process.Pid,
) -> Subscription(message) {
  pg.join(pubsub.tag, pid)
  Subscription(pubsub, pid)
}

/// Receive a message on a subscription.
/// has to be done on the process owning the Subscription,
/// which is passed to subscribe
pub fn receive(
  from subject: Subscription(message),
  within milliseconds: Int,
) -> Result(message, Nil) {
  process.new_selector()
  |> selecting_pubsub_subject(subject, fn(x) { x })
  |> process.select(within: milliseconds)
}

/// Unsubsribe a process from a PubSub.
pub fn unsubscribe(subscription: Subscription(message), pid: process.Pid) {
  pg.leave(subscription.pubsub.tag, pid)
}

type DoNotLeak

@external(erlang, "erlang", "send")
fn raw_send(a: process.Pid, b: message) -> DoNotLeak

/// Send a message to all processes, subscribed to the PubSub
pub fn broadcast(pubsub: PubSub(message), msg: message) {
  list.each(pg.get_members(pubsub.tag), fn(pid) {
    raw_send(pid, #(pubsub.tag, msg))
  })
}

/// Create a Selector for receiving PubSub messages.
pub fn selecting_pubsub_subject(
  selector: process.Selector(payload),
  subject: Subscription(message),
  handler: fn(message) -> payload,
) -> process.Selector(payload) {
  process.selecting_record2(selector, subject.pubsub.tag, fn(d) {
    d
    |> dynamic.unsafe_coerce
    |> handler
  })
}

/// Monitor a PubSub. A `pg.GorupMonitor` event will be 
/// send, when a process subscribes or unsubscribes.
pub fn monitor(
  pubsub: PubSub(message),
) -> #(pg.GroupMonitor(erlang.Reference), List(process.Pid)) {
  pg.monitor(pubsub.tag)
}

/// Stop monitoring a PubSub.
pub fn demonitor(pubsub: PubSub(message)) -> Bool {
  pg.demonitor(pubsub.tag)
}
