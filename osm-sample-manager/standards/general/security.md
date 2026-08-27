# Standard: security

Each rule below can fail a review. A rule that cannot fail a review is not a
standard.

## Secrets

1. No credential, key, token or password appears in a tracked file. Not in code,
   not in a test fixture, not in a comment, not in a commit message.
2. Credentials are read from the environment with **no default value**. A
   missing required variable aborts and names itself.
3. A credential is never passed as a command-line argument, because arguments
   are visible in the process table. Use the environment.
4. A credential is never logged, at any level, including in an exception
   message or a debug dump of a request.
5. `.env.example` documents variable *names* with empty values. `.env` is
   ignored.

## Authorisation

6. Every route declares the permission it requires. A route without one fails
   review.
7. Authorisation is evaluated in exactly one place. A second implementation for
   a different transport is a defect (ADR-0006).
8. Every new domain table has a row-level security policy. A schema test fails
   when one is missing.
9. A missing session variable denies access. It never defaults to permitting.
10. Machine credentials are scoped no broader than the work requires. The LabKey
    bridge uses an `EditorWithoutDelete`-restricted API key.

## Input

11. Every request body is validated at the boundary against a declared schema.
12. Filter expressions are parsed into a typed structure. String concatenation
    into SQL — LabKey SQL included — fails review.
13. File uploads have a bounded size and row count, a validated content type,
    and per-row error reporting.
14. Exported cells beginning with `=`, `+`, `-` or `@` are neutralised so that a
    spreadsheet cannot execute imported content.
15. Scanned barcode input is length-bounded and character-validated before use.

## Disclosure

16. An error never leaks a stack trace, a SQL fragment or a file path to a
    client.
17. A lookup failure returns the same response whether the identifier does not
    exist or exists outside the caller's scope.
18. A conflict response names the conflicting resource only to a caller
    permitted to see it.

## Agents

19. An operation that must never be agent-reachable is **not exposed as a tool**.
    Refusing at call time is a weaker guarantee than not existing, and a test
    asserts the absence so a later change cannot quietly add it.
20. A destructive tool requires an explicit confirmation argument and an
    administrative scope.
21. The tool allowlist is bound to the session at authentication time, never
    derived from content the agent reads.
22. The retrieval corpus is restricted at index time, not filtered at query time.
