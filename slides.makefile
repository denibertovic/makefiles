IMAGE_NAME='denibertovic/slides'

REVEALJS_TRANSITION?=linear
REVEALJS_THEME?=black
REVEALJS_URL=/opt/slides/reveal.js

PANDOC_CMD_PRESENT="pandoc -5 --slide-level=1 -t revealjs --highlight-style=zenburn -f markdown_github+mmd_title_block+backtick_code_blocks --standalone --self-contained --section-divs --variable transition=${REVEALJS_TRANSITION} --variable revealjs-url=${REVEALJS_URL} --variable theme=${REVEALJS_THEME} md/slides.md -o out/index.html"

PANDOC_CMD_PDF="pandoc --slide-level=1 -t latex --highlight-style=zenburn -f markdown_github+mmd_title_block+backtick_code_blocks --standalone --self-contained --section-divs md/slides.md -o out/out.pdf"

.PHONY: run prompt clean html pdf present logs

LOCAL_USER_ID ?= $(shell id -u $$USER)

require-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "ERROR: Environment variable not set: \"$*\""; \
		exit 1; \
	fi

## Run node.js web server
run: require-LOCAL_USER_ID require-IMAGE_NAME clean
	@-docker rm -v -f slides
	@docker run --rm -d \
		-e LOCAL_USER_ID=${LOCAL_USER_ID} \
		-v `pwd`/md:/opt/slides/reveal.js/md \
		-p 8000:8000 \
		-p 35729:35729 \
		--name slides \
	$(IMAGE_NAME)
	@echo "\n\nServer launched. Visit http://localhost:8000 to view slides.\n"

## Spawn bash shell in the container
shell: require-LOCAL_USER_ID require-IMAGE_NAME
	@docker run --rm -it \
		-e LOCAL_USER_ID=${LOCAL_USER_ID} \
 		-v `pwd`/out:/opt/slides/reveal.js/out \
		-v `pwd`/md:/opt/slides/reveal.js/md \
	$(IMAGE_NAME) /bin/bash

## Removes generated files
clean:
	@rm -rf out

## Generate index.html
html: require-LOCAL_USER_ID require-IMAGE_NAME clean
	@docker run --rm -it \
		-e LOCAL_USER_ID=${LOCAL_USER_ID} \
 		-v `pwd`/md:/opt/slides/reveal.js/md \
 		-v `pwd`/out:/opt/slides/reveal.js/out \
	$(IMAGE_NAME) /bin/bash -c ${PANDOC_CMD_PRESENT}
	@echo "\n\nSUCCESS! Check out/index.html\n"

## Generate PDF
pdf: require-LOCAL_USER_ID require-IMAGE_NAME clean
	@docker run --rm -it \
		-e LOCAL_USER_ID=${LOCAL_USER_ID} \
 		-v `pwd`/md:/opt/slides/reveal.js/md \
 		-v `pwd`/out:/opt/slides/reveal.js/out \
	$(IMAGE_NAME) /bin/bash -c ${PANDOC_CMD_PDF}
	@echo "\n\nSUCCESS! PDF created in out/out.pdf\n"

## Open generated index.html in a google-chrome incognito window
present:
	@google-chrome --incognito out/index.html

## Show logs from the slides container
logs:
	@docker logs -f slides

## Show help screen
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
