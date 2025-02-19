SHELL=/bin/bash
CDK_DIR=infrastructure/
COMPOSE_RUN = docker-compose run --rm base
COMPOSE_RUN_WITH_PORTS = docker-compose run -d --name base --service-ports --rm base
COMPOSE_UP_FULL_STACK = docker-compose up dynamodb sam frontend
COMPOSE_UP_FRONTEND = docker-compose up frontend
COMPOSE_UP_BACKEND = docker-compose up dynamodb sam
COMPOSE_RUN_PLAYWRIGHT = docker-compose run --rm playwright
COMPOSE_UP = docker-compose up base
PROFILE = --profile default
REGION = --region us-east-1

.DEFAULT_GOAL := help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

is-built: 
	if [ ! -d ./frontend/build ]; then make build; fi

# prep-env:
# 	${COMPOSE_RUN} make _prep-env

_prep-env:
	if [ ! -f ./configs.env ]; then \
		echo "No configs.env file found, genereating from env variables"; \
		touch configs.env; \
		echo "REACT_APP_USER_API_URL_LOCAL_SAM=http://localhost:3001/users" >> configs.env; \
		echo "THREE_M_DOMAIN=${THREE_M_DOMAIN}" >> configs.env; \
		echo "THREE_M_HOSTED_ZONE_NAME=${THREE_M_HOSTED_ZONE_NAME}" >> configs.env; \
		echo "THREE_M_HOSTED_ZONE_ID=${THREE_M_HOSTED_ZONE_ID}" >> configs.env; \
		echo "REACT_APP_USER_API_DOMAIN=${REACT_APP_USER_API_DOMAIN}" >> configs.env; \
	fi

_prep-env-ci:
	echo "THREE_M_DOMAIN=${THREE_M_DOMAIN}" >> configs.env; \
	echo "THREE_M_HOSTED_ZONE_NAME=${THREE_M_HOSTED_ZONE_NAME}" >> configs.env; \
	echo "THREE_M_HOSTED_ZONE_ID=${THREE_M_HOSTED_ZONE_ID}" >> configs.env; \
	echo "REACT_APP_USER_API_DOMAIN=${REACT_APP_USER_API_DOMAIN}" >> configs.env; \

build-container: 
	docker-compose build

cli: _prep-cache
	docker-compose run base /bin/bash

################
# Core Commands#
################

# These commands run processes acorss the mulitple layers of the project
.PHONY: install
install npm-install: _prep-env build-container install-infra install-frontend install-e2e install-backend synth

.PHONY: test
test: test-frontend test-e2e test-infra

.PHONY: run
run: _prep-env _launch-browser check-infra-synthed
	${COMPOSE_UP_FULL_STACK}

################
### Frontend ###
################

check-frontend-installed: 
	${COMPOSE_RUN} make _check-frontend-installed

_check-frontend-installed:
	if [ ! -d ./frontend/node_modules ]; then make install-frontend; fi

.PHONY: install-frontend
install-frontend: 
	${COMPOSE_RUN} make _install-frontend

_install-frontend npm-install-frontend:
	npm install --prefix frontend/

_launch-browser: #Haven't tested on mac, not sure what will happen ToDo: instead of wait 10 seconds, wait for site to be loaded
	nohup sleep 5 && xdg-open http://localhost:3000 || open "http://localhost:3000" || explorer.exe "http://localhost:3000"  >/dev/null 2>&1 &

#ToDo: Frontend doesn't go down when you kill it. Ctrl+c or z should kill the container
#ToDo: handling for when port 3000 is already in use
.PHONY: run-frontend
run-frontend start-frontend: _launch-browser
	${COMPOSE_RUN_WITH_PORTS} make _run-frontend
	docker exec -it base tail -f watch.log

_run-frontend:
	npm start --prefix frontend/ > /app/watch.log

#Useful for the CI, for local dev recomendation is to simply run make run in another terminal
run-frontend-daemon start-frontend-daemon:
	${COMPOSE_RUN_WITH_PORTS} make _run-frontend

_run-frontend-daemon:
	npm start --prefix frontend/ > /app/watch.log

.PHONY: test-frontend
test-frontend: 
	${COMPOSE_RUN} make _test-frontend

_test-frontend:
	export CI=true && npm test --prefix frontend/

.PHONY: test-frontend-interactive
test-frontend-interactive: 
	${COMPOSE_RUN} make _test-frontend-interactive

_test-frontend-interactive:
	npm test --prefix frontend/

.PHONY: build
build: 
	${COMPOSE_RUN} make _build

_build:
	npm run build --prefix frontend/

container-info:
	${COMPOSE_RUN} make _container-info

_container-info:
	./containerInfo.sh

.PHONY: ci
ci: 
	${COMPOSE_RUN} make _ci

_ci:
	npm ci --prefix frontend/

###############
### Backend ###
###############

_prep-venv:
	python3 -m venv backend/.venv

_clear-cache-backend:
	rm -rf backend/.venv/
	rm -rf backend/.pytest_cache/

check-backend-installed: 
	${COMPOSE_RUN} make _check-backend-installed

_check-backend-installed:
	if [ ! -d ./backend/.venv ]; then make install-backend; fi

.PHONY: install-backend
install-backend: 
	${COMPOSE_RUN} make _install-backend

_install-backend:
	python3 -m venv backend/.venv
	source backend/.venv/bin/activate
	pip install -r backend/tests/requirements.txt

.PHONY: test-backend
test-backend: test-backend-unit

.PHONY: test-backend-unit
test-backend-unit:
	${COMPOSE_RUN} make _test-backend-unit

