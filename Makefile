GLUU_VERSION=4.2.1
IMAGE_NAME=gluufederation/gluu-gateway
UNSTABLE_VERSION=dev

build-dev:
	@echo "[I] Building Docker image ${IMAGE_NAME}:${GLUU_VERSION}_${UNSTABLE_VERSION}"
	@docker build --rm --force-rm -t ${IMAGE_NAME}:${GLUU_VERSION}_${UNSTABLE_VERSION} .
