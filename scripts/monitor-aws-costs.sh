#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Monitor AWS costs for HPC bursting
set -e

# Get the AWS region from environment or default to us-west-2
AWS_REGION=${AWS_REGION:-"us-west-2"}

# Parse command-line options
CHECK_RESOURCES=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --costs-only)
      CHECK_RESOURCES=false
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --costs-only   Only show cost information, not running resources"
      echo "  --help         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage"
      exit 1
      ;;
  esac
done

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Cross-platform date handling
get_date_range() {
  # Determine OS type for date command compatibility
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    local this_month=$(date "+%Y-%m")
    local start_date="${this_month}-01"
    
    # Calculate end of month (next month - 1 day)
    local next_month_year=$(date -j -f "%Y-%m-%d" "${this_month}-01" "+%Y")
    local next_month_month=$(($(date -j -f "%Y-%m-%d" "${this_month}-01" "+%m") % 12 + 1))
    if [ "$next_month_month" -eq 1 ]; then
      next_month_year=$((next_month_year + 1))
    fi
    local next_month=$(printf "%04d-%02d" "$next_month_year" "$next_month_month")
    local end_date=$(date -j -v-1d -f "%Y-%m-%d" "${next_month}-01" "+%Y-%m-%d")
  else
    # Linux and other Unix-like systems
    local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
    local end_date=$(date -d "$(date -d "next month" +%Y-%m-01) - 1 day" +%Y-%m-%d)
  fi
  
  echo "$start_date $end_date"
}

# Get active resources
check_active_resources() {
  log "Checking for active AWS resources..."
  
  echo "========================================"
  echo "       ACTIVE HPC DEMO RESOURCES        "
  echo "========================================"
  echo ""
  
  # Check running instances
  echo "EC2 INSTANCES:"
  instances=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=HPC-Bursting-Demo" "Name=instance-state-name,Values=pending,running" \
    --query "Reservations[].Instances[].[InstanceId,InstanceType,State.Name,LaunchTime]" \
    --output table \
    --region $AWS_REGION)
  
  if [ -z "$instances" ] || [ "$instances" == "[]" ]; then
    echo "No running instances found."
  else
    echo "$instances"
  fi
  echo ""
  
  # Check AMIs
  echo "CUSTOM AMIS:"
  amis=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=hpc-demo*" \
    --query "Images[].[ImageId,Name,CreationDate]" \
    --output table \
    --region $AWS_REGION)
  
  if [ -z "$amis" ] || [ "$amis" == "[]" ]; then
    echo "No custom AMIs found."
  else
    echo "$amis"
  fi
  echo ""
  
  # Check launch templates
  echo "LAUNCH TEMPLATES:"
  templates=$(aws ec2 describe-launch-templates \
    --filters "Name=launch-template-name,Values=hpc-demo*" \
    --query "LaunchTemplates[].[LaunchTemplateId,LaunchTemplateName,CreateTime]" \
    --output table \
    --region $AWS_REGION)
  
  if [ -z "$templates" ] || [ "$templates" == "[]" ]; then
    echo "No launch templates found."
  else
    echo "$templates"
  fi
  echo ""
  
  # Provide cleanup reminder
  echo "To clean up ALL AWS resources:"
  echo "  cd scripts/aws"
  echo "  ./cleanup_aws_resources.sh"
  echo ""
}

# Get current month usage
get_month_usage() {
  local date_range=($(get_date_range))
  local start_date=${date_range[0]}
  local end_date=${date_range[1]}
  
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
  local date_range=($(get_date_range))
  local start_date=${date_range[0]}
  local end_date=${date_range[1]}
  
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
  local date_range=($(get_date_range))
  local start_date=${date_range[0]}
  local end_date=${date_range[1]}
  
  log "Getting HPC bursting tag cost data from $start_date to $end_date"
  
  aws ce get-cost-and-usage \
    --time-period Start=$start_date,End=$end_date \
    --granularity DAILY \
    --metrics "BlendedCost" "UsageQuantity" \
    --filter '{"Tags": {"Key": "Project", "Values": ["HPC-Bursting-Demo"]}}' \
    --group-by Type=DIMENSION,Key=SERVICE \
    --region $AWS_REGION
}

# Create a cost report
create_cost_report() {
  log "Creating cost report"
  
  echo "========================================"
  echo "       HPC BURSTING COST REPORT         "
  echo "========================================"
  echo ""
  
  # Get usage by instance type
  echo "EC2 INSTANCE USAGE BY TYPE:"
  ec2_usage=$(get_ec2_usage 2>/dev/null)
  
  if [ $? -eq 0 ] && [ ! -z "$ec2_usage" ]; then
    echo "$ec2_usage" | jq -r '.ResultsByTime[].Groups[] | "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount)"' | sort -k2 -nr
  else
    echo "No EC2 cost data available (this may be normal if you haven't used EC2 this month)"
  fi
  
  echo ""
  echo "TOTAL AWS SERVICES COST THIS MONTH:"
  monthly_usage=$(get_month_usage 2>/dev/null)
  
  if [ $? -eq 0 ] && [ ! -z "$monthly_usage" ]; then
    echo "$monthly_usage" | jq -r '.ResultsByTime[].Groups[] | "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount)"' | sort -k2 -nr
  else
    echo "No monthly cost data available (this may require Cost Explorer to be enabled)"
  fi
  
  echo ""
  echo "HPC BURSTING PROJECT COST BY DAY:"
  project_cost=$(get_hpc_bursting_cost 2>/dev/null)
  
  if [ $? -eq 0 ] && [ ! -z "$project_cost" ] && [ "$(echo "$project_cost" | jq -r '.ResultsByTime[].Groups | length')" -gt 0 ]; then
    echo "$project_cost" | jq -r '.ResultsByTime[] | "\(.TimePeriod.Start): $\(.Total.BlendedCost.Amount)"' | sort
    
    # Also show total for the month
    total_cost=$(echo "$project_cost" | jq -r '.ResultsByTime[].Total.BlendedCost.Amount' | awk '{s+=$1} END {print s}')
    echo "------------------------------------------"
    echo "TOTAL PROJECT COST: \$$(printf "%.2f" $total_cost)"
  else
    echo "No tagged HPC Bursting Demo resources found"
    echo "To ensure proper cost tracking, all resources should be tagged with:"
    echo "  Key: Project, Value: HPC-Bursting-Demo"
  fi
  
  echo ""
  echo "NOTE: Cost data may be delayed by 24-48 hours"
  echo "Cost Explorer must be enabled to view this data"
  echo ""
}

# Main execution
output_file="hpc-bursting-report-$(date '+%Y-%m-%d').txt"

{
  if [ "$CHECK_RESOURCES" = true ]; then
    check_active_resources
  fi
  create_cost_report
} > "$output_file"

log "Report saved to $output_file"
cat "$output_file"
