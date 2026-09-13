.PHONY: check verify pull up wait test ui logs down cleanup

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
	./scripts/serve-ui.sh

logs:
	docker compose logs -f vllm

down:
	docker compose down

cleanup:
	./scripts/cleanup.sh
