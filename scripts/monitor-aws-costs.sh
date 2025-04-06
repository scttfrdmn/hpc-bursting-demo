#!/bin/bash
# Monitor AWS costs for HPC bursting
set -e

AWS_REGION="us-west-2"  # Use your region

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Get current month usage
get_month_usage() {
  local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
  local end_date=$(date -d "$(date -d "next month" +%Y-%m-01) - 1 day" +%Y-%m-%d)
  
  log "Getting cost data from $start_date to $end_date"
  
  aws ce get-cost-and-usage \
    --time-period Start=$start_date,End=$end_date \
    --granularity MONTHLY \
    --metrics "BlendedCost" "UsageQuantity" \
    --group-by Type=DIMENSION,Key=SERVICE \
    --region $AWS_REGION
}

# Get EC2 instance usage
get_ec2_usage() {
  local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
  local end_date=$(date -d "$(date -d "next month" +%Y-%m-01) - 1 day" +%Y-%m-%d)
  
  log "Getting EC2 usage data from $start_date to $end_date"
  
  aws ce get-cost-and-usage \
    --time-period Start=$start_date,End=$end_date \
    --granularity DAILY \
    --metrics "BlendedCost" "UsageQuantity" \
    --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Compute Cloud - Compute"]}}' \
    --group-by Type=DIMENSION,Key=INSTANCE_TYPE \
    --region $AWS_REGION
}

# Get data for HPC bursting tag
get_hpc_bursting_cost() {
  local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
  local end_date=$(date -d "$(date -d "next month" +%Y-%m-01) - 1 day" +%Y-%m-%d)
  
  log "Getting HPC bursting tag cost data from $start_date to $end_date"
  
  aws ce get-cost-and-usage \
    --time-period Start=$start_date,End=$end_date \
    --granularity MONTHLY \
    --metrics "BlendedCost" "UsageQuantity" \
    --filter '{"Tags": {"Key": "Project", "Values": ["HPC-Bursting-Demo"]}}' \
    --group-by Type=DIMENSION,Key=SERVICE \
    --region $AWS_REGION
}

# Create a cost report
create_report() {
  log "Creating cost report"
  
  echo "===================================="
  echo "      HPC BURSTING COST REPORT      "
  echo "===================================="
  echo ""
  
  echo "EC2 Instance Usage by Type:"
  get_ec2_usage | jq -r '.ResultsByTime[].Groups[] | "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount)"' | sort -k2 -nr
  
  echo ""
  echo "Total AWS Services Cost This Month:"
  get_month_usage | jq -r '.ResultsByTime[].Groups[] | "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount)"' | sort -k2 -nr
  
  echo ""
  echo "HPC Bursting Project Cost (if tagged):"
  get_hpc_bursting_cost | jq -r '.ResultsByTime[].Total.BlendedCost | "Total: $\(.Amount)"' || echo "No data available - please ensure resources are tagged"
}

# Main execution
create_report > hpc-bursting-cost-report.txt
log "Cost report saved to hpc-bursting-cost-report.txt"
cat hpc-bursting-cost-report.txt
