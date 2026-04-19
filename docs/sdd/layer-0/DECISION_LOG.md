# VNALO Decision Log (ADR)

## ADR 001: WebRTC for Real-time Calls
**Status**: Decided
**Context**: Need a scalable, peer-to-peer solution for voice and video communication.
**Decision**: Adopted WebRTC with a custom Node.js Signaling Gateway.
**Rationale**: Native-like performance, widespread support, and ability to handle P2P media streams with STUN/TURN fallbacks.

## ADR 002: Premium Glass UI Design
**Status**: Decided
**Context**: Competitors like Zalo used standard flat designs. VNALO aims for a "Premium" feel.
**Decision**: Standardized on a "Glassmorphism" aesthetic with alpha-blended backgrounds (`0.5` opacity for overlays).
**Rationale**: High UX impact, modern aesthetic, and brand differentiation.

## ADR 003: Microservice Path (Polyglot)
**Status**: Decided
**Context**: Scaling specific features (AI vs Core) requires independent scaling.
**Decision**: Java Spring Boot for core business logic, Node.js for real-time signaling.
**Rationale**: Java's safety and ecosystem for Enterprise logic; Node.js event-loop for high-concurrency signaling.

## ADR 004: Spec-Driven Development (SDD)
**Status**: Accepted (2026-04-19)
**Context**: Communication gaps between AI-agents and humans led to spec drift.
**Decision**: All features must have an L2 Spec before/during implementation.
**Rationale**: Ensures 100% code accuracy and enables autonomous engineering roles.
