# Oracle Constructor Instruction Guide

This guide walks you through the steps for constructing an oracle using our pipeline. The process includes feature identification, document preparation, and oracle generation.
Some steps require an `OPENAI_API_KEY` and API cost (As shown in **TABLE II**). However, to ease reproduction, we have included intermediate results so you can skip or reuse certain stages without re-querying the LLM.

---

## Step 1: Feature Identification *(Requires `OPENAI_API_KEY`)*

This step extracts candidate security features from your target program using few-shot LLM queries.

### Detailed Steps

1. Configure the target program:  
   Set the `TARGET_PROG` field in `config.json`. *(Already preconfigured)*

2. Export your OpenAI API key:

   ```bash
   export OPENAI_API_KEY="your-key-here"
   ```

3. Run the feature query script:

   ```bash
   python3 feature_query.py
   ```

### Input and Output

- **Input**: `TARGET_PROG` field in `config.json`  
- **Output**: `./feature_output/`

### Note

We have provided precomputed results in `./feature_output/`, so you can proceed to later steps without this step.

---

## Step 2: Document Preparation

### 2.1 info collect
This step uses a crawler to fetch the documentation from the `START_URL`.

#### Detailed Steps

1. Set `START_URL` in `config.json`. *(Already preconfigured)*
2. Run the crawler:

   ```bash
   python3 general_crawler.py
   ```
3.	In the Nginx documentation, we observed a special case: directly crawling pages under https://nginx.org/en/docs/http/ consistently results in 404 Not Found. To address this, we begin crawling from the broader root https://nginx.org/en/docs/ and then filter out irrelevant files to reduce the crawling cost. Please refer to the /metadata directory for the corresponding experimental results.

4. Based on item 3, to reproduce our results, please reuse our downloaded documentation by running:

   ```bash
   rm -rf downloaded_docs
   cp -r ./metadata/downloaded_docs .
   ```
   and then continue with the following steps.


#### Input and Output

- **Input**: `START_URL`  
- **Output**: `./downloaded_docs/`

---

### 2.2 preprocess

This step removes non-content elements such as navigation bars, layout structures, and scripts.

```bash
python3 extract_text.py
```

- **Input**: `./downloaded_docs/`  
- **Output**: `./downloaded_txt/`

---

### 2.3 filtering

This step performs keyword-based filtering to retain only security-related documents.

```bash
python3 security_filter.py
```

- **Input**: `./downloaded_txt/`  
- **Output**: `./security_txt/`

---

## Step 3: Oracle Generation *(Requires `OPENAI_API_KEY`)*

Use the identified features and filtered documentation to generate a task-specific oracle.

### Detailed Steps

1. List available feature JSON files and choose one to use  
   (either the pre-generated version we provide or the one you produced in **Step 1**):

   ```bash
   ls ./feature_output/
   ```
   Select the desired JSON file and use it as a CLI argument in the next step.

2. Generate the oracle using the selected feature, run:

   ```bash
   python3 oracle_generation_with_provided_feature.py --feature-json feature_output/nginx_features.json
   ```

### Input and Output

- **Input**: `feature_output/*.json`, `./security_txt/`  
- **Output**: `./oracle_generation_with_provided_feature/`

The generated oracles are in `./oracle_generation_with_provided_feature/`


---

## Metadata

The `./metadata` directory stores all original data produced during the evaluation process described above.

After Step 1: `./metadata/feature_output`  
After Step 2.1: `./metadata/downloaded_docs`  
After Step 2.2: `./metadata/downloaded_txt`  
After Step 2.3: `./metadata/security_txt`  
After Step 3: `./metadata/oracle_generation_with_provided_feature`

For the oracle we generated in `./metadata/oracle_generation_with_provided_feature`, we select a representative subset of these features for evaluation, as mentioned in VI.B.

**Features for evaluation**  
N1 comes from `1_HTTP_Basic_Authentication_20250716_170302.md`  
N2 comes from `5_Request_Rate_Limiting_20250716_170431.md`  
N3 comes from `9_Web_Application_Firewall_(WAF)_Integration_20250716_170558.md`  
N4 comes from `12_Request_Method_Restrictions_20250716_170636.md`  
N5 comes from `10_Logging_and_Auditing_20250716_170602.md`  
N6 comes from `3_TLS_SSL_Encryption_20250716_170347.md`

The generated oracles are then tested manually and the quality is evaluated 
based on compilation flags, configuration directives, extra commands, legal/illegal input/out and final judgement.

## Optional: Error Handling and Refinement

1. Paste relevant information into `single_query_prompt.txt`
2. Run:

   ```bash
   python3 single_query.py
   ```

3. Check results in `./single_query/`

