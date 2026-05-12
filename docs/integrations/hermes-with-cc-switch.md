
# Hermes With cc-switch

cc-switch is the preferred provider/profile switchboard for AI coding CLIs where supported.

Hermes has its own provider configuration and may not automatically read every cc-switch profile. This integration must be explicit.

## Goal

Avoid profile drift:

```text
Claude Code using provider A
Codex using provider B
Hermes using provider C
Fabric using provider D
```

That can be intentional, but it must be documented.

## Ownership Boundary

cc-switch owns:

- Claude Code provider profiles.
- Codex provider profiles.
- Gemini CLI provider profiles.
- OpenCode/OpenClaw provider profiles.
- GUI/profile switching state.

Hermes owns:

- Hermes model/provider runtime settings.
- Agent memory, skills, tools, and gateway settings.

## Integration Rule

When Hermes and coding CLIs should use the same provider, document:

```text
provider name
base URL
model
which tool stores the key
how to rotate the key
which services need restart
```

## Recovery Rule

If model calls fail after switching profiles:

1. Check cc-switch active profile.
2. Check the specific CLI config file that cc-switch writes.
3. Check Hermes model config separately.
4. Check provider key validity.
5. Do not edit all configs blindly.
