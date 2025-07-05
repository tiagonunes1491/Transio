#!/bin/bash

# Frontend Test Runner for Transio
# This script runs the organized frontend test suite

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to frontend directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
cd "$FRONTEND_DIR"

echo -e "${BLUE}🚀 Transio Frontend Test Suite${NC}"
echo "================================="
echo "Frontend directory: $FRONTEND_DIR"
echo ""

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Error: Node.js is not installed${NC}"
    exit 1
fi

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ Error: npm is not available${NC}"
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    npm install
    echo ""
fi

# Function to run tests with category
run_test_category() {
    local category=$1
    local description=$2
    local path=$3
    
    echo -e "${BLUE}Running $description...${NC}"
    if npm test -- --testPathPattern="$path" --silent; then
        echo -e "${GREEN}✅ $description passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $description failed${NC}"
        return 1
    fi
}

# Parse command line arguments
case "${1:-all}" in
    "unit")
        echo -e "${YELLOW}Running unit tests only...${NC}"
        echo ""
        run_test_category "unit" "Unit Tests" "tests/unit/"
        ;;
    "security")
        echo -e "${YELLOW}Running security tests only...${NC}"
        echo ""
        run_test_category "security" "Security Tests" "tests/security/"
        ;;
    "all"|"")
        echo -e "${YELLOW}Running all tests...${NC}"
        echo ""
        
        # Track results
        failed_tests=0
        
        # Run unit tests
        if ! run_test_category "unit" "Unit Tests" "tests/unit/"; then
            failed_tests=$((failed_tests + 1))
        fi
        echo ""
        
        # Run security tests
        if ! run_test_category "security" "Security Tests" "tests/security/"; then
            failed_tests=$((failed_tests + 1))
        fi
        echo ""
        
        # Summary
        echo "================================="
        if [ $failed_tests -eq 0 ]; then
            echo -e "${GREEN}🎉 All test categories passed!${NC}"
            echo ""
            echo "Running complete test suite for final verification..."
            npm test
        else
            echo -e "${RED}❌ $failed_tests test category(ies) failed${NC}"
            exit 1
        fi
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [CATEGORY]"
        echo ""
        echo "Categories:"
        echo "  unit      - Run unit tests only (core functionality)"
        echo "  security  - Run security tests only (penetration testing)"
        echo "  all       - Run all tests (default)"
        echo "  help      - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                # Run all tests"
        echo "  $0 unit          # Run only unit tests"
        echo "  $0 security      # Run only security tests"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Unknown test category: $1${NC}"
        echo "Use '$0 help' to see available options"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ Frontend tests completed successfully${NC}"