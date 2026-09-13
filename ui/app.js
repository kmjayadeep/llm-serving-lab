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
  running: document.querySelector("#running"),
  waiting: document.querySelector("#waiting"),
  kvCache: document.querySelector("#kv-cache"),
  prefixCache: document.querySelector("#prefix-cache"),
  promptTokens: document.querySelector("#prompt-tokens"),
  generatedTokens: document.querySelector("#generated-tokens"),
  finishedRequests: document.querySelector("#finished-requests"),
  errors: document.querySelector("#errors"),
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

function parsePrometheus(text) {
  const samples = [];
  for (const line of text.split("\n")) {
    if (!line || line.startsWith("#")) continue;
    const match = line.match(/^([^\s{]+)(?:\{([^}]*)\})?\s+([^\s]+)$/);
    if (!match) continue;
    const labels = {};
    for (const label of (match[2] || "").matchAll(/(\w+)="([^"]*)"/g)) {
      labels[label[1]] = label[2];
    }
    samples.push({ name: match[1], labels, value: Number(match[3]) });
  }
  return samples;
}

function metricSum(samples, name, labels = {}) {
  return samples
    .filter((sample) => sample.name === name)
    .filter((sample) => Object.entries(labels).every(([key, value]) => sample.labels[key] === value))
    .reduce((total, sample) => total + sample.value, 0);
}

function renderServerMetrics(snapshot) {
  const format = (value) => Math.round(value).toLocaleString();
  elements.running.textContent = format(snapshot.running);
  elements.waiting.textContent = format(snapshot.waiting);
  elements.kvCache.textContent = `${(snapshot.kvCache * 100).toFixed(1)}%`;
  elements.prefixCache.textContent = snapshot.queries > 0
    ? `${(snapshot.hits / snapshot.queries * 100).toFixed(1)}%`
    : "n/a";
  elements.promptTokens.textContent = format(snapshot.promptTokens);
  elements.generatedTokens.textContent = format(snapshot.generatedTokens);
  elements.finishedRequests.textContent = format(snapshot.finishedRequests);
  elements.errors.textContent = format(snapshot.errors);
}

async function fetchServerMetrics(render = true) {
  const response = await fetch("http://127.0.0.1:8000/metrics");
  if (!response.ok) throw new Error(`Metrics HTTP ${response.status}`);
  const samples = parsePrometheus(await response.text());
  const snapshot = {
    running: metricSum(samples, "vllm:num_requests_running"),
    waiting: metricSum(samples, "vllm:num_requests_waiting"),
    kvCache: metricSum(samples, "vllm:kv_cache_usage_perc"),
    queries: metricSum(samples, "vllm:prefix_cache_queries_total"),
    hits: metricSum(samples, "vllm:prefix_cache_hits_total"),
    promptTokens: metricSum(samples, "vllm:prompt_tokens_total"),
    generatedTokens: metricSum(samples, "vllm:generation_tokens_total"),
    finishedRequests: metricSum(samples, "vllm:request_success_total"),
    errors: metricSum(samples, "vllm:request_success_total", { finished_reason: "error" })
      + metricSum(samples, "vllm:request_success_total", { finished_reason: "abort" }),
  };
  if (render) renderServerMetrics(snapshot);
  return snapshot;
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

async function streamReply(metricsBefore) {
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
  let requestCacheRate = "cache metric unavailable";
  try {
    const metricsAfter = await fetchServerMetrics();
    const queried = metricsBefore ? metricsAfter.queries - metricsBefore.queries : 0;
    const hits = metricsBefore ? metricsAfter.hits - metricsBefore.hits : 0;
    requestCacheRate = queried > 0 ? `${(hits / queried * 100).toFixed(1)}% request prefix hit` : "no cacheable prefix measured";
  } catch (_) {
    // Metrics are optional; a metrics failure must not turn a valid chat into an error.
  }
  elements.metrics.textContent = `TTFT: ${ttft} · Total: ${elapsedSeconds.toFixed(2)} s · ${rate} · ${requestCacheRate}`;
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
    const metricsBefore = await fetchServerMetrics(false).catch(() => null);
    await streamReply(metricsBefore);
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
fetchServerMetrics().catch(() => {});
setInterval(() => fetchServerMetrics().catch(() => {}), 2000);
