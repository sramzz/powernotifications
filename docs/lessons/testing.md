# Testing lessons

## Random-number test doubles must still produce entropy

A `RandomNumberGenerator` that always returned zero caused Swift's unbiased
range sampling to retry forever. This looked like an Xcode simulator hang while
the first schedule-generator test was running.

Use a deterministic seeded generator for tests involving Swift's random range
or shuffle APIs. Assert the public invariant—such as membership in the expected
segment—rather than relying on the standard library's internal mapping from raw
random bits to a particular value.
