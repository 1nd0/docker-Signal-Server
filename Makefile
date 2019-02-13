MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR  := $(patsubst %/,%,$(dir $(MAKEFILE_PATH)))

S3_ENDPOINT           := http://signal-minio:9000
S3_ATTACHMENTS_BUCKET := signal-attachments-buu
S3_PROFILES_BUCKET    := signal-profiles-buu

DOCKER_PREFIX := $(shell echo $(notdir $(MAKEFILE_DIR)) | tr A-Z a-z)

ifeq ($(OS),Windows_NT)
	OS_ESC_PREFIX=/
else
	OS_ESC_PREFIX=
endif

-include .env

.PHONY: all help up start down stop provision status
all: help

help:
	@echo "make up		- start docker-compose"
	@echo "make down	- stop docker-compose"
	@echo "make provision	- create S3 buckets"
	@echo "make status	- show containers state"

$(MAKEFILE_DIR)/.env:
	@echo ".env file was not found, creating with defaults"
	cp $(MAKEFILE_DIR)/.env.dist $(MAKEFILE_DIR)/.env

$(MAKEFILE_DIR)/signalserver/Signal-Server/config/Signal.yml:
	$(error signalserver/Signal-Server/config/Signal.yml not found. Create it according to README.md)

$(MAKEFILE_DIR)/postgresql/data:
	mkdir -p $(MAKEFILE_DIR)/postgresql/data

up start: | $(MAKEFILE_DIR)/.env $(MAKEFILE_DIR)/postgresql/data $(MAKEFILE_DIR)/signalserver/Signal-Server/config/Signal.yml
	cd $(MAKEFILE_DIR) && docker-compose up -d --remove-orphans

down stop: | $(MAKEFILE_DIR)/.env $(MAKEFILE_DIR)/postgresql/data $(MAKEFILE_DIR)/signalserver/Signal-Server/config/Signal.yml
	cd $(MAKEFILE_DIR) && docker-compose stop

provision: | $(MAKEFILE_DIR)/.env $(MAKEFILE_DIR)/postgresql/data $(MAKEFILE_DIR)/signalserver/Signal-Server/config/Signal.yml
	docker run --rm -it --network $(DOCKER_PREFIX)_default \
	    -v $(OS_ESC_PREFIX)$(MAKEFILE_DIR):/mnt --entrypoint '' minio/mc \
	    /bin/sh -c "/usr/bin/mc config host add myminio $(S3_ENDPOINT) $(MINIO_ACCESS_KEY) $(MINIO_SECRET_KEY) && \
	        /usr/bin/mc mb myminio/$(S3_ATTACHMENTS_BUCKET) && \
	        /usr/bin/mc mb myminio/$(S3_PROFILES_BUCKET) && \
	        /usr/bin/mc policy public myminio/$(S3_ATTACHMENTS_BUCKET) && \
	        /usr/bin/mc policy public myminio/$(S3_PROFILES_BUCKET)"

status: | $(MAKEFILE_DIR)/.env $(MAKEFILE_DIR)/postgresql/data $(MAKEFILE_DIR)/signalserver/Signal-Server/config/Signal.yml
	cd $(MAKEFILE_DIR) && docker-compose ps
