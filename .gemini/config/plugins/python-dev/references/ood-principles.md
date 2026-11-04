# Object-Oriented Design Principles

Distilled from *Practical Object-Oriented Design* (Sandi Metz), adapted for Python. Used by `sift` (as Toulmin warrants for Structure and Idioms findings), `analyse` (naming design smells), and `refactor` (the OO pattern family). If the standalone `metz-poodr` skill is installed, load its chapters for depth. This file is the working summary.

## The TRUE qualities (top-level warrant for any structure finding)

Code should be **Transparent** (consequences of change are obvious), **Reasonable** (cost of change is proportional to value), **Usable** (reusable in new contexts), and **Exemplary** (encourages quality in code built on it). A structure finding names the quality it violates.

## Single responsibility

A class does the smallest useful thing and has one reason to change. Litmus test: describe the class's job without "and" or "or". Extract extra responsibilities. Wrap bare data in behavior. Use `@dataclass(frozen=True, slots=True)` for immutable value objects.

## The dependency checklist

An object is coupled to another when it knows any of:

1. The **name** of another class.
2. The **name** of a message (method) it sends to someone other than itself.
3. The **arguments** a message requires.
4. The **order** of those arguments.

Each known item is a place the object must change when the other changes. Remedies, in order: inject the dependency through the constructor, isolate class references in a factory function, isolate message sends in a wrapper method, and use keyword arguments to remove argument-order knowledge.

**Dependency direction rule:** depend on things that change less often than you do. Depend on `Protocol`s, not concrete classes.

## Law of Demeter

Talk only to immediate neighbors. Avoid train wrecks (`customer.bicycle.wheel.rotate()`). Ask for what you want; do not script how to get it. A chain of calls on the same type (`sorted(d.keys())`) is fine. Demeter concerns reaching across objects.

## Duck typing

Objects are their public interfaces, not their classes. When an `isinstance` or `type(x)` chain selects different behavior, a hidden duck exists. Define one method all participants implement and let polymorphism replace the conditional. `match` on dataclasses and pydantic models is the safe structural form when the set of shapes is closed.

## Choosing relationships

| Relationship | Use when | Signal it is wrong |
|---|---|---|
| Inheritance (is-a) | Stable hierarchy and specialization of a shared abstraction | Subclass overrides to remove behavior; `super()` calls scattered across subclasses |
| Protocol (role-like-a) | A role shared by unrelated classes | The protocol must know its implementers' internals |
| Composition (has-a) | The whole is more than the sum of its parts. The default bias | An explosion of tiny objects with no clear roles |

Inheritance mechanics: the superclass owns the algorithm (Template Method). Subclasses fill it in through hook methods with no-op defaults, so no subclass is forced to call `super()`.

## Interface design

Public methods are small, stable, and describe what, not how. Default to private. Promotion to public is a backward-compatibility commitment (see Mandate 5). Design interfaces around the messages the sender needs, not what the receiver happens to expose.

## The testing grid (cite when auditing tests)

| Message type | What to test | Strategy |
|---|---|---|
| Incoming | Result or state | Assert on the return value or the resulting state |
| Outgoing query | Nothing | Tested in the receiver. Ignore here. |
| Outgoing command | That it was sent | Fake or mock at the Protocol boundary |

Also use **contract tests**: one parametrized test module that every implementer of a Protocol must pass. A fake cannot drift from the real interface because both run the same contract.

## Python 3.12+ applications

- `@dataclass(frozen=True, slots=True, kw_only=True)` for value objects and injected settings.
- `Protocol` plus keyword-only constructor arguments for every injected dependency.
- `ParamSpec` for forwarding wrappers. Do not re-declare parameters in delegation.
- `match` for destructuring dataclasses and pydantic models.
- No `dict` as a domain object. Use a typed model at every boundary.
