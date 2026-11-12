# BetterHalf 测试方案

## 一、环境准备

### 1. 数据库 (PostgreSQL)

```bash
# macOS 使用 Homebrew
brew install postgresql@14
brew services start postgresql@14

# 创建数据库
createdb betterhalf

# 或使用 Docker
docker run -d --name betterhalf-postgres \
  -e POSTGRES_DB=betterhalf \
  -e POSTGRES_USER=betterhalf \
  -e POSTGRES_PASSWORD=betterhalf \
  -p 5432:5432 \
  postgres:14-alpine
```

### 2. Redis

```bash
# macOS 使用 Homebrew
brew install redis
brew services start redis

# 或使用 Docker
docker run -d --name betterhalf-redis \
  -p 6379:6379 \
  redis:7-alpine
```

### 3. 环境变量

创建 `backend/betterhalf-api/src/main/resources/application-dev.yml`:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/betterhalf
    username: betterhalf
    password: betterhalf

betterhalf:
  auth:
    jwt-secret: dev-secret-key-minimum-32-characters-long
    cookie-secure: false
```

---

## 二、启动服务

### 终端 1: 启动后端

```bash
cd backend
./mvnw spring-boot:run -pl betterhalf-api -Dspring-boot.run.profiles=dev
```

等待看到:
```
Started BetterHalfApplication in X.XXX seconds
```

### 终端 2: 启动前端

```bash
cd frontend
npm install
npm run dev
```

等待看到:
```
▲ Next.js 14.0.4
- Local: http://localhost:3000
```

---

## 三、测试方案

### A. 后端 API 测试

#### 1. 健康检查

```bash
# 健康端点
curl http://localhost:8080/actuator/health

# 预期响应
{"status":"UP"}
```

#### 2. Swagger UI 测试

打开浏览器访问: http://localhost:8080/swagger-ui.html

可以在 Swagger UI 中测试所有 API 端点。

#### 3. cURL 命令测试

```bash
# 1. 注册用户
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "email": "test@example.com",
    "password": "TestPassword123!",
    "name": "Test User"
  }'

# 预期响应
{
  "id": "uuid",
  "email": "test@example.com",
  "name": "Test User",
  "accessToken": "jwt_token"
}

# 2. 登录
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "email": "test@example.com",
    "password": "TestPassword123!"
  }'

# 3. 获取当前用户 (使用 cookie)
curl http://localhost:8080/api/v1/auth/me \
  -b cookies.txt

# 4. 创建 Couple
curl -X POST http://localhost:8080/api/v1/couples \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "name": "John & Jane",
    "visibility": "PRIVATE"
  }'

# 5. 创建 Event (替换 {coupleId})
curl -X POST http://localhost:8080/api/v1/couples/{coupleId}/events \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "title": "First Date",
    "description": "Our first date",
    "eventDate": "2024-01-15"
  }'

# 6. 获取 Events
curl http://localhost:8080/api/v1/couples/{coupleId}/events \
  -b cookies.txt

# 7. 登出
curl -X POST http://localhost:8080/api/v1/auth/logout \
  -b cookies.txt
```

### B. 前后端集成测试

#### 1. 自动化测试页面

访问: http://localhost:3000/test

这个页面会自动运行以下测试:
1. ✅ 健康检查 - 验证后端连接
2. ✅ 用户注册 - 测试注册流程
3. ✅ 获取用户 - 测试认证 Cookie
4. ✅ 创建 Couple - 测试创建功能
5. ✅ 获取 Couples - 测试列表功能
6. ✅ 创建 Event - 测试事件创建
7. ✅ 获取 Events - 测试分页
8. ✅ 删除 Event - 测试删除
9. ✅ 登出 - 测试登出
10. ✅ 登录 - 测试登录流程

#### 2. 手动浏览器测试

打开浏览器开发者工具 (F12)，观察:
- **Network 标签**: 查看 API 请求/响应
- **Application 标签**: 查看 Cookies (access_token, refresh_token)
- **Console 标签**: 查看错误信息

### C. CORS 测试

```bash
# 测试 CORS 预检请求
curl -X OPTIONS http://localhost:8080/api/v1/auth/login \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -v

