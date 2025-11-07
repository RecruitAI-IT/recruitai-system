.PHONY: deploy build-all stop-all update-all rebuild-all
.PHONY: rebuild-app stop-app
.PHONY: rebuild-monitoring stop-monitoring
.PHONY: rebuild-db stop-db
.PHONY: set-env set-env-to-config-template

set-env:
	@export $(cat env/.env.app env/.env.db env/.env.monitoring | xargs)

set-env-to-config-template:
	@envsubst < ${RECRUITAI_LOKI_CONFIG_FILE}.template > ${RECRUITAI_LOKI_CONFIG_FILE}
	@envsubst < ${RECRUITAI_MONITORING_REDIS_CONFIG_FILE}.template > ${RECRUITAI_MONITORING_REDIS_CONFIG_FILE}
	@envsubst < ${RECRUITAI_TEMPO_CONFIG_FILE}.template > ${RECRUITAI_TEMPO_CONFIG_FILE}
	@envsubst < ${RECRUITAI_OTEL_COLLECTOR_CONFIG_FILE}.template > ${RECRUITAI_OTEL_COLLECTOR_CONFIG_FILE}

deploy:
	@apt update && apt upgrade -y
	@apt install python3-pip git make
	@pip install requests --break-system-packages
	@cd ..
	@git@github.com:RecruitAI-IT/recruitai-vacancy.git
	@git@github.com:RecruitAI-IT/recruitai-frontend.git
	@cd recruitai-system
	@./infrastructure/nginx/install.sh
	@./infrastructure/docker/install.sh
	@mkdir -p volumes/{grafana,loki,tempo,redis,postgresql,victoria-metrics}
	@mkdir -p volumes/redis/monitoring
	@mkdir -p volumes/weed
	@mkdir -p volumes/postgresql/{vacancy, grafana}
	@chmod -R 777 volumes

build-all: set-env-to-config-template
	@docker compose -f ./docker-compose/db.yaml up -d --build
	sleep 20
	@docker compose -f ./docker-compose/monitoring.yaml up -d --build
	sleep 20
	@docker compose -f ./docker-compose/app.yaml up -d --build


stop-all:
	@docker compose -f ./docker-compose/apps.yaml down
	@docker compose -f ./docker-compose/monitoring.yaml down
	@docker compose -f ./docker-compose/db.yaml down

update-all:
	@git pull
	@cd ../recruitai-vacancy/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../recruitai-system/
	@cd ../recruitai-frontend/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../recruitai-system/

rebuild-all: update-all build-all

rebuild-app: update-all set-env-to-config-template
	@docker compose -f ./docker-compose/apps.yaml up -d --build

stop-app:
	@docker compose -f ./docker-compose/apps.yaml down

stop-monitoring:
	@docker compose -f ./docker-compose/monitoring.yaml down

stop-db:
	@docker compose -f ./docker-compose/db.yaml down

rebuild-monitoring: update-all set-env-to-config-template
	@docker compose -f ./docker-compose/monitoring.yaml down
	@docker compose -f ./docker-compose/monitoring.yaml up -d --build

rebuild-db: update-all set-env-to-config-template
	@docker compose -f ./docker-compose/db.yaml down
	@docker compose -f ./docker-compose/db.yaml up -d --build