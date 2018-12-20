.PHONY: plan apply help clean generate-ssh-keypair import-ssh-keypair \
	init check-plan-file fetch-vars fetch-ssh-keys save-vars save-ssh-keys

.DEFAULT_GOAL = help

export PASSWORD_STORE_DIR ?= ${PWD}/../password-store

# Hardcoding value of 3 minutes when we check if the plan file is stale
STALE_PLAN_FILE := `find "${ENVIRONMENT}/tf.out" -mmin -3 | grep -q tf.out`

require-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "ERROR: Environment variable not set: \"$*\""; \
		exit 1; \
	fi

## Check if tf.out is stale (Older than 2 minutes)
check-plan-file:
	@if ! ${STALE_PLAN_FILE} ; then \
		echo "ERROR: Stale tf.out plan file (older than 3 minutes)!"; \
		exit 1; \
	fi

## Runs terraform get and terraform init for env
init: require-ENVIRONMENT
	@cd ${ENVIRONMENT} && terraform get
	@cd ${ENVIRONMENT} && terraform init

## EXAMPLE: initial terraform plan (makes VPC, subnets, etc)
# init-plan: require-ENVIRONMENT require-CLUSTER_NAME
# 	@cd ${ENVIRONMENT} && terraform plan \
# 		-target="module.vpc" \
# 		-target="module.public-subnets" \
# 		-target="module.open-ssh" \
# 		-target="module.open-egress" \
# 		-target="module.open-egress" \
# 		-out=tf.out

## terraform plan (makes everything)
plan: require-ENVIRONMENT
	@cd ${ENVIRONMENT} && terraform plan -out=tf.out

## terraform apply
apply: require-ENVIRONMENT check-plan-file
	@cd ${ENVIRONMENT} && terraform apply tf.out

## Cleans current dir from uneeded files
clean: require-ENVIRONMENT
	@cd ${ENVIRONMENT} && rm -f tf.out
	@cd ${ENVIRONMENT} && rm -f terraform.tfvars
	@cd ${ENVIRONMENT} && rm -f terraform.*.backup

## Generate new ssh keypair.
generate-ssh-keypair: require-ENVIRONMENT require-CLUSTER_NAME
	@cd ${ENVIRONMENT} && ssh-keygen -t rsa -b 4096 -f ${CLUSTER_NAME}-admin.pem -C "${CLUSTER_NAME}-admin"
## Import keypair into aws
import-ssh-keypair: require-ENVIRONMENT require-CLUSTER_NAME
	@cd ${ENVIRONMENT} && aws ec2 import-key-pair --key-name ${CLUSTER_NAME}-admin --region us-east-1 --public-key-material "`cat ${CLUSTER_NAME}-admin.pem.pub)`"

## Saves admin keys to password store
save-ssh-keys: require-ENVIRONMENT require-CLUSTER_NAME
	@pass insert -f -m clusters/${CLUSTER_NAME}/keys/admin.pem<${ENVIRONMENT}/${CLUSTER_NAME}-admin.pem
	@pass insert -f -m clusters/${CLUSTER_NAME}/keys/admin.pem.pub<${ENVIRONMENT}/${CLUSTER_NAME}-admin.pem.pub

## Saves terraform.tfvars to password store
save-vars: require-ENVIRONMENT require-CLUSTER_NAME
	@pass insert -f -m tfvars/${CLUSTER_NAME}.tfvars<${ENVIRONMENT}/terraform.tfvars

## Fetch terraform.tfvars from password store
fetch-vars: require-ENVIRONMENT require-CLUSTER_NAME require-PASSWORD_STORE_DIR
	@pass tfvars/${CLUSTER_NAME}.tfvars > ${ENVIRONMENT}/terraform.tfvars

## Fetch ssh public and private key from pw store
fetch-ssh-keys: require-ENVIRONMENT require-CLUSTER_NAME require-PASSWORD_STORE_DIR
	@pass clusters/${CLUSTER_NAME}/keys/admin.pem > ${ENVIRONMENT}/${CLUSTER_NAME}-admin.pem
	@pass clusters/${CLUSTER_NAME}/keys/admin.pem > ${ENVIRONMENT}/${CLUSTER_NAME}-admin.pem.pub

## Show help screen.
help:
	@echo "Please use \`make <target>' where <target> is one of\n\n"
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-30s %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

