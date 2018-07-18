.PHONY: build
build:
	hugo
	git checkout master
	find . -type f -not -name 'public' -print0 | xargs -0 rm -rf --
	mv public/* .
	rm -rf public
	git commit -m "Publish."
