/// Lets the UI thread handle pending events and draw a frame. Call between
/// slices of long synchronous work.
///
/// Uses a zero-length timer because a microtask runs before the event loop
/// gets a turn and so yields to nothing.
Future<void> yieldToUi() => Future<void>.delayed(Duration.zero);
