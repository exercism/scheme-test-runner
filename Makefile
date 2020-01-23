.PHONY : clean clean-docker build-docker run-example enter-docker

image:= runner:runner
example:= prime-factors /mnt/alyssa-p /tmp

clean :
	find . -name "*~" -exec rm {} \;

build-docker :
	docker build -t $(image) .

clean-docker :
	docker image rm --force $(image)

enter-docker :
	docker run -it $(image) sh 

run-example :
	make clean-docker
	make build-docker
	docker run  -it $(image) sh /opt/test-runner/bin/run.sh $(example)
