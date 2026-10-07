# Bug 修复策略模板

## 使用说明
Stage 4.5 生成修复时，按 `bug-analysis-rules.md` 匹配到的 `rule_id` 查找对应修复策略。每种策略包含 Java / C# / Vue 三种技术栈的修复模板。

---

## NULL_POINTER

### 识别关键词
`NullPointerException`, `NPE`, `Cannot invoke`, `is null`

### Java 修复模板

**方案A: 防御性判空（推荐）**
```java
// ❌ 问题代码
Patient patient = patientService.findById(id);
return patient.getName();

// ✅ 修复代码
Patient patient = patientService.findById(id);
if (patient == null) {
    throw new BusinessException("患者不存在: " + id);
}
return patient.getName();
```

**方案B: Optional 链式调用**
```java
// ✅ 修复代码
return patientService.findById(id)
    .map(Patient::getName)
    .orElseThrow(() -> new BusinessException("患者不存在: " + id));
```

**方案C: 返回默认值（适用于非关键路径）**
```java
// ✅ 修复代码
Patient patient = patientService.findById(id);
return patient != null ? patient.getName() : "";
```

### C# 修复模板
```csharp
// ❌ 问题代码
var patient = _patientService.FindById(id);
return patient.Name;

// ✅ 修复代码
var patient = _patientService.FindById(id);
if (patient == null)
    throw new BusinessException($"患者不存在: {id}");
return patient.Name;
```

### Vue/前端修复模板
```javascript
// ❌ 问题代码
const name = response.data.patient.name;

// ✅ 修复代码
const name = response.data?.patient?.name ?? '';
```

### 验证方法
- 重测原失败用例 ✅
- 补充 null 输入边界用例 ✅

### 禁止操作
- ❌ 不要通过 `@SuppressWarnings` 消除警告
- ❌ 不要用 `assert` 替代运行时判空

---

## INDEX_OUT_OF_BOUNDS

### 识别关键词
`ArrayIndexOutOfBounds`, `IndexOutOfBounds`, `越界`

### Java 修复模板
```java
// ❌ 问题代码
String item = list.get(index);

// ✅ 修复代码
if (index < 0 || index >= list.size()) {
    throw new BusinessException("索引越界: " + index);
}
String item = list.get(index);
```

### C# 修复模板
```csharp
// ✅ 修复代码
if (index < 0 || index >= list.Count)
    throw new BusinessException($"索引越界: {index}");
var item = list[index];
```

### Vue/前端修复模板
```javascript
// ✅ 修复代码
const item = (index >= 0 && index < list.length) ? list[index] : null;
```

### 验证方法
- 重测原失败用例 ✅
- 补充边界值用例（index=0, index=-1, index=size）✅

---

## TYPE_CONVERSION

### 识别关键词
`ClassCastException`, `NumberFormatException`, `类型转换`

### Java 修复模板
```java
// ❌ 问题代码
int value = Integer.parseInt(str);

// ✅ 修复代码
int value;
try {
    value = Integer.parseInt(str);
} catch (NumberFormatException e) {
    throw new BusinessException("数值格式错误: " + str, e);
}
```

### C# 修复模板
```csharp
// ✅ 修复代码
if (!int.TryParse(str, out int value))
    throw new BusinessException($"数值格式错误: {str}");
```

### 验证方法
- 重测原失败用例 ✅
- 补充非法格式输入用例 ✅

---

## CONCURRENCY

### 识别关键词
`ConcurrentModification`, `Deadlock`, `线程安全`

### Java 修复模板

**方案A: 使用线程安全容器**
```java
// ❌ 问题代码
List<String> list = new ArrayList<>();

// ✅ 修复代码
List<String> list = new CopyOnWriteArrayList<>();
// 或
List<String> list = Collections.synchronizedList(new ArrayList<>());
```

**方案B: 同步块**
```java
// ✅ 修复代码
synchronized (this) {
    // 关键操作
}
```

### C# 修复模板
```csharp
// ✅ 修复代码 - 使用 ConcurrentDictionary
var dict = new ConcurrentDictionary<string, object>();
dict.TryAdd(key, value);
```

### 验证方法
- 重测原失败用例 ✅
- 多线程并发压力测试 ✅

### 禁止操作
- ❌ 不要简单地吞掉 `ConcurrentModificationException`
- ❌ 不要在持锁期间调用外部方法（死锁风险）

---

## RESOURCE_LEAK

