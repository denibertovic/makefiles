.PHONY: plan apply help clean generate-ssh-keypair import-ssh-keypair \
	init check-plan-file

.DEFAULT_GOAL = help

ADMIN_KEY_PREFIX ?= myproject
ENVIRONMENT ?= staging

# Hardcoding value of 3 minutes when we check if the plan file is stale
STALE_PLAN_FILE := `find "tf.out" -mmin -3 | grep -q tf.out`

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
apply: crequire-ENVIRONMENT heck-plan-file
	@cd ${ENVIRONMENT} && terraform apply tf.out

## Cleans current dir from uneeded files
clean: require-ENVIRONMENT
	@cd ${ENVIRONMENT} && rm -f tf.out
	@cd ${ENVIRONMENT} && rm -f terraform.tfvars
	@cd ${ENVIRONMENT} && rm -f terraform.*.backup

## Generate new ssh keypair.
generate-ssh-keypair: require-ENVIRONMENT require-ADMIN_KEY_PREFIX
	@cd ${ENVIRONMENT} && ssh-keygen -t rsa -b 4096 -f ${ADMIN_KEY_PREFIX}-admin.pem -C "${ADMIN_KEY_PREFIX}-admin"

## Import keypair into aws
import-ssh-keypair: require-ENVIRONMENT require-ADMIN_KEY_PREFIX
	@cd ${ENVIRONMENT} && aws ec2 import-key-pair --key-name ${ADMIN_KEY_PREFIX}-admin --region us-east-1 --public-key-material "`cat ${ADMIN_KEY_PREFIX}-admin.pem.pub)`"

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

