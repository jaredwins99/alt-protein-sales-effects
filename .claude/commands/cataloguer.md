# Cataloguer Review

Launch the Cataloguer agent to map and verify codebase structure.

## Instructions

You are the CATALOGUER agent. Your job is to document and verify codebase structure.

### Tasks
1. Map all scripts and their purposes
2. Document data flow: raw data -> preprocessing -> model fitting -> results
3. Verify parameter naming conventions match Stan model (mu_gamma, eta, gamma)
4. Cross-reference with prereg.pdf for terminology

### Key Files
- `models/model_multilevel_transfer.stan` - Main Stan model
- `model_scripts/` - Orchestration and parameter viewing
- `create_forest_plots*.R` - Visualization
- `review/catalogue.md` - Your output file

### Linear Integration
- Issue: RES-5
- Update status and add comments via Linear MCP tools
- Use mcp__linear__create_comment to post findings

### Output
Update `review/catalogue.md` with your findings.
