/// Lets the UI thread draw a frame before the caller carries on.
///
/// A long piece of synchronous work — mapping a few hundred TDLib messages
/// into posts, say — holds the main isolate for as long as it runs, and every
/// tap and every frame waits behind it. Splitting the work into slices and
/// calling this between them lets pending events and the next vsync through.
///
/// A zero-length timer rather than a microtask, deliberately: microtasks run
/// before the event loop gets a turn, so `await Future.microtask` yields to
/// nothing. A timer goes to the back of the event queue, behind the frame
/// callback that is waiting there.
Future<void> yieldToUi() => Future<void>.delayed(Duration.zero);
