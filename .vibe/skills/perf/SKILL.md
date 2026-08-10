---
name: perf
description: "Use when Ruby code is slow, allocating too much, or needs optimization - profiling with stackprof, benchmarking with benchmark-ips, reducing allocations, and hoisting lookups. Trigger on 'slow', 'performance', 'optimize', 'profile', 'benchmark', 'memory bloat', or GC pressure in a Ruby context."
user-invocable: true
---

# RubyDev Perf — Profile-Benchmark-Optimize

## Overview

Optimization is a reactive, evidence-based discipline (methodology from *Polished Ruby Programming*, Jeremy Evans, ch3/ch14 — load the `evans-polished-ruby` skill for depth if installed). Guessing at hotspots wastes effort and complicates code for nothing; the PBO cycle replaces guessing with measurement.

**Core Mandate**: Never optimize without a profile. Never keep an optimization without a benchmark delta. The fastest code is the code you successfully delete.

**Reference**: Optimization technique catalog with before/after shapes: [~/.vibe/skills/perf/references/optimization-catalog.md](~/.vibe/skills/perf/~/.vibe/skills/perf/references/optimization-catalog.md))

## When to Use

- "This is slow" / "takes too long" / "uses too much memory"
- Hot paths identified by [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md) (the debugger diagnoses *what* is slow; this skill makes it fast)
- Library code expected to be called at scale
- GC pressure, allocation churn, N+1-style repeated work

**Don't use for:**
- Code that hasn't been measured as slow (premature optimization)
- Algorithmic redesign that changes behavior (diagnose with analyse first)
- Database query tuning beyond Ruby-side batching (that's schema/index work)

## Required Gems

| Gem | Purpose | Context7 ID |
|-----|---------|-------------|
| `stackprof` | Sampling profiler (low overhead, production-safe) | verify at point of use |
| `benchmark-ips` | Iterations-per-second benchmarking with stddev | verify at point of use |
| `memory_profiler` | Allocation tracking by gem/file/line | verify at point of use |

## The PBO Cycle

### Step 1: Profile — find the hotspot

```ruby
require "stackprof"

StackProf.run(mode: :wall, out: "tmp/stackprof.dump", interval: 1000) do
  workload
end
# stackprof tmp/stackprof.dump --text     # top frames
# stackprof tmp/stackprof.dump --method 'Klass#slow_method'
```

Sampling (not tracing) — low overhead, no observer effect. Profile a production-like workload; toy inputs produce toy hotspots. For allocation hotspots use `mode: :object`, or `memory_profiler` for who-allocates-what.

### Step 2: Benchmark — establish the baseline

Isolate the hotspot into a minimal script with `benchmark-ips`:

```ruby
require "benchmark/ips"

Benchmark.ips do |x|
  x.report("current") { current_implementation }
  x.report("candidate") { candidate_implementation }
  x.compare!
end
```

Commit this script (e.g. `bench/`) — it's the regression test for the optimization.

### Step 3: Optimize — simplest change first

Priority order (details and before/after shapes in the catalog):

1. **Algorithm**: O(n) lookups → Hash/Set membership. Biggest wins live here.
2. **Do less work**: pre-calculate idempotent results in `initialize`; lazy-init expensive objects (`@x ||=`); early-return before expensive branches.
3. **Allocate less**: string `<<` over `+`, `freeze` constants, avoid intermediate arrays (`each_with_object`, `sum`, `lazy` for chains), reuse buffers.
4. **Hoist lookups**: in tight loops, copy instance variables and method-call results into locals before the loop — locals are stack-indexed, everything else is a lookup.
5. **Exception cost**: frequent expected failures in hot loops → backtraceless raise (see refactor's `hot_loop_exception_backtrace`) or return values.

### Step 4: Re-verify — keep or revert

Rerun the benchmark. **If the gain is under ~10-20%, revert** — the maintenance cost of clever code usually exceeds the win. Report deltas as ips ratios ("2.3x"), not vague adjectives. Then rerun the *test suite*: an optimization that changes behavior is a bug with good latency.

## Output Format

Report each optimization as:

```yaml
- hotspot: "CSV::Row#fetch in ReportGenerator#process (41% of samples)"
  change: "hoisted header index lookup out of row loop"
  benchmark: "bench/report_generator_bench.rb"
  before_ips: 1_240
  after_ips: 4_810
  ratio: "3.9x"
  tests: pass
```

## Integration

- **From analyse**: the debugger's Muda/Root-Cause findings with performance symptoms hand off here with the suspected hotspot.
- **To sift**: optimized code still passes the audit gate — clever-but-unreadable fails Idioms.
- **With refactor**: catalog patterns (`hot_loop_exception_backtrace`, `thread_to_async`) apply mechanically once this skill has proven the hotspot.

## Common Pitfalls

1. **Optimizing without profiling** — the hotspot is almost never where intuition says.
2. **Benchmarking unrealistic input** — n=10 hides O(n²); use production-shaped data.
3. **Keeping sub-10% wins** — complexity compounds, single-digit gains don't.
4. **Trusting one run** — benchmark-ips reports stddev; overlapping error bars mean no win.
5. **Forgetting the GC** — if `mode: :object` shows heavy allocation, reduce allocations before micro-tuning CPU.

## Verification Checklist

- [ ] Profile evidence identifies the hotspot (% of samples) before any change
- [ ] Benchmark script committed with before/after ips and ratio
- [ ] Gain ≥ 10-20% or change reverted
- [ ] Full test suite passes after optimization
- [ ] `ruby -c` and RuboCop conventions still clean
