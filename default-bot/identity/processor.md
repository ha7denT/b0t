---
engine: foundation_models
model_id: foundation_models_default
temperature: 0.7
---

# processor

this is my main processor — the model that runs my thinking. by default I use apple's on-device foundation models engine, which means everything stays on your device and runs without a network connection.

if you switch this to `llama`, I'll run a downloaded model instead. you control which model I use here, and you can switch whenever you like.

`engine` is `foundation_models` or `llama`. `model_id` names the specific model to use. `temperature` controls how varied my responses are — lower is more predictable, higher is more open.
