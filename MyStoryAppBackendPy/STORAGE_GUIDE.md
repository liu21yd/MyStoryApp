# 可配置存储系统

支持本地存储和阿里云 OSS 云存储无缝切换

## 快速配置

### 方式一：本地存储（开发测试）

```bash
# .env
STORAGE_TYPE=local
UPLOAD_DIR=./uploads
OUTPUT_DIR=./output
```

### 方式二：阿里云 OSS（生产环境）

```bash
# .env
STORAGE_TYPE=oss
OSS_ACCESS_KEY_ID=your-access-key-id
OSS_ACCESS_KEY_SECRET=your-access-key-secret
OSS_ENDPOINT=oss-cn-beijing.aliyuncs.com
OSS_BUCKET=your-bucket-name
OSS_CUSTOM_DOMAIN=cdn.yourdomain.com  # 可选，用于 CDN 加速
```

## 阿里云 OSS 配置步骤

### 1. 创建 OSS Bucket

1. 登录阿里云控制台: https://oss.console.aliyun.com/
2. 点击「创建 Bucket」
3. 配置：
   - Bucket 名称: `mystoryapp` (全局唯一)
   - 地域: 选择离你服务器最近的（如华东1-杭州）
   - 存储类型: 标准存储
   - 读写权限: **公共读**（重要，否则图片无法访问）

### 2. 获取 AccessKey

1. 点击右上角头像 → AccessKey 管理
2. 创建 AccessKey
3. 保存 `AccessKey ID` 和 `AccessKey Secret`

### 3. 配置 CDN（可选）

1. 在 OSS Bucket → 传输管理 → 域名管理
2. 绑定自定义域名（如 `cdn.yourdomain.com`）
3. 添加 CNAME 解析
4. 开启 CDN 加速

## 代码使用示例

```python
from app.services.storage import get_storage

# 获取存储服务（根据配置自动选择）
storage = get_storage()

# 上传文件
file_url = await storage.upload_file(
    local_path="/path/to/local/file.jpg",
    filename="user_123_image.jpg",
    content_type="image/jpeg"
)

# 上传字节数据
file_url = await storage.upload_from_bytes(
    data=image_bytes,
    filename="image.jpg",
    content_type="image/jpeg"
)

# 删除文件
success = await storage.delete_file(file_url)

# 获取带签名的临时 URL
temp_url = await storage.get_file_url("image.jpg", expire=3600)
```

## 存储路径规则

### 本地存储
```
uploads/
├── {user_id}/
│   ├── {uuid}.jpg       # 用户上传的图片
│   └── {uuid}.png
```

### OSS 存储
```
oss://{bucket}/
├── uploads/
│   ├── 2024/02/09/
│   │   ├── {user_id}_{uuid}.jpg
│   │   └── {user_id}_{uuid}.png
```

## 两种存储方式对比

| 特性 | 本地存储 | 阿里云 OSS |
|------|----------|------------|
| 成本 | 低（磁盘空间） | 按量付费 |
| 可靠性 | 依赖服务器磁盘 | 99.995% SLA |
| 访问速度 | 依赖服务器带宽 | CDN 全球加速 |
| 容量限制 | 受磁盘限制 | 无限扩容 |
| 备份恢复 | 需自行实现 | 自动多副本 |
| 图片处理 | 需自行实现 | 自带图片处理 |
| HTTPS | 需自行配置 | 自带 HTTPS |

## 迁移数据

从本地迁移到 OSS：

```bash
# 使用 ossutil 工具
ossutil cp -r ./uploads oss://your-bucket/uploads/

# 或编写脚本调用 API
python scripts/migrate_to_oss.py
```

## 故障排查

### OSS 上传失败

```bash
# 检查配置
echo $OSS_ACCESS_KEY_ID
echo $OSS_BUCKET

# 测试连接
python -c "
import oss2
auth = oss2.Auth('your-key', 'your-secret')
bucket = oss2.Bucket(auth, 'oss-cn-beijing.aliyuncs.com', 'your-bucket')
print(bucket.get_bucket_info())
"
```

### 文件访问 403

1. 检查 Bucket 权限是否为「公共读」
2. 检查是否有 Bucket Policy 限制
3. 检查 Referer 防盗链设置

## 最佳实践

1. **开发环境**：使用本地存储，快速方便
2. **测试环境**：使用 OSS，验证生产流程
3. **生产环境**：使用 OSS + CDN，保证速度和可靠性
4. **备份策略**：OSS 开启版本控制，防止误删
5. **成本控制**：设置生命周期规则，自动清理旧文件
