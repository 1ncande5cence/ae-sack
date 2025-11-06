## Oracle Generation

This directory contains the full codebase and original experimental data used for oracle generation.

### Reproducing Existing Results

To reproduce results for a specific target program:

1. Navigate to the corresponding folder:
   ```
   cd oracle_generation_{target_program}
   ```
2. Follow the instructions in `./oracle_generation_{target_program}/README.md` file.

### Testing a New Program

To test the oracle generation pipeline on a new target program:

1. Copy the template directory:
   ```bash
   cp -r oracle_generation_template oracle_generation_newtarget
   ```
2. Use the new folder (`oracle_generation_newtarget`) as your working directory.