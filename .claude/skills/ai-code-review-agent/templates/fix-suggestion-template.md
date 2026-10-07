# 修复建议文档

## 概述
本文档提供代码审查中发现问题的修复建议和代码示例。

---

## 安全类问题修复建议

### 1. SQL注入漏洞 (COMMON-SEC-001)

**问题描述**: 使用字符串拼接构建SQL语句存在注入风险

**修复方案**: 使用参数化查询或预编译语句

**代码示例**:

```java
// ❌ 修复前 - 存在SQL注入风险
public User findByUsername(String username) {
    String sql = "SELECT * FROM users WHERE username = '" + username + "'";
    return jdbcTemplate.queryForObject(sql, new UserRowMapper());
}

// ✅ 修复后 - 使用参数化查询
public User findByUsername(String username) {
    String sql = "SELECT * FROM users WHERE username = ?";
    return jdbcTemplate.queryForObject(sql, new Object[]{username}, new UserRowMapper());
}

// ✅ 或使用MyBatis参数绑定
@Select("SELECT * FROM users WHERE username = #{username}")
User findByUsername(@Param("username") String username);
```

---

### 2. XSS跨站脚本攻击 (COMMON-SEC-002)

**问题描述**: 未对用户输入进行转义处理

**修复方案**: 使用XSS过滤器对用户输入进行转义

**代码示例**:

```vue
<!-- ❌ 修复前 - 存在XSS风险 -->
<div v-html="userInput"></div>

<!-- ✅ 修复后 - 使用转义处理 -->
<template>
  <div>{{ sanitizedContent }}</div>
</template>

<script setup>
import { computed } from 'vue'
import { sanitize } from 'dompurify'

const props = defineProps(['userInput'])

const sanitizedContent = computed(() => {
  return sanitize(props.userInput, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong'],
    ALLOWED_ATTR: []
  })
})
</script>
```

---

### 3. 敏感信息硬编码 (COMMON-SEC-003)

**问题描述**: 配置文件中存在硬编码的敏感信息

**修复方案**: 使用环境变量或配置中心管理敏感信息

**代码示例**:

```yaml
# ❌ 修复前 - 硬编码敏感信息
spring:
  datasource:
    password: MyP@ssw0rd123
  mail:
    password: mail-password

# ✅ 修复后 - 使用环境变量
spring:
  datasource:
    password: ${DB_PASSWORD}
  mail:
    password: ${MAIL_PASSWORD}
```

---

## 性能类问题修复建议

### 4. N+1查询问题 (COMMON-PERF-001)

**问题描述**: 循环中执行数据库查询导致性能问题

**修复方案**: 使用JOIN或批量查询优化

**代码示例**:

```java
// ❌ 修复前 - N+1查询
public List<OrderDTO> getOrdersWithItems(List<Long> orderIds) {
    List<Order> orders = orderMapper.selectByIds(orderIds);
    return orders.stream().map(order -> {
        List<OrderItem> items = orderItemMapper.selectByOrderId(order.getId()); // N次查询
        return convertToDTO(order, items);
    }).collect(Collectors.toList());
}

// ✅ 修复后 - 批量查询
public List<OrderDTO> getOrdersWithItems(List<Long> orderIds) {
    List<Order> orders = orderMapper.selectByIds(orderIds);
    List<OrderItem> allItems = orderItemMapper.selectByOrderIds(orderIds); // 1次查询

    Map<Long, List<OrderItem>> itemMap = allItems.stream()
        .collect(Collectors.groupingBy(OrderItem::getOrderId));

    return orders.stream().map(order -> {
        List<OrderItem> items = itemMap.getOrDefault(order.getId(), Collections.emptyList());
        return convertToDTO(order, items);
    }).collect(Collectors.toList());
}

// ✅ 或使用MyBatis关联查询
@Select("SELECT o.*, i.* FROM orders o LEFT JOIN order_items i ON o.id = i.order_id WHERE o.id IN (${orderIds})")
@Results({
    @Result(property = "id", column = "id"),
    @Result(property = "items", javaType = List.class, column = "id",
            many = @Many(select = "selectItemsByOrderId"))
})
List<Order> selectOrdersWithItems(@Param("orderIds") List<Long> orderIds);
```

---

## 医疗合规类问题修复建议

### 5. 患者敏感信息脱敏检查 (MED-SEC-001)

**问题描述**: 患者姓名未脱敏直接展示

**修复方案**: 使用脱敏工具类处理患者信息

**代码示例**:

