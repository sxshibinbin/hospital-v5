# Java修复引擎

## 引擎信息
- **技术栈**: Java
- **支持规则**: 4个
- **风险级别**: low ~ medium

## 支持规则列表

| 规则ID | 规则名称 | 风险级别 | 自动修复 |
|--------|----------|----------|----------|
| COMMON-SEC-002 | 敏感信息日志输出检查 | low | ✅ |
| COMMON-QUAL-001 | 空catch块检查 | low | ✅ |
| COMMON-STD-002 | 命名规范检查 | medium | ✅ |
| MED-SEC-001 | 患者敏感信息脱敏检查 | low | ✅ |

---

## 规则修复实现

### 1. COMMON-SEC-002: 敏感信息日志输出检查

**风险级别**: low

**修复策略**: `remove_or_mask_sensitive_log`

**检测模式**:
```regex
log\.(info|debug|error|warn)\s*\([^)]*(password|token|secret|key|credential)[^)]*\)
```

**修复逻辑**:
1. 检测日志语句中的敏感字段名
2. 移除敏感参数或替换为脱敏占位符
3. 保持日志语句的基本结构

**修复示例**:

```java
// ========== 修复前 ==========
log.info("用户登录: username={}, password={}", username, password);
log.debug("API Token: {}", apiToken);
log.error("数据库连接失败, password={}", dbPassword);

// ========== 修复后 ==========
log.info("用户登录: username={}", username);
log.debug("API Token: ***");
log.error("数据库连接失败");
```

**修复代码模板**:
```python
def fix_sensitive_log(content, issue):
    """
    修复敏感信息日志
    """
    import re

    line_number = issue["line_number"]
    lines = content.split('\n')
    original_line = lines[line_number - 1]

    # 敏感字段列表
    sensitive_fields = ['password', 'token', 'secret', 'key', 'credential']

    # 移除包含敏感字段的参数
    modified_line = original_line

    for field in sensitive_fields:
        # 匹配 "{}" 占位符和对应参数
        pattern = r'\{[^}]*\}' if field in original_line.lower() else None
        if pattern:
            # 简化处理：移除敏感字段相关内容
            modified_line = re.sub(
                r',?\s*' + field + r'=\{[^}]*\}',
                '',
                modified_line,
                flags=re.IGNORECASE
            )
            modified_line = re.sub(
                r',?\s*' + field + r'\s*(,|\))',
                r'\1',
                modified_line,
                flags=re.IGNORECASE
            )

    lines[line_number - 1] = modified_line
    return '\n'.join(lines)
```

---

### 2. COMMON-QUAL-001: 空catch块检查

**风险级别**: low

**修复策略**: `add_log_statement`

**检测模式**:
```regex
catch\s*\([^)]+\)\s*\{\s*\}
```

**修复逻辑**:
1. 定位空catch块
2. 添加日志语句记录异常
3. 使用异常变量 `e` 记录错误信息

**修复示例**:

```java
// ========== 修复前 ==========
try {
    doSomething();
} catch (Exception e) {
}

try {
    processData(data);
} catch (IOException e) {
}

// ========== 修复后 ==========
try {
    doSomething();
} catch (Exception e) {
    log.error("操作失败", e);
}

try {
    processData(data);
} catch (IOException e) {
    log.error("数据处理失败", e);
}
```

**修复代码模板**:
```python
def fix_empty_catch(content, issue):
    """
    修复空catch块
    """
    line_number = issue["line_number"]
    lines = content.split('\n')

    # 找到空catch块的结束位置
    catch_line = lines[line_number - 1]

    # 提取异常类型和变量名
    import re
    match = re.search(r'catch\s*\(\s*(\w+(?:\.\w+)*)\s+(\w+)\s*\)', catch_line)

    if match:
        exception_type = match.group(1)
        exception_var = match.group(2)

        # 生成日志语句
        # 根据异常类型生成不同的日志消息
        error_msg = generate_error_message(exception_type)
        log_statement = f'        log.error("{error_msg}", {exception_var});'

        # 在catch块内添加日志
        # 找到catch块的结束大括号位置
        modified_lines = insert_log_into_empty_catch(lines, line_number - 1, log_statement)
        return '\n'.join(modified_lines)

    return content

def generate_error_message(exception_type):
    """根据异常类型生成错误消息"""
    messages = {
        'IOException': 'IO操作失败',
        'SQLException': '数据库操作失败',
        'NullPointerException': '空指针异常',
        'IllegalArgumentException': '参数非法',
        'RuntimeException': '运行时异常',
        'Exception': '操作失败'
    }
    return messages.get(exception_type, '操作失败')
```

---

### 3. COMMON-STD-002: 命名规范检查

**风险级别**: medium

**修复策略**: `rename_identifier`

**检测模式**:
```regex
(var\s+[A-Z][a-zA-Z0-9]*|private\s+\w+\s+[A-Z][a-zA-Z0-9]*\s*;)
```

**修复逻辑**:
1. 识别命名不规范的变量/字段
2. 转换为camelCase命名
3. 全局搜索替换所有引用

**修复示例**:

```java
// ========== 修复前 ==========
var UserName = "test";
private String UserPassword;
public void SetData(String Value) {
    this.Value = Value;
}

// ========== 修复后 ==========
var userName = "test";
private String userPassword;
public void setData(String value) {
    this.value = value;
}
```

