.PHONY: check verify pull up wait test logs down cleanup render-k8s

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

logs:
	docker compose logs -f vllm

down:
	docker compose down

cleanup:
	./scripts/cleanup.sh

render-k8s:
	kubectl kustomize kubernetes/base
