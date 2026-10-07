# Bug 分析规则库

## 使用说明
Stage 4.5 根因分析时，按错误堆栈/测试输出中的关键词匹配以下规则。匹配成功后，记录 `rule_id` 用于关联 `fix-strategies.md` 中的修复策略。

---

## 通用规则（10种）

### 1. NULL_POINTER
| 属性 | 值 |
|------|-----|
| **规则ID** | NULL_POINTER |
| **严重级别** | HIGH (P1) |
| **识别关键词** | `NullPointerException`, `NPE`, `空引用`, `null object`, `Cannot invoke`, `is null` |
| **典型场景** | 对象未初始化、查询返回null后直接调用方法、集合元素为null |
| **匹配堆栈模式** | `at xxx.xxx.method(Xxx.java:NN)` 前一行含 `NullPointerException` |

### 2. INDEX_OUT_OF_BOUNDS
| 属性 | 值 |
|------|-----|
| **规则ID** | INDEX_OUT_OF_BOUNDS |
| **严重级别** | HIGH (P1) |
| **识别关键词** | `ArrayIndexOutOfBounds`, `IndexOutOfBounds`, `越界`, `StringIndexOutOfBounds` |
| **典型场景** | 数组/列表越界访问、字符串截取越界、分页参数未校验 |
| **匹配堆栈模式** | 堆栈含 `Index` 相关异常类 |

### 3. TYPE_CONVERSION
| 属性 | 值 |
|------|-----|
| **规则ID** | TYPE_CONVERSION |
| **严重级别** | MEDIUM (P2) |
| **识别关键词** | `ClassCastException`, `NumberFormatException`, `类型转换`, `cannot be cast`, `Invalid cast` |
| **典型场景** | 强转类型未检查、字符串转数字失败、JSON反序列化类型不匹配 |
| **匹配堆栈模式** | 堆栈含 `cast` 或 `convert` 相关异常 |

### 4. CONCURRENCY
| 属性 | 值 |
|------|-----|
| **规则ID** | CONCURRENCY |
| **严重级别** | HIGH (P1) |
| **识别关键词** | `ConcurrentModification`, `Deadlock`, `Race condition`, `线程安全`, `synchronized` |
| **典型场景** | 遍历时修改集合、多线程竞争资源、死锁、非线程安全容器并发访问 |
| **匹配堆栈模式** | 堆栈含 `Concurrent` 或 `Deadlock` 关键词 |

### 5. RESOURCE_LEAK
| 属性 | 值 |
|------|-----|
| **规则ID** | RESOURCE_LEAK |
| **严重级别** | HIGH (P1) |
| **识别关键词** | `未关闭`, `资源泄漏`, `connection leak`, `stream not closed`, `try-with-resources` |
| **典型场景** | 数据库连接未关闭、文件流未释放、HTTP连接池耗尽 |
| **匹配堆栈模式** | 测试超时 + 资源相关堆栈 |

### 6. SQL_INJECTION
| 属性 | 值 |
|------|-----|
| **规则ID** | SQL_INJECTION |
| **严重级别** | CRITICAL (P0) |
| **识别关键词** | `SQL注入`, `字符串拼接SQL`, `SQL injection`, `dynamic SQL`, `${}` (MyBatis) |
| **典型场景** | MyBatis XML中使用 `${}` 而非 `#{}`、字符串拼接构建SQL、未使用参数化查询 |
| **匹配堆栈模式** | 代码审查发现 + SQL相关测试失败 |

### 7. XSS_VULNERABILITY
| 属性 | 值 |
|------|-----|
| **规则ID** | XSS_VULNERABILITY |
| **严重级别** | CRITICAL (P0) |
| **识别关键词** | `XSS`, `跨站脚本`, `未编码输出`, `script injection`, `innerHTML` |
| **典型场景** | 用户输入未编码直接输出到页面、富文本未过滤、API返回未转义 |
| **匹配堆栈模式** | 前端测试发现 + 安全扫描报告 |

