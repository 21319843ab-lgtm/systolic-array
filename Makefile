.PHONY: all test case lint coverage sweep clean

all: test

test:
	bash sim/run_all.sh

case:
	bash sim/run_case.sh

lint:
	bash sim/run_lint.sh

coverage:
	bash sim/run_coverage.sh

sweep:
	python3 analysis/parameter_sweep.py --output-prefix analysis/results/parameter_sweep

clean:
	rm -rf sim/build tools/__pycache__ analysis/__pycache__
	rm -f analysis/results/*.csv analysis/results/*.svg