**修复代码模板**:
```python
def fix_naming_convention(content, issue):
    """
    修复命名规范问题
    注意：需要全局替换引用
    """
    import re

    line_number = issue["line_number"]
    lines = content.split('\n')
    original_line = lines[line_number - 1]

    # 提取需要重命名的标识符
    # 变量: var XXX -> var xxx
    # 字段: private Type XXX -> private Type xxx
    # 方法: public void XXX() -> public void xxx()

    old_name = extract_identifier(original_line, issue)
    new_name = to_camel_case(old_name)

    if old_name and new_name != old_name:
        # 全局替换（注意避免误替换）
        modified_content = safe_rename(content, old_name, new_name)
        return modified_content

    return content

def to_camel_case(name):
    """转换为camelCase"""
    if not name:
        return name
    return name[0].lower() + name[1:]

def safe_rename(content, old_name, new_name):
    """
    安全重命名，避免误替换
    """
    import re
    # 使用词边界匹配
    pattern = r'\b' + re.escape(old_name) + r'\b'
    return re.sub(pattern, new_name, content)
```

---

### 4. MED-SEC-001: 患者敏感信息脱敏检查

**风险级别**: low

**修复策略**: `apply_desensitization`

**检测模式**:
```regex
(patient\.getName\(\)|patient\.getIdCard\(\)|patient\.getPhone\(\)|\.setPatientName\([^)]+\))
```

**修复逻辑**:
1. 检测直接使用患者敏感信息的代码
2. 包装脱敏工具类调用
3. 保持业务逻辑不变

**修复示例**:

```java
// ========== 修复前 ==========
public PatientVO getPatientInfo(Long patientId) {
    Patient patient = patientMapper.selectById(patientId);
    PatientVO vo = new PatientVO();
    vo.setName(patient.getName());
    vo.setIdCard(patient.getIdCard());
    vo.setPhone(patient.getPhone());
    return vo;
}

// ========== 修复后 ==========
public PatientVO getPatientInfo(Long patientId) {
    Patient patient = patientMapper.selectById(patientId);
    PatientVO vo = new PatientVO();
    vo.setName(DesensitizationUtil.name(patient.getName()));
    vo.setIdCard(DesensitizationUtil.idCard(patient.getIdCard()));
    vo.setPhone(DesensitizationUtil.phone(patient.getPhone()));
    return vo;
}
```

**脱敏工具类模板**:
```java
/**
 * 脱敏工具类
 */
public class DesensitizationUtil {

    /**
     * 姓名脱敏: 张三 -> 张*
     */
    public static String name(String name) {
        if (StringUtils.isBlank(name)) return name;
        if (name.length() == 2) {
            return name.charAt(0) + "*";
        }
        return name.charAt(0) + "*" + name.charAt(name.length() - 1);
    }

    /**
     * 身份证脱敏: 110101199001011234 -> 110***********1234
     */
    public static String idCard(String idCard) {
        if (StringUtils.isBlank(idCard) || idCard.length() < 15) return idCard;
        return idCard.substring(0, 3) + "***********" + idCard.substring(idCard.length() - 4);
    }

    /**
     * 手机号脱敏: 13812345678 -> 138****5678
     */
    public static String phone(String phone) {
        if (StringUtils.isBlank(phone) || phone.length() < 11) return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }
}
```

**修复代码模板**:
```python
def fix_patient_desensitization(content, issue):
    """
    修复患者信息脱敏
    """
    import re

    # 脱敏映射
    desensitize_map = {
        'getName()': 'DesensitizationUtil.name(patient.getName())',
        'getIdCard()': 'DesensitizationUtil.idCard(patient.getIdCard())',
        'getPhone()': 'DesensitizationUtil.phone(patient.getPhone())',
    }

    modified_content = content
    for pattern, replacement in desensitize_map.items():
        # 匹配 patient.getXxx() 但排除已经被包装的情况
        regex = r'(?<!DesensitizationUtil\.\w+\()patient\.' + pattern
        modified_content = re.sub(regex, replacement, modified_content)

    # 检查是否需要添加import
    if 'DesensitizationUtil' in modified_content:
        if 'import com.winning.util.DesensitizationUtil;' not in modified_content:
            modified_content = add_import(modified_content, 'com.winning.util.DesensitizationUtil')

    return modified_content
```

---

## 修复引擎接口

```python
class JavaFixEngine:
    """Java修复引擎"""

    def __init__(self):
        self.fix_strategies = {
            'COMMON-SEC-002': self.fix_sensitive_log,
            'COMMON-QUAL-001': self.fix_empty_catch,
            'COMMON-STD-002': self.fix_naming_convention,
            'MED-SEC-001': self.fix_patient_desensitization,
        }

    def apply_fix(self, content: str, issue: dict) -> dict:
        """
        应用修复

        Args:
            content: 文件内容
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
            return {
                "success": True,
                "content": fixed_content,
                "fix_applied": f"应用规则 {rule_id} 修复"
            }
        except Exception as e:
            return {
                "success": False,
                "content": content,
                "reason": f"修复异常: {str(e)}"
            }

    def check_syntax(self, content: str) -> bool:
        """
        语法检查（简化版）
        实际应调用 Java 编译器
        """
        # 检查基本语法：括号匹配
        brace_count = content.count('{') - content.count('}')
        paren_count = content.count('(') - content.count(')')

        return brace_count == 0 and paren_count == 0
```

---

## 注意事项

1. **命名规范修复需谨慎**: 需要全局替换引用，可能影响其他文件
2. **脱敏修复需确认工具类**: 确保 `DesensitizationUtil` 已存在于项目中
3. **备份原文件**: 修复前务必备份，支持回滚
4. **测试验证**: 修复后需通过编译和单元测试
