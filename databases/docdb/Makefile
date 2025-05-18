# DocumentDB Investigation Commands
# Note: These commands require AWS CLI and MongoDB Shell to be installed

# Required environment variable: CLUSTER_NAME (e.g., docdb-2025-05-17-08-21-41)

# Helper functions to get cluster information
define get_instance_id
$(shell aws docdb describe-db-clusters --db-cluster-identifier $(CLUSTER_NAME) --query 'DBClusters[0].DBClusterMembers[?IsClusterWriter==`true`].DBInstanceIdentifier' --output text)
endef

define get_cluster_endpoint
$(shell aws docdb describe-db-clusters --db-cluster-identifier $(CLUSTER_NAME) --query 'DBClusters[0].Endpoint' --output text)
endef

define get_cluster_port
$(shell aws docdb describe-db-clusters --db-cluster-identifier $(CLUSTER_NAME) --query 'DBClusters[0].Port' --output text)
endef

# Performance Insights Commands
pi-enable:
	@./scripts/pi-enable.sh $(CLUSTER_NAME)

pi-disable:
	@./scripts/pi-disable.sh $(CLUSTER_NAME)

# CloudWatch Metrics Commands
get-db-load:
	@echo "Getting DBLoad metrics for the last hour..."
	aws cloudwatch get-metric-statistics \
		--namespace AWS/DocDB \
		--metric-name DBLoad \
		--period 360 \
		--statistics Average \
		--start-time `date -u --date="1 hour ago" "+%Y-%m-%dT%H:%M:%SZ"` \
		--end-time `date -u "+%Y-%m-%dT%H:%M:%SZ"` \
		--dimensions Name=DBInstanceIdentifier,Value=$(call get_instance_id)

get-cpu-metrics:
	@echo "Getting CPU utilization metrics..."
	aws cloudwatch get-metric-statistics \
		--namespace AWS/DocDB \
		--metric-name CPUUtilization \
		--period 360 \
		--statistics Average \
		--start-time `date -u --date="1 hour ago" "+%Y-%m-%dT%H:%M:%SZ"` \
		--end-time `date -u "+%Y-%m-%dT%H:%M:%SZ"` \
		--dimensions Name=DBInstanceIdentifier,Value=$(call get_instance_id)

# Database Operations Analysis Commands
show-current-ops:
	@echo "Showing current operations..."
	mongosh "mongodb://$(call get_cluster_endpoint):$(call get_cluster_port)" --eval "db.adminCommand({currentOp: 1, \$$all: true})"

show-slow-ops:
	@echo "Showing operations running longer than 10 seconds..."
	mongosh "mongodb://$(call get_cluster_endpoint):$(call get_cluster_port)" --eval 'db.adminCommand({aggregate: 1, pipeline: [{$$currentOp: {}}, {$$match: {$$or: [{secs_running: {$$gt: 10}}, {WaitState: {$$exists: true}}]}}, {$$project: {_id:0, opid: 1, secs_running: 1, WaitState: 1, blockedOn: 1, command: 1}}], cursor: {}})'

show-ops-by-namespace:
	@echo "Showing operations aggregated by namespace..."
	mongosh "mongodb://$(call get_cluster_endpoint):$(call get_cluster_port)" --eval 'db.adminCommand({aggregate: 1, pipeline: [{$$currentOp: {allUsers: true, idleConnections: true}}, {$$group: {_id: {desc: "$$desc", ns: "$$ns", WaitState: "$$WaitState"}, count: {$$sum: 1}}}], cursor: {}})'

# Index Analysis Commands
show-index-stats:
	@echo "Showing index statistics for database $(db_name) and collection $(collection_name)..."
	mongosh "mongodb://$(call get_cluster_endpoint):$(call get_cluster_port)/$(db_name)" --eval "db.$(collection_name).aggregate([{\\$$indexStats: {}}])"

show-collection-stats:
	@echo "Showing collection statistics for database $(db_name) and collection $(collection_name)..."
	mongosh "mongodb://$(call get_cluster_endpoint):$(call get_cluster_port)/$(db_name)" --eval "db.$(collection_name).stats()"

