# ==============================================================================
# xChat AP 2026 - Database Automation & Verification Makefile
# Author: Kushal Garg (kshlgrg) · Enrollment No.: 2501010241
# ==============================================================================

PGHOST ?= localhost
PGPORT ?= 5432
PGUSER ?= postgres
PGDATABASE ?= xchat_db

PSQL = psql -h $(PGHOST) -p $(PGPORT) -U $(PGUSER) -d $(PGDATABASE)

.PHONY: all help init-db schema seed test queries check clean

help:
	@echo "======================================================================"
	@echo " xChat AP 2026 Database Management Makefile"
	@echo "======================================================================"
	@echo "Targets:"
	@echo "  init-db       - Create database $(PGDATABASE) if not exists"
	@echo "  schema        - Execute dbms/03_schema.sql (DDL & constraints)"
	@echo "  seed          - Load dbms/06_seed_data.sql into xchat schema"
	@echo "  test          - Run tests/test_xchat_integrity.sql test suite"
	@echo "  queries       - Execute dbms/04_queries.sql workload (R1-R10, W1-W8)"
	@echo "  check         - Run schema -> seed -> test in sequence"
	@echo "  clean         - Drop xchat schema"
	@echo "======================================================================"

init-db:
	@echo "Creating database $(PGDATABASE) if necessary..."
	@psql -h $(PGHOST) -p $(PGPORT) -U $(PGUSER) -tc "SELECT 1 FROM pg_database WHERE datname = '$(PGDATABASE)'" | grep -q 1 || \
		psql -h $(PGHOST) -p $(PGPORT) -U $(PGUSER) -c "CREATE DATABASE $(PGDATABASE);"

schema:
	@echo "Deploying xChat Schema (dbms/03_schema.sql)..."
	@$(PSQL) -f dbms/03_schema.sql

seed:
	@echo "Seeding initial dataset (dbms/06_seed_data.sql)..."
	@$(PSQL) -f dbms/06_seed_data.sql

test:
	@echo "Executing integrity validation suite (tests/test_xchat_integrity.sql)..."
	@$(PSQL) -f tests/test_xchat_integrity.sql

queries:
	@echo "Running sample workload queries (dbms/04_queries.sql)..."
	@$(PSQL) -f dbms/04_queries.sql

check: schema seed test
	@echo "All database checks passed successfully!"

clean:
	@echo "Dropping xchat schema..."
	@$(PSQL) -c "DROP SCHEMA IF EXISTS xchat CASCADE;"
