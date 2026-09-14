.PHONY: check verify pull up wait test ui logs down cleanup kind-up kind-test kind-down kind-gpu-up kind-gpu-test kind-gpu-down

check:
	./scripts/check-amd-gpu.sh

verify:
	./scripts/verify-rocm-container.sh

pull:
	docker compose pull

up:
	docker compose up -d

wait:
	./scripts/wait-for-server.sh

test:
	./scripts/test-api.sh

ui:
	docker compose up -d --build ui

logs:
	docker compose logs -f vllm

down:
	docker compose down

cleanup:
	./scripts/cleanup.sh

kind-up:
	./scripts/kind-up.sh

kind-test:
	./scripts/test-kind.sh

kind-down:
	kind delete cluster --name llm-serving-lab

kind-gpu-up:
	./scripts/kind-gpu-up.sh

kind-gpu-test:
	./scripts/test-kind-gpu.sh

kind-gpu-down:
	kind delete cluster --name llm-serving-gpu-lab
