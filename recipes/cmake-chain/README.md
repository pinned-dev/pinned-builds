# cmake-chain

fmt 11.2.0 -> spdlog 1.15.3 -> installed-package consumer.

Sources and licenses are pinned in sources.txt. The full recipe disables
upstream test suites; smoke-run executes the consumer. Configure-only runs
just the first source project. See the repository README for phase metadata
and local reference capture. Add a scenario when changing options or checks;
do not count a skipped upstream test suite as PASS.
