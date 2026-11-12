#!/bin/bash

# BetterHalf API 测试脚本
# 使用方法: ./scripts/test-api.sh

set -e

BASE_URL="http://localhost:8080"
COOKIES_FILE="/tmp/betterhalf-cookies.txt"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "🧪 BetterHalf API 测试"
echo "================================================"
echo ""

# 清理旧 cookie
rm -f $COOKIES_FILE

# 测试函数
test_endpoint() {
    local name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected_code=$5
    
    echo -n "测试: $name ... "
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -b $COOKIES_FILE \
            -c $COOKIES_FILE \
            -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$endpoint" \
            -b $COOKIES_FILE \
            -c $COOKIES_FILE)
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" == "$expected_code" ]; then
        echo -e "${GREEN}✓ 通过${NC} (HTTP $http_code)"
        if [ -n "$body" ]; then
            echo "  响应: $(echo $body | head -c 100)..."
        fi
        return 0
    else
        echo -e "${RED}✗ 失败${NC} (期望 $expected_code, 实际 $http_code)"
        echo "  响应: $body"
        return 1
    fi
}

# 1. 健康检查
echo ""
echo "📋 1. 基础连接测试"
echo "-------------------"

test_endpoint "健康检查 (Actuator)" "GET" "/actuator/health" "" "200"
test_endpoint "API 健康检查" "GET" "/api/v1/health" "" "200"

# 2. 认证测试
echo ""
echo "🔐 2. 认证测试"
echo "--------------"

TEST_EMAIL="test$(date +%s)@example.com"
TEST_PASSWORD="TestPassword123!"

# 注册
REGISTER_DATA="{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"name\":\"Test User\"}"
test_endpoint "用户注册" "POST" "/api/v1/auth/register" "$REGISTER_DATA" "201"

# 获取当前用户
test_endpoint "获取当前用户" "GET" "/api/v1/auth/me" "" "200"

# 登出
test_endpoint "登出" "POST" "/api/v1/auth/logout" "" "204"

# 登录
LOGIN_DATA="{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}"
test_endpoint "用户登录" "POST" "/api/v1/auth/login" "$LOGIN_DATA" "200"

# 3. Couple 测试
echo ""
echo "💑 3. Couple 测试"
echo "-----------------"

# 创建 Couple
COUPLE_DATA='{"name":"Test Couple","visibility":"PRIVATE"}'
echo -n "测试: 创建 Couple ... "
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/couples" \
    -H "Content-Type: application/json" \
    -b $COOKIES_FILE \
    -c $COOKIES_FILE \
    -d "$COUPLE_DATA")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" == "201" ]; then
    echo -e "${GREEN}✓ 通过${NC} (HTTP $http_code)"
    COUPLE_ID=$(echo $body | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "  Couple ID: $COUPLE_ID"
else
    echo -e "${RED}✗ 失败${NC} (HTTP $http_code)"
    echo "  响应: $body"
    exit 1
fi

# 获取我的 Couples
test_endpoint "获取我的 Couples" "GET" "/api/v1/couples/me" "" "200"

# 获取单个 Couple
test_endpoint "获取 Couple 详情" "GET" "/api/v1/couples/$COUPLE_ID" "" "200"

# 4. Event 测试
echo ""
echo "📅 4. Event 测试"
echo "----------------"

# 创建 Event
EVENT_DATA='{"title":"First Date","description":"Our first date","eventDate":"2024-01-15"}'
echo -n "测试: 创建 Event ... "
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1/couples/$COUPLE_ID/events" \
    -H "Content-Type: application/json" \
    -b $COOKIES_FILE \
    -c $COOKIES_FILE \
    -d "$EVENT_DATA")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" == "201" ]; then
    echo -e "${GREEN}✓ 通过${NC} (HTTP $http_code)"
    EVENT_ID=$(echo $body | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "  Event ID: $EVENT_ID"
else
    echo -e "${RED}✗ 失败${NC} (HTTP $http_code)"
    echo "  响应: $body"
fi

# 获取 Events 列表
test_endpoint "获取 Events 列表" "GET" "/api/v1/couples/$COUPLE_ID/events" "" "200"

# 获取单个 Event
if [ -n "$EVENT_ID" ]; then
    test_endpoint "获取 Event 详情" "GET" "/api/v1/couples/$COUPLE_ID/events/$EVENT_ID" "" "200"
    
    # 更新 Event
    UPDATE_DATA='{"title":"Updated Title"}'
    test_endpoint "更新 Event" "PUT" "/api/v1/couples/$COUPLE_ID/events/$EVENT_ID" "$UPDATE_DATA" "200"
    
    # 删除 Event
    test_endpoint "删除 Event" "DELETE" "/api/v1/couples/$COUPLE_ID/events/$EVENT_ID" "" "204"
fi

# 5. 错误处理测试
echo ""
echo "⚠️  5. 错误处理测试"
echo "-------------------"

# 无效登录
INVALID_LOGIN='{"email":"invalid@example.com","password":"wrong"}'
test_endpoint "无效登录 (应返回错误)" "POST" "/api/v1/auth/login" "$INVALID_LOGIN" "400"

# 未授权访问
rm -f $COOKIES_FILE
test_endpoint "未授权访问 (应返回 401/403)" "GET" "/api/v1/couples/me" "" "403"

# 汇总
echo ""
echo "================================================"
echo -e "${GREEN}✓ 测试完成!${NC}"
echo "================================================"
echo ""
echo "📝 更多测试选项:"
echo "  - Swagger UI: http://localhost:8080/swagger-ui.html"
echo "  - 前端测试页: http://localhost:3000/test"
echo ""

# 清理
rm -f $COOKIES_FILE