### 识别关键词
`未关闭`, `资源泄漏`, `connection leak`

### Java 修复模板
```java
// ❌ 问题代码
Connection conn = dataSource.getConnection();
PreparedStatement stmt = conn.prepareStatement(sql);
ResultSet rs = stmt.executeQuery();
// 未关闭

// ✅ 修复代码 - try-with-resources
try (Connection conn = dataSource.getConnection();
     PreparedStatement stmt = conn.prepareStatement(sql);
     ResultSet rs = stmt.executeQuery()) {
    // 使用 rs
}
```

### C# 修复模板
```csharp
// ✅ 修复代码 - using 语句
using var conn = new SqlConnection(connectionString);
using var cmd = new SqlCommand(sql, conn);
await conn.OpenAsync();
```

### 验证方法
- 重测原失败用例 ✅
- 多次执行确认资源正确释放 ✅

---

## SQL_INJECTION

### 识别关键词
`${}` (MyBatis), `字符串拼接SQL`, `SQL injection`

### Java 修复模板

**MyBatis XML 修复：**
```xml
<!-- ❌ 问题代码 -->
<select id="findPatient">
    SELECT * FROM patient WHERE name LIKE '%${name}%'
</select>

<!-- ✅ 修复代码 -->
<select id="findPatient">
    SELECT * FROM patient WHERE name LIKE CONCAT('%', #{name}, '%')
</select>
```

**JDBC 修复：**
```java
// ❌ 问题代码
String sql = "SELECT * FROM patient WHERE name = '" + name + "'";

// ✅ 修复代码
String sql = "SELECT * FROM patient WHERE name = ?";
PreparedStatement stmt = conn.prepareStatement(sql);
stmt.setString(1, name);
```

### 验证方法
- 重测原失败用例 ✅
- 补充SQL注入攻击用例 ✅

### 禁止操作
- ❌ 绝对不要使用字符串拼接构建SQL
- ❌ 不要依赖前端过滤替代后端参数化

---

## XSS_VULNERABILITY

### 识别关键词
`XSS`, `未编码输出`, `innerHTML`

### Vue/前端修复模板
```javascript
// ❌ 问题代码
element.innerHTML = userInput;

// ✅ 修复代码 - 使用 textContent
element.textContent = userInput;

// ✅ 修复代码 - Vue 模板自动转义（默认安全）
// <template> 中 {{ }} 自动转义，避免使用 v-html
```

### Java 修复模板（后端输出）
```java
// ✅ 修复代码 - 使用 HtmlUtils 转义
import org.springframework.web.util.HtmlUtils;
String safeOutput = HtmlUtils.htmlEscape(userInput);
```

### 验证方法
- 重测原失败用例 ✅
- 补充XSS攻击载荷测试用例 ✅

---

## PERFORMANCE

### 识别关键词
`慢查询`, `超时`, `OutOfMemory`, `N+1`

### Java 修复模板

**N+1 查询修复：**
```java
// ❌ 问题代码 - N+1 查询
List<Order> orders = orderMapper.selectAll();
for (Order order : orders) {
    Patient patient = patientMapper.selectById(order.getPatientId()); // 每条订单查一次
}

// ✅ 修复代码 - 批量查询
List<Order> orders = orderMapper.selectAll();
List<Long> patientIds = orders.stream().map(Order::getPatientId).distinct().collect(Collectors.toList());
Map<Long, Patient> patientMap = patientMapper.selectByIds(patientIds)
    .stream().collect(Collectors.toMap(Patient::getId, Function.identity()));
for (Order order : orders) {
    Patient patient = patientMap.get(order.getPatientId());
}
```

### 验证方法
- 重测原失败用例 ✅
- 确认查询次数从 N+1 降为 2 ✅

---

## DATA_VALIDATION

### 识别关键词
`参数校验`, `缺少校验`, `Invalid input`

### Java 修复模板
```java
// ❌ 问题代码
public Patient createPatient(PatientDTO dto) {
    return patientMapper.insert(dto); // 未校验
}

// ✅ 修复代码
public Patient createPatient(PatientDTO dto) {
    if (dto == null) {
        throw new BusinessException("参数不能为空");
    }
    if (StringUtils.isBlank(dto.getName())) {
        throw new BusinessException("患者姓名不能为空");
    }
    if (dto.getAge() == null || dto.getAge() < 0 || dto.getAge() > 200) {
        throw new BusinessException("年龄不在有效范围");
    }
    return patientMapper.insert(dto);
}
```

