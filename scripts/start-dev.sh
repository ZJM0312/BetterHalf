#!/bin/bash

# BetterHalf 开发环境启动脚本
# 使用方法: ./scripts/start-dev.sh

set -e

echo "================================================"
echo "🚀 BetterHalf 开发环境启动"
echo "================================================"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 启动依赖服务
echo "📦 启动 PostgreSQL 和 Redis..."
docker-compose up -d postgres redis

# 等待服务就绪
echo "⏳ 等待服务就绪..."
sleep 5

# 检查服务状态
echo ""
echo "🔍 检查服务状态:"

# PostgreSQL
if docker exec betterhalf-postgres pg_isready -U betterhalf > /dev/null 2>&1; then
    echo "  ✓ PostgreSQL 运行中 (localhost:5432)"
else
    echo "  ✗ PostgreSQL 未就绪"
fi

# Redis
if docker exec betterhalf-redis redis-cli ping > /dev/null 2>&1; then
    echo "  ✓ Redis 运行中 (localhost:6379)"
else
    echo "  ✗ Redis 未就绪"
fi

echo ""
echo "================================================"
echo "✅ 依赖服务已启动!"
echo ""
echo "📝 下一步:"
echo ""
echo "1. 启动后端 (终端 1):"
echo "   cd backend"
echo "   ./mvnw spring-boot:run -pl betterhalf-api"
echo ""
echo "2. 启动前端 (终端 2):"
echo "   cd frontend"
echo "   npm install && npm run dev"
echo ""
echo "3. 访问:"
echo "   - 前端: http://localhost:3000"
echo "   - 后端 API: http://localhost:8080/api/v1"
echo "   - Swagger: http://localhost:8080/swagger-ui.html"
echo "   - 测试页: http://localhost:3000/test"
echo ""
echo "4. 运行 API 测试:"
echo "   ./scripts/test-api.sh"
echo ""
echo "================================================"
