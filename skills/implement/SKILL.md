---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
version: 1.0.0
license: LICENSE
metadata:
  upstream: mattpocock/skills
  upstream-sha: 3cca18b368ae95cdbdebbff572ccafa662551015
  vendored: unedited
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work.

Commit your work to the current branch.
