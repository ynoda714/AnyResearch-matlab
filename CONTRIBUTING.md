# Contributing to AnyResearch

Thank you for your interest in AnyResearch!

## Reporting Bugs

Please [open an issue](https://github.com/ynoda714/AnyResearch-matlab/issues/new) and include:

- MATLAB version (e.g., R2025b)
- Operating system
- Steps to reproduce the problem
- Relevant log output (from `result/runs/<timestamp>/`)
- Expected vs actual behavior

## Requesting Features

Open a feature request issue describing:

- The use case (who needs it, why)
- Proposed behavior or API change
- Whether it applies to Layer 0, Layer 1, or both

## Submitting Pull Requests

1. Fork the repository and create a branch from `main`
2. Make your changes in `src/` (no logic in root `.m` files)
3. Add a smoke test in `test/smoke/` if applicable
4. Verify that all existing smoke tests pass
5. Follow the naming conventions in [Code Style](#code-style) below (snake_case `.m` files, English comments)
6. Open a pull request with a description of the change

## Code Style

- `.m` files: English-only comments and log messages
- Function naming: `snake_case` (e.g., `fetch_openalex_works.m`)
- No logic in `main_run_pipeline.m` or `main_run_batch.m` — parameters only
- Use `log_info` / `log_warn` / `log_error` helpers; no bare `fprintf`

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
