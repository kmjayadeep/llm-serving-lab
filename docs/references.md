# References

Last reviewed: 2026-09-12. Prefer release-specific documentation when reproducing an experiment.

## vLLM

- [vLLM documentation](https://docs.vllm.ai/)
- [GPU installation](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/)
- [Docker deployment](https://docs.vllm.ai/en/stable/deployment/docker/)
- [OpenAI-compatible server](https://docs.vllm.ai/en/stable/serving/openai_compatible_server/)
- [vLLM GitHub repository](https://github.com/vllm-project/vllm)

## AMD ROCm and Radeon

- [AMD: vLLM inference and serving on ROCm](https://rocm.docs.amd.com/projects/ai-ecosystem/en/latest/inference/vllm.html)
- [AMD Radeon/Ryzen: vLLM Docker image](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/advanced/advancedrad/linux/llm/build-docker-image.html)
- [Radeon native Linux compatibility](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/native_linux/native_linux_compatibility.html)
- [ROCm documentation](https://rocm.docs.amd.com/)
- [ROCm vLLM fork/repository](https://github.com/ROCm/vllm)

## Models

- [Qwen2.5-0.5B-Instruct model card](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct)
- [Hugging Face Hub documentation](https://huggingface.co/docs/hub/)

Always review a model's license, intended use, limitations, and revision before using it.

## Kubernetes and AMD GPUs

- [Kubernetes device plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)
- [AMD GPU device plugin documentation](https://instinct.docs.amd.com/projects/k8s-device-plugin/en/latest/)
- [ROCm Kubernetes device plugin repository](https://github.com/ROCm/k8s-device-plugin)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)

## llm-d

- [llm-d website](https://llm-d.ai/)
- [llm-d documentation](https://llm-d.ai/docs/)
- [llm-d architecture](https://llm-d.ai/docs/architecture)
- [llm-d quickstart](https://llm-d.ai/docs/getting-started/quickstart)
- [llm-d GitHub repository](https://github.com/llm-d/llm-d)

## KServe and observability

- [KServe documentation](https://kserve.github.io/website/)
- [KServe Hugging Face/vLLM runtime](https://kserve.github.io/website/latest/modelserving/v1beta1/llm/huggingface/)
- [Prometheus](https://prometheus.io/docs/introduction/overview/)
- [Grafana](https://grafana.com/docs/)

## Related local-serving tools

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [Ollama](https://ollama.com/)

These are useful comparison points. vLLM emphasizes high-throughput serving and batching; llama.cpp and Ollama can be more convenient for single-user quantized local inference.
