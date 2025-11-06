## Oracle Generation

This directory contains the full codebase and original experimental data used for oracle generation.

### Reproducing Existing Results

To reproduce results for a specific target program:

1. Navigate to the corresponding folder:
   ```
   cd oracle_generation_{target_program}
   ```
2. Follow the instructions in `./oracle_generation_{target_program}/README.md` file.


### Provided API Key for evaluation
We provide a **OpenRouter API key** with a usage limit of **$15** to support reproducibility and evaluation. (Located in the Appendix)

To stay within the budget, we recommend that reviewers **test a subset of the programs step-by-step** and **compare the outputs** against the reference results provided in the `metadata/` folder, as well as the oracle generation source described in each program’s `README.md` (`./oracle_generation_{target_program}/README.md`).


### Estimated Cost per Program

| Program   | Estimated Cost (USD) |
|-----------|----------------------|
| Nginx     | $4.32                |
| SQLite3   | $2.75                |
| ProFTPD   | $9.72                |
| Sudo      | $7.74                |
| Apache    | $11.60               |
| Wireshark | $0.60                |
| V8        | $0.90                |

---

### How to Use

Export the provided API key:

```bash
export OPENAI_API_KEY="key-here"
```

> **Using Your Own Key?**  
If you prefer to use your own `OPENAI_API_KEY` with the official OpenAI endpoint, modify all instances of:

```python
OpenAI(base_url="https://openrouter.ai/api/v1")
```

to:

```python
OpenAI()
```

This will default to `https://api.openai.com/v1`, enabling compatibility with your personal API key.



### Testing a New Program

To test the oracle generation pipeline on a new target program:

1. Copy the template directory:
   ```bash
   cp -r oracle_generation_template oracle_generation_newtarget
   ```
2. Use the new folder (`oracle_generation_newtarget`) as your working directory.