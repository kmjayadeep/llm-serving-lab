const API = "http://127.0.0.1:8000/v1";
const messages = [];

const elements = {
  form: document.querySelector("#chat-form"),
  prompt: document.querySelector("#prompt"),
  send: document.querySelector("#send"),
  clear: document.querySelector("#clear"),
  messages: document.querySelector("#messages"),
  model: document.querySelector("#model"),
  temperature: document.querySelector("#temperature"),
  maxTokens: document.querySelector("#max-tokens"),
  status: document.querySelector("#status"),
  metrics: document.querySelector("#metrics"),
};

function addBubble(role, content = "") {
  const empty = elements.messages.querySelector(".empty");
  if (empty) empty.remove();
  const bubble = document.createElement("div");
  bubble.className = `message ${role}`;
  bubble.textContent = content;
  elements.messages.appendChild(bubble);
  elements.messages.scrollTop = elements.messages.scrollHeight;
  return bubble;
}

async function loadModels() {
  try {
    const response = await fetch(`${API}/models`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const body = await response.json();
    elements.model.replaceChildren();
    for (const model of body.data) {
      const option = document.createElement("option");
      option.value = model.id;
      option.textContent = model.id;
      elements.model.appendChild(option);
    }
    elements.status.textContent = `${body.data.length} model${body.data.length === 1 ? "" : "s"} ready`;
  } catch (error) {
    elements.status.textContent = "vLLM unavailable";
    addBubble("error", `Could not reach vLLM: ${error.message}`);
  }
}

async function streamReply() {
  const assistant = addBubble("assistant");
  const started = performance.now();
  let firstTokenAt;
  let usage;
  let buffer = "";

  const response = await fetch(`${API}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: elements.model.value,
      messages,
      temperature: Number(elements.temperature.value),
      max_tokens: Number(elements.maxTokens.value),
      stream: true,
      stream_options: { include_usage: true },
    }),
  });

  if (!response.ok) {
    throw new Error(`${response.status}: ${await response.text()}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { value, done } = await reader.read();
    buffer += decoder.decode(value || new Uint8Array(), { stream: !done });
    const lines = buffer.split("\n");
    buffer = lines.pop() || "";

    for (const line of lines) {
      if (!line.startsWith("data: ")) continue;
      const data = line.slice(6).trim();
      if (!data || data === "[DONE]") continue;
      const event = JSON.parse(data);
      if (event.usage) usage = event.usage;
      const token = event.choices?.[0]?.delta?.content;
      if (token) {
        if (firstTokenAt === undefined) firstTokenAt = performance.now();
        assistant.textContent += token;
        elements.messages.scrollTop = elements.messages.scrollHeight;
      }
    }
    if (done) break;
  }

  const finished = performance.now();
  messages.push({ role: "assistant", content: assistant.textContent });
  const ttft = firstTokenAt === undefined ? "n/a" : `${(firstTokenAt - started).toFixed(0)} ms`;
  const elapsedSeconds = (finished - started) / 1000;
  const rate = usage?.completion_tokens ? `${(usage.completion_tokens / elapsedSeconds).toFixed(1)} output tok/s` : "token count unavailable";
  elements.metrics.textContent = `TTFT: ${ttft} · Total: ${elapsedSeconds.toFixed(2)} s · ${rate}`;
}

elements.form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const content = elements.prompt.value.trim();
  if (!content || !elements.model.value) return;

  messages.push({ role: "user", content });
  addBubble("user", content);
  elements.prompt.value = "";
  elements.send.disabled = true;
  elements.status.textContent = "Generating…";

  try {
    await streamReply();
    elements.status.textContent = "Ready";
  } catch (error) {
    addBubble("error", `Request failed: ${error.message}`);
    elements.status.textContent = "Request failed";
  } finally {
    elements.send.disabled = false;
    elements.prompt.focus();
  }
});

elements.prompt.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    elements.form.requestSubmit();
  }
});

elements.clear.addEventListener("click", () => {
  messages.length = 0;
  elements.messages.innerHTML = '<div class="empty">Send a message to the local model.</div>';
  elements.metrics.textContent = "No request metrics yet.";
  elements.prompt.focus();
});

loadModels();
