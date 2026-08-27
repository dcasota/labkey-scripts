# Standard: testing

## Rules

1. Tests accompany the code in the same pull request. A follow-up test commit is
   not acceptable.
2. **Test the denials.** A role test that proves access works has tested half
   the requirement. Prove that the wrong role is refused.
3. Concurrency requirements get concurrency tests. The slot exclusion
   constraint, the audit chain and optimistic task locking each need parallel
   writers, not a comment claiming safety.
4. Performance requirements get benchmarks that **fail the build** when the
   target is missed. An unenforced target is a wish.
5. Idempotency requirements get a test that runs the operation twice and asserts
   the second run changed nothing.
6. Exactness requirements get a test that accumulates. A thousand successive
   aliquot splits must leave the amount exact.
7. Tests that touch the network or the LabKey server are marked so they can be
   deselected, and the unit suite passes without either.
8. A test that creates something in LabKey cleans up after itself and never
   touches `SleepDrive-Lab`.
9. Coverage has a configured floor and the build fails below it.

## What does not count

- Asserting that a mock was called.
- A test whose assertion would still pass if the implementation were deleted.
- Snapshot tests over output nobody reads.
