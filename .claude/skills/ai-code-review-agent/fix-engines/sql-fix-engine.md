# SQL修复引擎

## 引擎信息
- **技术栈**: SQL
- **支持规则**: 1个
- **风险级别**: medium

## 支持规则列表

| 规则ID | 规则名称 | 风险级别 | 自动修复 |
|--------|----------|----------|----------|
| COMMON-PERF-002 | 深分页检查 | medium | ✅ |

---

## 规则修复实现

### 1. COMMON-PERF-002: 深分页检查

**风险级别**: medium

**修复策略**: `convert_to_cursor_pagination`

**检测模式**:
```regex
OFFSET\s+\d{5,}
```

**问题描述**:
当 OFFSET 值过大（如超过 10000）时，数据库需要扫描并跳过大量数据，导致性能急剧下降。

**修复逻辑**:
1. 检测深分页查询
2. 转换为基于游标的分页方式
3. 使用 WHERE 条件替代 OFFSET

**修复示例**:

```sql
-- ========== 修复前 ==========
-- 传统分页，OFFSET 100000 时性能极差
SELECT id, name, create_time
FROM orders
ORDER BY id
LIMIT 10 OFFSET 100000;

-- ========== 修复后 ==========
-- 游标分页，基于上次查询的最大ID
SELECT id, name, create_time
FROM orders
WHERE id > :last_id  -- 上次查询返回的最大ID
ORDER BY id
LIMIT 10;
```

**复杂排序场景**:

```sql
-- ========== 修复前 ==========
SELECT id, order_no, create_time
FROM orders
WHERE status = 1
ORDER BY create_time DESC, id DESC
LIMIT 10 OFFSET 50000;

-- ========== 修复后 ==========
-- 使用复合游标
SELECT id, order_no, create_time
FROM orders
WHERE status = 1
  AND (create_time < :last_create_time
       OR (create_time = :last_create_time AND id < :last_id))
ORDER BY create_time DESC, id DESC
LIMIT 10;
```

**MyBatis XML 示例**:

```xml
<!-- ========== 修复前 ========== -->
<select id="selectOrders" resultType="Order">
    SELECT id, order_no, create_time
    FROM orders
    WHERE status = #{status}
    ORDER BY id
    LIMIT #{pageSize} OFFSET #{offset}
</select>

<!-- ========== 修复后 ========== -->
<select id="selectOrdersByCursor" resultType="Order">
    SELECT id, order_no, create_time
    FROM orders
    WHERE status = #{status}
    <if test="lastId != null">
        AND id > #{lastId}
    </if>
    ORDER BY id
    LIMIT #{pageSize}
</select>
```

**修复代码模板**:
```python
def fix_deep_pagination(content, issue):
    """
    修复深分页问题
    """
    import re

    # 检测 OFFSET 模式
    offset_pattern = r'OFFSET\s+(\d+)'
    match = re.search(offset_pattern, content, re.IGNORECASE)

    if not match:
        return content

    offset_value = int(match.group(1))

    # 如果 OFFSET < 10000，不修复
    if offset_value < 10000:
        return content

    # 检测 ORDER BY
    order_pattern = r'ORDER\s+BY\s+(\w+(?:\s+(?:ASC|DESC))?(?:\s*,\s*\w+(?:\s+(?:ASC|DESC))?)*)'
    order_match = re.search(order_pattern, content, re.IGNORECASE)

    if not order_match:
        # 没有 ORDER BY，无法安全转换
        return content

    order_columns = parse_order_columns(order_match.group(1))

    # 检测 LIMIT
    limit_pattern = r'LIMIT\s+(\d+)'
    limit_match = re.search(limit_pattern, content, re.IGNORECASE)
    limit_value = limit_match.group(1) if limit_match else '10'

    # 生成游标分页查询
    cursor_pagination = generate_cursor_pagination(
        original_sql=content,
        order_columns=order_columns,
        limit=limit_value
    )

    return cursor_pagination

def parse_order_columns(order_clause):
    """解析 ORDER BY 列"""
    import re

    columns = []
    parts = order_clause.split(',')

    for part in parts:
        part = part.strip()
        match = re.match(r'(\w+)(?:\s+(ASC|DESC))?', part, re.IGNORECASE)
        if match:
            columns.append({
                'name': match.group(1),
                'direction': (match.group(2) or 'ASC').upper()
            })

    return columns

def generate_cursor_pagination(original_sql, order_columns, limit):
    """生成游标分页SQL"""

    # 移除 OFFSET
    sql = re.sub(r'\s*OFFSET\s+\d+', '', original_sql, flags=re.IGNORECASE)

    # 构建游标条件
    if len(order_columns) == 1:
        col = order_columns[0]
        cursor_condition = f"WHERE {col['name']} > :last_{col['name']}"
    else:
        # 多列排序，生成复合条件
        conditions = []
        for i, col in enumerate(order_columns):
            if col['direction'] == 'DESC':
                conditions.append(f"{col['name']} < :last_{col['name']}")
            else:
                conditions.append(f"{col['name']} > :last_{col['name']}")

        cursor_condition = f"WHERE {' AND '.join(conditions)}"

    # 插入游标条件
    # 注意：需要保留原有的 WHERE 条件
    if 'WHERE' in sql.upper():
        sql = re.sub(
            r'WHERE\s+',
            cursor_condition.replace('WHERE', '') + ' AND ',
            sql,
            flags=re.IGNORECASE
        )
    else:
        # 在 ORDER BY 前插入
        sql = re.sub(
            r'ORDER\s+BY',
            cursor_condition + '\nORDER BY',
            sql,
            flags=re.IGNORECASE
        )

    return sql
```