### C# 修复模板
```csharp
// ✅ 修复代码
if (dto == null) throw new BusinessException("参数不能为空");
if (string.IsNullOrWhiteSpace(dto.Name)) throw new BusinessException("患者姓名不能为空");
```

### 验证方法
- 重测原失败用例 ✅
- 补充空值/非法值边界用例 ✅

---

## CONFIGURATION

### 识别关键词
`硬编码`, `配置错误`, `hardcode`

### Java 修复模板
```java
// ❌ 问题代码
String apiUrl = "http://192.168.1.100:8080/api";

// ✅ 修复代码
@Value("${external.api.url}")
private String apiUrl;
```

### 验证方法
- 重测原失败用例 ✅
- 确认配置文件包含对应项 ✅

---

## MEDICAL_DATA_INTEGRITY

### 识别关键词
`事务未回滚`, `数据残留`, `数据不一致`

### Java 修复模板
```java
// ❌ 问题代码 - 缺少事务注解
public void transferPatient(Long patientId, Long fromDept, Long toDept) {
    deptMapper.removePatient(fromDept, patientId);
    deptMapper.addPatient(toDept, patientId); // 如果这里失败，上面已执行
}

// ✅ 修复代码
@Transactional(rollbackFor = Exception.class)
public void transferPatient(Long patientId, Long fromDept, Long toDept) {
    deptMapper.removePatient(fromDept, patientId);
    deptMapper.addPatient(toDept, patientId);
}
```

### 验证方法
- 重测原失败用例 ✅
- 模拟异常确认事务回滚 ✅
- ⚠️ **必须标记人工复核**

### 禁止操作
- ❌ 不要捕获异常后不抛出（吞异常导致事务不回滚）
- ❌ 不要在同一事务中混合不同数据源操作

---

## MEDICAL_DOSAGE_CALC

### 识别关键词
`剂量超范围`, `单位错误`, `药物计算`

### Java 修复模板
```java
// ❌ 问题代码 - 缺少剂量范围校验
public Prescription createPrescription(Long patientId, String drugCode, double dosage) {
    Prescription p = new Prescription();
    p.setDosage(dosage);
    return prescriptionMapper.insert(p);
}

// ✅ 修复代码
public Prescription createPrescription(Long patientId, String drugCode, double dosage) {
    Drug drug = drugService.findByCode(drugCode);
    if (drug == null) {
        throw new BusinessException("药物不存在: " + drugCode);
    }
    // 剂量范围校验
    if (dosage < drug.getMinDosage() || dosage > drug.getMaxDosage()) {
        throw new BusinessException(String.format(
            "剂量 %.2f 超出范围 [%.2f, %.2f] %s",
            dosage, drug.getMinDosage(), drug.getMaxDosage(), drug.getUnit()));
    }
    Prescription p = new Prescription();
    p.setDosage(dosage);
    return prescriptionMapper.insert(p);
}
```

### 验证方法
- 重测原失败用例 ✅
- 补充超范围剂量用例 ✅
- 补充成人/儿童差异化用例 ✅
- ⚠️ **必须标记人工复核**

### 禁止操作
- ❌ 不要简化或移除剂量范围校验
- ❌ 不要用 `int` 替代 `double`（精度丢失）

---

## MEDICAL_AUTH_BYPASS

### 识别关键词
`越权访问`, `角色缺失`, `权限绕过`

### Java 修复模板
```java
// ❌ 问题代码 - 缺少权限校验
@GetMapping("/api/patient/{id}/records")
public List<MedicalRecord> getRecords(@PathVariable Long id) {
    return recordService.findByPatientId(id);
}

// ✅ 修复代码
@PreAuthorize("hasAnyRole('DOCTOR', 'NURSE', 'ADMIN')")
@GetMapping("/api/patient/{id}/records")
public List<MedicalRecord> getRecords(@PathVariable Long id) {
    // 护士只能查看自己负责科室的患者
    if (SecurityUtils.hasRole("NURSE")) {
        recordService.verifyNurseAccess(id, SecurityUtils.getCurrentUserId());
    }
    return recordService.findByPatientId(id);
}
```

### 验证方法
- 重测原失败用例 ✅
- 补充所有角色组合的越权测试 ✅
- ⚠️ **必须标记人工复核**

### 禁止操作
- ❌ 不要仅依赖前端隐藏菜单实现权限控制
- ❌ 不要在接口层跳过角色校验