# 检查响应头包含:
# Access-Control-Allow-Origin: http://localhost:3000
# Access-Control-Allow-Credentials: true
```

### D. 认证流程测试

```bash
# 1. 获取 CSRF Token (可选，当前配置已禁用 auth 端点的 CSRF)
curl http://localhost:8080/api/v1/auth/login \
  -c cookies.txt \
  -v

# 2. 使用错误密码登录
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "wrong"}'

# 预期: 401 Unauthorized
{
  "code": "UNAUTHORIZED",
  "message": "Invalid credentials",
  "requestId": "uuid"
}

# 3. 未认证访问受保护端点
curl http://localhost:8080/api/v1/couples/me

# 预期: 401 或 403
```

### E. 速率限制测试

```bash
# 快速发送多个请求测试速率限制
for i in {1..110}; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    http://localhost:8080/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email": "test@example.com", "password": "test"}'
done

# 超过限制后应返回 429 Too Many Requests
# 响应头包含: X-RateLimit-Limit, X-RateLimit-Remaining, Retry-After
```

---

## 四、常见问题排查

### 1. 后端启动失败

**问题**: `Connection refused` 数据库连接失败

**解决**:
```bash
# 检查 PostgreSQL 运行状态
pg_isready -h localhost -p 5432

# 检查数据库存在
psql -U postgres -c "\l" | grep betterhalf
```

### 2. Redis 连接失败

**问题**: `Unable to connect to Redis`

**解决**:
```bash
# 检查 Redis 运行状态
redis-cli ping
# 应返回: PONG
```

### 3. CORS 错误

**问题**: `Access to fetch blocked by CORS policy`

**解决**:
- 确认前端运行在 `http://localhost:3000`
- 检查 `SecurityConfig.java` 中的 CORS 配置
- 清除浏览器缓存

### 4. Cookie 未设置

**问题**: 登录后无法访问受保护端点

**解决**:
- 检查浏览器 Application > Cookies
- 确认 `credentials: 'include'` 在 fetch 请求中
- 检查 `SameSite` 和 `Secure` cookie 设置

### 5. JWT 解析错误

**问题**: `JWT signature does not match`

**解决**:
- 确认 `JWT_SECRET` 环境变量一致
- 至少 32 字符长度
- 重新登录获取新 token

---

## 五、测试检查清单

### 后端测试 ✅

- [ ] 数据库连接正常
- [ ] Redis 连接正常
- [ ] 健康端点响应 UP
- [ ] Swagger UI 可访问
- [ ] 用户注册成功
- [ ] 用户登录成功
- [ ] JWT 认证工作
- [ ] Couple 创建成功
- [ ] Event CRUD 正常
- [ ] 速率限制生效

### 前端测试 ✅

- [ ] 页面正常加载
- [ ] API 请求发送正确
- [ ] CORS 无错误
- [ ] Cookie 正确设置
- [ ] 认证状态保持
- [ ] 错误信息显示

### 集成测试 ✅

- [ ] 完整注册流程
- [ ] 完整登录流程
- [ ] Token 刷新工作
- [ ] 登出清除状态
- [ ] 受保护路由正常

---

## 六、性能测试 (可选)

使用 `wrk` 或 `ab` 进行简单负载测试:

```bash
# 安装 wrk
brew install wrk

# 测试健康端点 (10 秒, 2 线程, 100 连接)
wrk -t2 -c100 -d10s http://localhost:8080/actuator/health

# 预期: 高 RPS, 低延迟
```

---

## 七、下一步

测试通过后，可以:

1. **构建完整 UI** - 创建登录、注册、仪表板页面
2. **添加单元测试** - 后端服务层测试
3. **添加 E2E 测试** - 使用 Playwright 或 Cypress
4. **配置 CI/CD** - GitHub Actions 自动化测试
