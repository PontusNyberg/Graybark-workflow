# Rules: Testing

Applies when test files are created or modified.

## Test principles

- Tests prove the code works — they are not a checkbox exercise
- Test behavior, not implementation details
- One logical assertion per test (multiple `expect` calls is fine if they test the same behavior)
- Tests must be deterministic — no flaky tests

## Test naming

- Describe WHAT is being tested and WHAT the expected outcome is
- Pattern: `it("should <expected behavior> when <condition>")`
- Group related tests with `describe("<unit under test>")`

## Test structure

- **Arrange** — set up test data and preconditions
- **Act** — execute the code under test
- **Assert** — verify the result

## What to test

- Happy path (normal operation)
- Edge cases (empty input, boundary values, null)
- Error cases (invalid input, network failure, auth failure)
- Business rules (the specific logic that makes this feature work)

## What NOT to test

- Framework internals (React renders correctly, Express routes work)
- Third-party libraries (they have their own tests)
- Implementation details (internal state, private methods)
- Trivial code (getters/setters with no logic)

## Mocking

- Mock external dependencies (APIs, databases, file system)
- Don't mock the code under test
- Prefer integration tests over heavily mocked unit tests when feasible
- Reset mocks between tests

## Test file placement

TODO: Define where test files should live in your project:
- Co-located with source? (`Component.test.tsx` next to `Component.tsx`)
- Separate directory? (`__tests__/`)
- Both? (different rules for different parts)
