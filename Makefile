MAKEFLAGS = -j1

export NODE_ENV = test

.PHONY: build build-dist watch lint fix clean test-clean test-only test test-ci publish bootstrap

build: clean
	./node_modules/.bin/gulp build

build-dist: build
	cd packages/babel-polyfill; \
	scripts/build-dist.sh
	cd packages/babel-runtime; \
	node scripts/build-dist.js
	node scripts/generate-babel-types-docs.js

watch: clean
	rm -rf packages/*/lib
	BABEL_ENV=development ./node_modules/.bin/gulp watch

lint:
	./node_modules/.bin/eslint scripts packages *.js --format=codeframe

flow:
	./node_modules/.bin/flow check

fix:
	./node_modules/.bin/eslint scripts packages *.js --format=codeframe --fix

clean: test-clean
	rm -rf packages/babel-polyfill/browser*
	rm -rf packages/babel-polyfill/dist
	# rm -rf packages/babel-runtime/helpers
	# rm -rf packages/babel-runtime/core-js
	rm -rf coverage
	rm -rf packages/*/npm-debug*

test-clean:
	rm -rf packages/*/test/tmp
	rm -rf packages/*/test-fixtures.json

clean-all:
	rm -rf packages/*/lib
	rm -rf node_modules
	rm -rf packages/*/node_modules
	make clean

test-only:
	./scripts/test.sh
	make test-clean

test: lint test-only

test-ci:
	make bootstrap
	make test-only

test-ci-coverage:
	BABEL_ENV=cov make bootstrap
	./scripts/test-cov.sh
	./node_modules/.bin/codecov -f coverage/coverage-final.json

publish:
	git pull --rebase
	rm -rf packages/*/lib
	BABEL_ENV=production make build-dist
	make test
	# not using lerna independent mode atm, so only update packages that have changed since we use ^
	# --only-explicit-updates
	./node_modules/.bin/lerna publish --npm-tag=next --exact --skip-temp-tag
	make clean

bootstrap:
	make clean-all
	yarn
	./node_modules/.bin/lerna bootstrap
	make build
	cd packages/babel-runtime; \
	node scripts/build-dist.js


	FROM_TAG := ""
TO_TAG := ""
GITHUB_API_TOKEN := ""

##
# Releases
release:
	npm run dist
	./node_modules/.bin/lerna publish

release-canary:
	npm run dist
	./node_modules/.bin/lerna publish --canary

##
# Changelog
changelog:
	git checkout master
	git pull origin master
	GITHUB_AUTH=$(GITHUB_API_TOKEN) ./node_modules/.bin/lerna-changelog --tag-from $(FROM_TAG) --tag-to $(TO_TAG)

push-changelog:
	git checkout master
	git pull origin master
	git add CHANGELOG.md
	git commit -m 'changelog updated.'
	git push origin master

##
# Packages
list-packages:
	./node_modules/.bin/lerna ls

list-updated:
	./node_modules/.bin/lerna updated

##
# Site
site-fetch-contributors:
	GITHUB_API_TOKEN=$(GITHUB_API_TOKEN) node ./site/scripts/fetch-contributors.js

site-build:
	node ./site/scripts/build-content.js

	mkdir -p ./_site/css
	./node_modules/.bin/node-sass --include-path ./node_modules ./site/assets/css/main.scss ./_site/css/site.css

	mkdir -p ./_site/js
	./node_modules/.bin/babel ./site/assets/js --out-dir ./_site/js

	cp -rf ./site/assets/img ./_site/img

	cp -rf ./packages/frint*/dist ./_site/js

site-watch:
	make site-build
	fswatch -or './site' | xargs -I{} make site-build

site-serve-only:
	echo "Starting server at http://localhost:6001"
	./node_modules/.bin/live-server --port=6001 ./_site/

site-serve:
	make site-build
	make site-serve-only

site-publish:
	npm run bootstrap
	npm run dist
	rm -rf ./_site
	make site-build
	make site-publish-only

site-publish-only:
	rm -rf ./_site/.git

	cp -f CNAME ./_site/CNAME

	(cd ./_site && git init)
	(cd ./_site && git commit --allow-empty -m 'update site')
	(cd ./_site && git checkout -b gh-pages)
	(cd ./_site && touch .nojekyll)
	(cd ./_site && git add .)
	(cd ./_site && git commit -am 'update site')
	(cd ./_site && git push git@github.com:Travix-International/frint gh-pages --force)