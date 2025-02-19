import logging
import boto3

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class CloudWatchMetricsHandler:
    """Handler for CloudWatch metrics operations"""

    def __init__(self, namespace: str = "CustomMetrics/AsyncInference"):
        self.namespace = namespace
        self.cloudwatch = boto3.client("cloudwatch")

    def put_backlog_metric(self, endpoint_name: str, backlog_size: int) -> None:
        """Update CloudWatch metrics for queue monitoring"""
        try:
            self.cloudwatch.put_metric_data(
                Namespace=self.namespace,
                MetricData=[
                    {
                        "MetricName": "ApproximateBacklogSizePerInstance",
                        "Value": backlog_size,
                        "Unit": "Count",
                        "Dimensions": [
                            {"Name": "EndpointName", "Value": endpoint_name}
                        ],
                    }
                ],
            )
        except Exception as e:
            logger.error(f"Error updating metrics: {str(e)}")