_test-backend-unit:
	cd backend && LOG_LEVEL=INFO AWSENV=AWSENV TABLE_NAME=visitorCount CORS_URL=http://localhost:3000 AWS_DEFAULT_REGION=us-east-1 python -m pytest tests/unit -v --cov=hello_world --cov-report=xml:../coverage-reports/backend-unit-coverage.xml && cd ..

# Monitor lambda function logs which was deployed from local
# ToDo: Monitor other lambda functions
.PHONY: monitor-lambda-logs
monitor-lambda-logs:
	${COMPOSE_RUN} make _monitor-lambda-logs
_monitor-lambda-logs:
	echo "============ Monitoring $$(grep -B1 'AWS::Lambda::Function' infrastructure/template.yaml | grep -o BackendFunction[0-9]*) greated via stack $$(grep 'displayName' infrastructure/cdk.out/manifest.json| cut -d: -f2 |  tr -d '\"') ============"
	sam logs -n $$(grep -B1 'AWS::Lambda::Function' infrastructure/template.yaml | grep -o BackendFunction[0-9]*) --stack-name $$(grep 'displayName' infrastructure/cdk.out/manifest.json| cut -d: -f2 |  tr -d '"') --tail ${PROFILE} ${REGION}

build-backend: synth

_kill-sam:
	killall -9 sam || echo "SAM was not already running... starting SAM"

#ToDo: check for template.yaml, build if not exist
#ToDo: Add warning to update make synth on CDK changes
run-backend: check-infra-synthed
	${COMPOSE_UP_BACKEND}

_run-backend _start-api: _kill-sam
	cd backend && sam local start-api -p 3001 -t ../infrastructure/template.yaml --docker-volume-basedir /home/chris/git/gsd-aws-cdk-serverless-example/backend --host 0.0.0.0 --env-vars sam_local_environment_variables.json --docker-network aws_backend && cd ..

# sam local start-api \
#     --host 0.0.0.0 \
# 	--port 3001 \
# 	-t ../infrastructure/template.yaml \
#     --container-host-interface 0.0.0.0 \
#     --container-host host.docker.internal \
#     --debug \
#     --docker-volume-basedir $PWD 
# cd backend && sam local start-api -p 3001 -t ../infrastructure/template.yaml --host 0.0.0.0 --debug && cd .. # Works with old SAM version

#############
### Infra ###
#############

.PHONY: install-infra
install-infra npm-install-infra: 
	${COMPOSE_RUN} make _install-infra

_install-infra:
	npm install --prefix ${CDK_DIR}/

_prep-cache: #This resolves Error: EACCES: permission denied, open 'cdk.out/tree.json'
	mkdir -p ${CDK_DIR}/cdk.out/
	if [ ! -f ./${CDK_DIR}/cdk.out/tree.json ]; then touch ${CDK_DIR}/cdk.out/tree.json; fi

test-infra:
	${COMPOSE_RUN} make _test-infra

_test-infra:
	npm test --prefix ${CDK_DIR}/ 

down:
	docker-compose down --remove-orphans --volume

clear-cache:
	${COMPOSE_RUN} rm -rf ${CDK_DIR}cdk.out && rm -rf ${CDK_DIR}node_modules

check-infra-synthed: 
	${COMPOSE_RUN} make _check-infra-synthed

_check-infra-synthed:
	if [ ! -f ./${CDK_DIR}/template.yaml ]; then make synth; fi

synth: _prep-cache is-built
	${COMPOSE_RUN} make _synth

_synth:
	cd ${CDK_DIR} && cdk synth --no-staging ${PROFILE} > template.yaml

bootstrap: _prep-cache
	${COMPOSE_RUN} make _bootstrap

_bootstrap:
	cd ${CDK_DIR} && cdk bootstrap ${PROFILE}

deploy: _prep-cache build
	${COMPOSE_RUN} make _deploy 

deploy-no-build: _prep-cache
	${COMPOSE_RUN} make _deploy 

_deploy: 
	cd ${CDK_DIR} && cdk deploy --require-approval never ${PROFILE}

destroy:
	${COMPOSE_RUN} make _destroy

_destroy:
	cd ${CDK_DIR} && cdk destroy --force ${PROFILE}

diff: _prep-cache is-built
	${COMPOSE_RUN} make _diff

_diff: _prep-cache
	cd ${CDK_DIR} && cdk diff ${PROFILE}

###########
### E2E ###
###########
.PHONY: install-e2e
install-e2e: 
	${COMPOSE_RUN} make _install-e2e

_install-e2e npm-install-playwright:
	npm install --prefix e2e/

.PHONY: test-e2e
test-e2e:
	${COMPOSE_RUN_PLAYWRIGHT} make _test-e2e

_test-e2e:
	cd e2e && npx playwright test --output ../test_results/ && cd .. 

test-e2e-ci:
	${COMPOSE_RUN_PLAYWRIGHT} make _test-e2e-ci

_test-e2e-ci:
	cd e2e && export CI=true && npx playwright test --output ../test_results/ && cd .. 

#Running e2e tests locally in a browser cannot be done via a container, if you want to run e2e tests headfully(in browser) then run this command
.PHONY: _test-install-e2e-headful
_test-install-e2e-headful:
	cd e2e &&  npx playwright install-deps && cd ..

#ToDo: Figure out how to specify a directory for npx https://github.com/npm/npx/issues/74#issuecomment-676092733
#ToDo: Ensure frontend is up and running
.PHONY: _test-install-e2e-headful
_test-e2e-headful:
	cd e2e && npx playwright test --headed && cd .. 