### 8. PERFORMANCE
| 属性 | 值 |
|------|-----|
| **规则ID** | PERFORMANCE |
| **严重级别** | MEDIUM (P2) |
| **识别关键词** | `慢查询`, `超时`, `O(n²)`, `timeout`, `performance`, `内存溢出`, `OutOfMemory` |
| **典型场景** | N+1查询、大对象创建、嵌套循环、未分页的全量查询 |
| **匹配堆栈模式** | 测试超时 + 性能相关日志 |

### 9. DATA_VALIDATION
| 属性 | 值 |
|------|-----|
| **规则ID** | DATA_VALIDATION |
| **严重级别** | MEDIUM (P2) |
| **识别关键词** | `参数校验`, `缺少校验`, `validation`, `Invalid input`, `参数为空` |
| **典型场景** | 接口入参未校验、必填字段未检查、格式校验缺失 |
| **匹配堆栈模式** | 异常边界测试失败 |

### 10. CONFIGURATION
| 属性 | 值 |
|------|-----|
| **规则ID** | CONFIGURATION |
| **严重级别** | LOW (P3) |
| **识别关键词** | `硬编码`, `配置错误`, `hardcode`, `环境差异`, `配置缺失` |
| **典型场景** | 硬编码URL/端口、环境配置不一致、缺少默认配置 |
| **匹配堆栈模式** | 环境相关测试失败 |

---

## 医疗系统扩展规则（3种）

### 11. MEDICAL_DATA_INTEGRITY
| 属性 | 值 |
|------|-----|
| **规则ID** | MEDICAL_DATA_INTEGRITY |
| **严重级别** | CRITICAL (P0) |
| **识别关键词** | `事务未回滚`, `数据残留`, `数据不一致`, `transaction rollback`, `数据完整性` |
| **典型场景** | 异常时事务未回滚导致脏数据、多表操作部分成功、护理记录被篡改 |
| **匹配堆栈模式** | 事务相关测试失败 + 数据一致性断言失败 |
| **特殊要求** | ⚠️ 修复后必须标记"需人工复核" |

### 12. MEDICAL_DOSAGE_CALC
| 属性 | 值 |
|------|-----|
| **规则ID** | MEDICAL_DOSAGE_CALC |
| **严重级别** | CRITICAL (P0) |
| **识别关键词** | `剂量超范围`, `单位错误`, `dosage`, `药物计算`, `处方剂量`, `药物相互作用` |
| **典型场景** | 剂量计算公式精度丢失、成人/儿童剂量未区分、药物相互作用校验缺失 |
| **匹配堆栈模式** | 剂量相关断言失败 + 计算结果偏差 |
| **特殊要求** | ⚠️ 修复后必须标记"需人工复核"，且修复方案不得简化剂量校验逻辑 |

### 13. MEDICAL_AUTH_BYPASS
| 属性 | 值 |
|------|-----|
| **规则ID** | MEDICAL_AUTH_BYPASS |
| **严重级别** | HIGH (P1) |
| **识别关键词** | `越权访问`, `角色缺失`, `权限绕过`, `auth bypass`, `未授权`, `角色隔离` |
| **典型场景** | 护士可执行医生操作、普通用户可访问管理接口、缺少角色权限校验 |
| **匹配堆栈模式** | 权限相关测试失败 + 角色隔离断言失败 |
| **特殊要求** | ⚠️ 修复后必须标记"需人工复核"，且修复方案必须覆盖所有角色组合 |

---

## 规则匹配优先级

当多个规则同时匹配时，按以下优先级排序：
1. **CRITICAL (P0)** 规则优先：SQL_INJECTION > XSS_VULNERABILITY > MEDICAL_DATA_INTEGRITY > MEDICAL_DOSAGE_CALC
2. **HIGH (P1)** 规则其次：NULL_POINTER > INDEX_OUT_OF_BOUNDS > CONCURRENCY > RESOURCE_LEAK > MEDICAL_AUTH_BYPASS
3. **MEDIUM (P2)** 规则：TYPE_CONVERSION > PERFORMANCE > DATA_VALIDATION
4. **LOW (P3)** 规则：CONFIGURATION
