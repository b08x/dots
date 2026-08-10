# Optimization Catalog

Before/after shapes for the PBO cycle's Step 3, ordered by typical payoff. Distilled from *Polished Ruby Programming* ch1/ch3/ch14.

## 1. Algorithm: linear scan → hash lookup

```ruby
# Before — O(n) per lookup, O(n*m) total
valid = codes.select { |c| allowed_list.include?(c) }

# After — O(1) per lookup
allowed = allowed_list.to_set   # or a Hash built once
valid = codes.select { |c| allowed.include?(c) }
```

## 2. Pre-calculation (idempotent results)

```ruby
# Before — recomputed every call
def full_name = "#{first} #{last}"

# After — computed once at construction
def initialize(first:, last:)
  @first, @last = first, last
  @full_name = "#{first} #{last}"
end
attr_reader :full_name
```

## 3. Lazy initialization (may never be needed)

```ruby
def connection = @connection ||= Sequel.connect(url)
```

Use for expensive objects with uncertain use. Note `||=` is wrong for legitimately-false/nil values — use `defined?` guard there.

## 4. Performance hoisting (tight loops)

Locals are stack-indexed; ivars, constants, and method calls are lookups. Hoist before the loop:

```ruby
# Before
def process(rows)
  rows.each { |r| r[:total] = r[:amount] * @tax_rate * FACTOR }
end

# After
def process(rows)
  tax_rate = @tax_rate
  factor = FACTOR
  rows.each { |r| r[:total] = r[:amount] * tax_rate * factor }
end
```

Same for `attr_reader`s called inside loops: `s = size` once, not `size` per iteration.

## 5. String allocation

```ruby
# Before — each + allocates a new string
result = ""
items.each { |i| result = result + i.to_s + "\n" }

# After — << mutates one buffer
result = +""                       # unfrozen literal
items.each { |i| result << i.to_s << "\n" }

# Constants: freeze to dedupe
SEPARATOR = ", "                   # add # frozen_string_literal: true; freeze explicit non-literals
```

## 6. Intermediate collection elimination

```ruby
# Before — three intermediate arrays
total = rows.map { |r| r[:amount] }.select(&:positive?).sum

# After — single pass, no intermediates
total = rows.sum { |r| a = r[:amount]; a.positive? ? a : 0 }

# Long chains over large/streaming input: .lazy
first_ten = huge_enum.lazy.map { transform(it) }.select { valid?(it) }.first(10)
```

## 7. each_with_object over inject-with-dup

```ruby
# Before
index = rows.inject({}) { |h, r| h.merge(r[:id] => r) }   # allocates a hash per row

# After
index = rows.each_with_object({}) { |r, h| h[r[:id]] = r }
```

## 8. Object pools / buffer reuse

For hot paths allocating identical short-lived objects (parsers, buffers), keep and reset one instance instead of constructing per call. Only after `mode: :object` profiling shows the allocation matters — pools complicate ownership.

## 9. Backtraceless exceptions

See refactor catalog `hot_loop_exception_backtrace`. Applies only when profiling shows raise cost; otherwise keep backtraces — they're worth their price everywhere else.

## 10. Memoization discipline

Memoize pure, hot, repeated computations (`@x ||=`). Do not memoize: anything time/state-dependent, anything cheap (hash lookup cost ≈ the computation), or in objects with long lifetimes holding big results (memory leak by memo).

## Measurement quickrefs

```ruby
# Allocation profile
require "memory_profiler"
report = MemoryProfiler.report { workload }
report.pretty_print(scale_bytes: true)

# GC stats delta
before = GC.stat(:total_allocated_objects)
workload
puts GC.stat(:total_allocated_objects) - before
```
