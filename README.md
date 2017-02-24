# SCTP-Crystal

**This library does not work in its current state for Crystal 20.5+ since sockets were refactored.**

SCTP networking library for Crystal.

SCTP-Crystal is currently in an early state.
There may be breaking changes.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  nuummite:
    github: codesteak/sctp-crystal
    version: ~> 0.2.0
```

## Usage

For usage please see `spec/sctp_spec`.
`samples/` will be updated soon.

## Dependencies
### Linux
You need to have `lksctp-tools` installed.
#### Arch
`# pacman -S lksctp-tools`
#### Ubuntu
`# apt-get install libsctp-dev lksctp-tools`

### Other OS
¯\\_(ツ)_/¯
<!--
 :shrug: would be better.
-->
## TODO
- Better samples, docs & tests
- More socket options

---

Feel free to make pull requests or open issues for bugs and missing features.
