# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- **Initial extraction.** The email transport that the ActiveAgents platform's
  `examples/support_inbox` grew as app code, made a gem: `BodyParser` (a reply
  chain reduced to what the person wrote this time), `Addressing` (+tag reply
  addresses, lowercase so they survive the mail system), `InboundMessage` (one
  normalized view of a `Mail::Message`), `LoopGuard` (bounces, autoresponders,
  lists, our own addresses, and a per-conversation reply rate), `Mailbox` (the
  exchange, with hooks for the host's conversation records) and `Mailer` (the
  threading headers a reply needs). Conversations remain the host app's own
  models; the gem ships no tables.