**Java 应用层示例**:

```java
// ========== 修复前 ==========
public PageResult<Order> getOrders(int pageNum, int pageSize) {
    int offset = (pageNum - 1) * pageSize;
    List<Order> orders = orderMapper.selectOrders(offset, pageSize);
    int total = orderMapper.countOrders();
    return new PageResult<>(orders, total, pageNum, pageSize);
}

// ========== 修复后 ==========
public CursorPageResult<Order> getOrders(Long lastId, int pageSize) {
    List<Order> orders = orderMapper.selectOrdersByCursor(lastId, pageSize);

    Long nextCursor = null;
    if (orders.size() == pageSize) {
        nextCursor = orders.get(orders.size() - 1).getId();
    }

    return new CursorPageResult<>(orders, nextCursor, pageSize);
}

// MyBatis Mapper
@Select("SELECT id, order_no, create_time FROM orders " +
        "WHERE #{lastId} IS NULL OR id > #{lastId} " +
        "ORDER BY id LIMIT #{pageSize}")
List<Order> selectOrdersByCursor(@Param("lastId") Long lastId,
                                  @Param("pageSize") int pageSize);
```

---

## 修复引擎接口

```python
class SQLFixEngine:
    """SQL修复引擎"""

    def __init__(self):
        self.fix_strategies = {
            'COMMON-PERF-002': self.fix_deep_pagination,
        }

    def apply_fix(self, content: str, issue: dict) -> dict:
        """
        应用修复

        Args:
            content: 文件内容（SQL或MyBatis XML）
            issue: 问题对象

        Returns:
            {
                "success": bool,
                "content": str,      # 修复后的内容
                "fix_applied": str,  # 修复描述
                "reason": str        # 失败原因
            }
        """
        rule_id = issue.get("rule_id")
        strategy = self.fix_strategies.get(rule_id)

        if not strategy:
            return {
                "success": False,
                "content": content,
                "reason": f"未找到规则 {rule_id} 的修复策略"
            }

        try:
            fixed_content = strategy(content, issue)

            if fixed_content == content:
                return {
                    "success": False,
                    "content": content,
                    "reason": "无法自动修复，需人工评估"
                }

            return {
                "success": True,
                "content": fixed_content,
                "fix_applied": f"已转换为游标分页，移除 OFFSET {issue.get('offset_value', 'N/A')}"
            }
        except Exception as e:
            return {
                "success": False,
                "content": content,
                "reason": f"修复异常: {str(e)}"
            }

    def check_syntax(self, content: str) -> bool:
        """
        SQL语法检查（简化版）
        """
        # 检查基本关键字
        keywords = ['SELECT', 'FROM', 'WHERE', 'ORDER', 'BY', 'LIMIT']
        content_upper = content.upper()

        # 至少包含 SELECT 和 FROM
        return 'SELECT' in content_upper and 'FROM' in content_upper
```

---

## 注意事项

1. **游标分页不兼容跳页**: 无法直接跳转到第N页，只能顺序翻页
2. **需修改API接口**: 前端需要配合修改分页参数
3. **排序字段要求**: 游标分页要求排序字段唯一且有序
4. **测试数据一致性**: 在数据频繁变化的场景需注意数据重复或遗漏

## 适用场景评估

| 场景 | 是否适用游标分页 | 说明 |
|------|------------------|------|
| 无限滚动加载 | ✅ 适用 | 典型场景 |
| 时间线/动态流 | ✅ 适用 | 按时间排序 |
| 管理后台列表 | ❌ 不适用 | 需要跳页功能 |
| 搜索结果页 | ⚠️ 部分适用 | 评估是否需要跳页 |
| 数据导出 | ✅ 适用 | 顺序读取即可 |