# Performance Insights API Commands
get-pi-key:
	@./scripts/get-pi-key.sh $(CLUSTER_NAME)

get-counter-metrics:
	@./scripts/get-counter-metrics.sh $(CLUSTER_NAME)

list-available-dimensions:
	@echo "利用可能なディメンション:"
	@echo "  - db.wait_state    (待機状態によるロードの分析)"
	@echo "  - db.user          (データベースユーザー別の分析)"
	@echo "  - db.host          (クライアントホスト別の分析)"
	@echo "  - db.query         (SQLクエリ別の分析)"
	@echo "  - db.application   (アプリケーション別の分析)"
	@echo "  - db.session_type  (セッションタイプ別の分析)"

get-dimension-metrics:
	@if [ -z "$(dimension)" ]; then \
		echo "エラー: dimension パラメータが必要です"; \
		echo "使用例: CLUSTER_NAME=your-cluster make get-dimension-metrics dimension=db.wait_state"; \
		exit 1; \
	fi
	@./scripts/get-dimension-metrics.sh $(CLUSTER_NAME) $(dimension)

get-detailed-metrics:
	@./scripts/get-detailed-metrics.sh $(CLUSTER_NAME)

# Resource Metrics Commands
get-resource-metrics:
	@./scripts/get-resource-metrics.sh $(CLUSTER_NAME)

get-top-wait-states:
	@./scripts/get-top-wait-states.sh $(CLUSTER_NAME)

# Connection Command
connect:
	@if [ -z "$(DOCDB_USERNAME)" ] || [ -z "$(DOCDB_PASSWORD)" ]; then \
		echo "エラー: DOCDB_USERNAME と DOCDB_PASSWORD 環境変数が必要です"; \
		echo "使用例: DOCDB_USERNAME=username DOCDB_PASSWORD=password CLUSTER_NAME=your-cluster make connect"; \
		exit 1; \
	fi
	@./scripts/connect-docdb.sh $(CLUSTER_NAME)

# Help
help:
	@echo "DocumentDB Investigation Commands"
	@echo ""
	@echo "Usage: CLUSTER_NAME=<cluster-name> make <command> [db_name=<db>] [collection_name=<collection>]"
	@echo ""
	@echo "Environment Variables:"
	@echo "  CLUSTER_NAME        - DocumentDB cluster identifier (e.g., docdb-2025-05-17-08-21-41)"
	@echo "  db_name            - Database name (required for index and collection commands)"
	@echo "  collection_name    - Collection name (required for index and collection commands)"
	@echo ""
	@echo "Available commands:"
	@echo "  pi-enable            - Enable Performance Insights"
	@echo "  pi-disable           - Disable Performance Insights"
	@echo "  get-db-load          - Get DBLoad metrics from CloudWatch"
	@echo "  get-cpu-metrics      - Get CPU utilization metrics"
	@echo "  show-current-ops     - Show current operations"
	@echo "  show-slow-ops        - Show operations running > 10s"
	@echo "  show-ops-by-namespace - Show operations by namespace"
	@echo "  show-index-stats     - Show index statistics (requires db_name and collection_name)"
	@echo "  show-collection-stats - Show collection statistics (requires db_name and collection_name)"
	@echo "  get-resource-metrics  - Get resource metrics from Performance Insights"
	@echo "  get-top-wait-states   - Get top wait states from Performance Insights"
	@echo "  get-pi-key           - Get Performance Insights API key"
	@echo "  get-counter-metrics  - Get counter metrics (blocks read/hit, transactions)"
	@echo "  get-dimension-metrics - Get metrics by dimension (requires dimension parameter)"
	@echo "  get-detailed-metrics - Get detailed performance metrics (CPU, memory, etc.)"
	@echo "  connect             - Connect to DocumentDB using mongosh (requires DOCDB_USERNAME and DOCDB_PASSWORD)"
	@echo ""
	@echo "Example:"
	@echo "  CLUSTER_NAME=docdb-2025-05-17-08-21-41 make get-cpu-metrics"
	@echo "  CLUSTER_NAME=docdb-2025-05-17-08-21-41 make show-index-stats db_name=mydb collection_name=users"
