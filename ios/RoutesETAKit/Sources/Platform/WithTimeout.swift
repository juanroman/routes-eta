/// The result of `operation`, or nil if it produced none within `timeout` (the operation is then
/// cancelled). An operation that finishes with nil early also yields nil early.
func withTimeout<T: Sendable>(
  _ timeout: Duration, _ operation: @escaping @Sendable () async -> T?
) async -> T? {
  await withTaskGroup(of: T?.self) { group in
    group.addTask { await operation() }
    group.addTask {
      try? await Task.sleep(for: timeout)
      return nil
    }
    // `next()` is optional because the group could be empty; the value itself is optional too.
    let first = await group.next() ?? nil
    group.cancelAll()
    return first
  }
}