```java
// ❌ 修复前 - 直接展示患者信息
public PatientVO getPatientInfo(Long patientId) {
    Patient patient = patientMapper.selectById(patientId);
    return new PatientVO(patient.getName(), patient.getIdCard(), patient.getPhone());
}

// ✅ 修复后 - 脱敏处理
public PatientVO getPatientInfo(Long patientId) {
    Patient patient = patientMapper.selectById(patientId);
    return new PatientVO(
        DesensitizationUtil.name(patient.getName()),      // 张*三
        DesensitizationUtil.idCard(patient.getIdCard()), // 110***********1234
        DesensitizationUtil.phone(patient.getPhone())    // 138****1234
    );
}

// 脱敏工具类
public class DesensitizationUtil {

    public static String name(String name) {
        if (StringUtils.isBlank(name)) return name;
        if (name.length() == 2) {
            return name.charAt(0) + "*";
        }
        return name.charAt(0) + "*" + name.charAt(name.length() - 1);
    }

    public static String idCard(String idCard) {
        if (StringUtils.isBlank(idCard) || idCard.length() < 15) return idCard;
        return idCard.substring(0, 3) + "***********" + idCard.substring(idCard.length() - 4);
    }

    public static String phone(String phone) {
        if (StringUtils.isBlank(phone) || phone.length() < 11) return phone;
        return phone.substring(0, 3) + "****" + phone.substring(7);
    }
}
```

---

### 6. 患者数据加密存储检查 (MED-SEC-002)

**问题描述**: 病历数据存储未加密

**修复方案**: 使用AES-256加密敏感数据

**代码示例**:

```java
// ✅ 加密存储
@Entity
public class MedicalRecord {

    @Id
    private Long id;

    @Convert(converter = EncryptedStringConverter.class)
    @Column(columnDefinition = "TEXT")
    private String diagnosisContent; // 加密存储

    @Convert(converter = EncryptedStringConverter.class)
    private String treatmentPlan; // 加密存储
}

// 加密转换器
@Converter(autoApply = true)
public class EncryptedStringConverter implements AttributeConverter<String, String> {

    private static final String SECRET_KEY = System.getenv("ENCRYPTION_KEY");

    @Override
    public String convertToDatabaseColumn(String attribute) {
        if (attribute == null) return null;
        return AES256Util.encrypt(attribute, SECRET_KEY);
    }

    @Override
    public String convertToEntityAttribute(String dbData) {
        if (dbData == null) return null;
        return AES256Util.decrypt(dbData, SECRET_KEY);
    }
}
```

---

### 7. 关键操作审计日志检查 (MED-AUDIT-001)

**问题描述**: 处方操作未记录审计日志

**修复方案**: 添加操作审计日志记录

**代码示例**:

```java
// ✅ 添加审计日志
@Service
public class PrescriptionService {

    @Autowired
    private AuditLogService auditLogService;

    @Transactional
    public Prescription createPrescription(PrescriptionDTO dto, String operatorId) {
        // 业务操作
        Prescription prescription = convertAndSave(dto);

        // 记录审计日志
        auditLogService.log(AuditLog.builder()
            .operationType("CREATE_PRESCRIPTION")
            .businessId(prescription.getId())
            .operatorId(operatorId)
            .operationTime(LocalDateTime.now())
            .details(JsonUtil.toJson(dto))
            .ipAddress(RequestContext.getClientIp())
            .build());

        return prescription;
    }
}

// 使用AOP自动记录
@Aspect
@Component
public class AuditLogAspect {

    @AfterReturning(pointcut = "@annotation(auditLog)", returning = "result")
    public void recordAuditLog(JoinPoint joinPoint, AuditLog auditLog, Object result) {
        // 自动记录审计日志
    }
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface AuditLog {
    String operationType();
    String description() default "";
}
```

---

## 产品线特定修复建议

### 8. API统一POST方法 (AIMY-API-001)

**问题描述**: AI-MY平台所有API接口统一使用POST方法

**修复方案**: 将@GetMapping/@PutMapping/@DeleteMapping改为@PostMapping

**代码示例**:

```java
// ❌ 修复前
@GetMapping("/user/list")
public Result<List<UserVO>> listUsers(UserQuery query) {
    return Result.success(userService.list(query));
}

// ✅ 修复后
@PostMapping("/api/v1/agent_framework/admin/user/list")
public Result<List<UserVO>> listUsers(@RequestBody UserQuery query) {
    return Result.success(userService.list(query));
}
```

---

### 9. 移动端响应式适配 (AIMY-MOBILE-001)

**问题描述**: 使用固定像素宽度不利于移动端适配

**修复方案**: 使用rem/vw/vh或百分比布局

**代码示例**:

```vue
<!-- ❌ 修复前 -->
<style scoped>
.container {
  width: 375px;
  padding: 20px;
}
.title {
  font-size: 18px;
}
</style>

<!-- ✅ 修复后 -->
<style scoped>
.container {
  width: 100%;
  max-width: 750px;
  padding: 0.5rem;
}
.title {
  font-size: 0.45rem;
}

/* 或使用媒体查询 */
@media screen and (min-width: 768px) {
  .container {
    width: 750px;
    margin: 0 auto;
  }
}
</style>
```

---

## 修复优先级建议

| 优先级 | 问题类型 | 修复时限 |
|--------|----------|----------|
| P0 | Critical安全漏洞 | 立即修复 |
| P1 | Critical医疗合规 | 24小时内 |
| P2 | Warning类问题 | 本迭代内 |
| P3 | Info类建议 | 下迭代规划 |
