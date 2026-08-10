# Object-Oriented Design Principles

Distilled from *Practical Object-Oriented Design in Ruby* (Sandi Metz). Used by `sift` (as Toulmin warrants for Structure/Idioms findings), `analyse` (naming design smells), and `refactor` (the OO pattern family). If the standalone `metz-poodr` skill is installed, load its chapters for depth; this file is the working summary.

## The TRUE Qualities (top-level warrant for any structure finding)

Code should be **Transparent** (consequences of change are obvious), **Reasonable** (cost of change is proportional to value), **Usable** (reusable in new contexts), **Exemplary** (encourages quality in code built on it). A structure finding should name which quality is violated.

## Single Responsibility

A class should do the smallest possible useful thing — one reason to change. Litmus test: describe the class's job without "and"/"or". Extract extra responsibilities; wrap bare data in methods; use `Data.define` for immutable value objects.

## The Dependency Checklist

An object is coupled to another when it knows any of:

1. The **name** of another class
2. The **name** of a message it sends to someone other than self
3. The **arguments** a message requires
4. The **order** of those arguments

Each known item is a place the object must change when the other changes. Remedies in order: inject the dependency (keyword args), isolate class references in a factory method, isolate message sends in a wrapper method, use kwargs to kill argument-order knowledge.

**Dependency direction rule**: depend on things that change *less* often than you do — abstractions over concretions.

## Law of Demeter

Only talk to immediate neighbors; no train wrecks (`customer.bicycle.wheel.rotate`). Ask for *what* you want, don't script *how* to get it. A chain of sends to the same object type (`hash.keys.sort.join`) is fine — Demeter is about reaching across objects.

## Duck Typing

Objects are their public interfaces, not their classes. When a `case obj.class` / `respond_to?` / `is_a?` chain switches on type to send different messages, there's a hidden duck: define one message all players implement, and let polymorphism replace the conditional. Pattern matching on `deconstruct_keys` (Data/Struct) is the Ruby-4 safe destructuring form.

## Choosing Relationships

| Relationship | Use when | Signal it's wrong |
|--------------|----------|-------------------|
| Inheritance (is-a) | Stable hierarchy, specialization of a common abstraction | Subclass overrides to *remove* behavior; `super` calls scattered in subclasses |
| Module (behaves-like-a) | A role shared by unrelated objects | Module needs to know its includers' internals |
| Composition (has-a) | Whole is more than sum of parts — the default bias | Explosion of tiny objects with no clear roles |

Inheritance mechanics: superclass owns the algorithm (Template Method), subclasses fill in via **hook methods** (`post_initialize`, defaulted no-op) rather than being forced to call `super`.

## Interface Design

Public methods are small, stable, about *what* not *how*. Default methods to `private`; promotion to public is a backward-compatibility commitment (this is also orchestrator Mandate 5). Design interfaces around the messages the *sender* needs, not what the receiver happens to have.

## The Testing Grid (cite when auditing tests)

| Message type | What to test | Strategy |
|--------------|-------------|----------|
| Incoming | Result/state | Assert on return value or resulting state |
| Outgoing query | Nothing | Tested in the receiver; ignore here |
| Outgoing command | That it was sent | Mock/expectation |

Plus: **role tests** — a shared test module included by every player of a duck type, so doubles can't lie about the interface.

## Ruby 4 Applications

`Data.define` over `Struct` for immutable values; keyword args for all injected dependencies; `it` parameter for one-line blocks; no `OpenStruct`; pattern matching to destructure Data/Struct.
