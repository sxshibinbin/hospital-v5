# Vue修复引擎

## 引擎信息
- **技术栈**: Vue 2.x / Vue 3.x
- **支持规则**: 2个
- **风险级别**: low ~ medium

## 支持规则列表

| 规则ID | 规则名称 | 风险级别 | 自动修复 |
|--------|----------|----------|----------|
| COMMON-SEC-003 | XSS风险检查 | medium | ✅ |
| AIMY-MOBILE-001 | 移动端响应式适配 | low | ✅ |

---

## 规则修复实现

### 1. COMMON-SEC-003: XSS风险检查

**风险级别**: medium

**修复策略**: `add_sanitize_wrapper`

**检测模式**:
```regex
v-html\s*=\s*["']([^"']+)["']
```

**修复逻辑**:
1. 检测使用 `v-html` 直接渲染用户输入的代码
2. 添加 DOMPurify 净化处理
3. 确保引入 DOMPurify 依赖

**修复示例**:

```vue
<!-- ========== 修复前 ========== -->
<template>
  <div v-html="userInput"></div>
  <span v-html="comment.content"></span>
</template>

<script>
export default {
  data() {
    return {
      userInput: ''
    }
  }
}
</script>

<!-- ========== 修复后 ========== -->
<template>
  <div v-html="sanitizedUserInput"></div>
  <span v-html="sanitizeHtml(comment.content)"></span>
</template>

<script>
import DOMPurify from 'dompurify'

export default {
  data() {
    return {
      userInput: ''
    }
  },
  computed: {
    sanitizedUserInput() {
      return this.sanitizeHtml(this.userInput)
    }
  },
  methods: {
    sanitizeHtml(html) {
      return DOMPurify.sanitize(html, {
        ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p', 'br'],
        ALLOWED_ATTR: []
      })
    }
  }
}
</script>
```

**Vue 3 Composition API 示例**:

```vue
<!-- ========== 修复后 (Vue 3) ========== -->
<template>
  <div v-html="sanitizedUserInput"></div>
</template>

<script setup>
import { computed } from 'vue'
import DOMPurify from 'dompurify'

const props = defineProps(['userInput'])

const sanitizedUserInput = computed(() => {
  return DOMPurify.sanitize(props.userInput, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p', 'br'],
    ALLOWED_ATTR: []
  })
})
</script>
```

**修复代码模板**:
```python
def fix_xss_vulnerability(content, issue):
    """
    修复XSS漏洞
    """
    import re

    # 检测 v-html 使用
    v_html_pattern = r'v-html\s*=\s*["\']([^"\']+)["\']'
    matches = re.findall(v_html_pattern, content)

    if not matches:
        return content

    modified_content = content

    for match in matches:
        variable_name = match.strip()

        # 跳过已经被包装的情况
        if 'sanitize' in variable_name.lower():
            continue

        # 生成安全变量名
        safe_var_name = f'sanitized{capitalize(variable_name)}'

        # 替换 v-html 绑定
        old_binding = f'v-html="{variable_name}"'
        new_binding = f'v-html="{safe_var_name}"'
        modified_content = modified_content.replace(old_binding, new_binding)

    # 添加 DOMPurify 导入
    if 'dompurify' not in modified_content.lower():
        modified_content = add_dompurify_import(modified_content)

    # 添加净化方法
    if 'sanitizeHtml' not in modified_content:
        modified_content = add_sanitize_method(modified_content)

    return modified_content

def add_dompurify_import(content):
    """添加 DOMPurify 导入"""
    import re

    # 查找 <script> 标签
    script_match = re.search(r'<script[^>]*>', content)
    if script_match:
        insert_pos = script_match.end()
        import_statement = "\nimport DOMPurify from 'dompurify'\n"
        content = content[:insert_pos] + import_statement + content[insert_pos:]

    return content

def add_sanitize_method(content):
    """添加净化方法"""
    # Vue 2 Options API
    methods_pattern = r'methods\s*:\s*\{'
    if re.search(methods_pattern, content):
        sanitize_method = '''
    sanitizeHtml(html) {
      if (!html) return ''
      return DOMPurify.sanitize(html, {
        ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p', 'br'],
        ALLOWED_ATTR: []
      })
    },
'''
        content = re.sub(
            methods_pattern,
            'methods: {' + sanitize_method,
            content
        )

    return content
```

---

### 2. AIMY-MOBILE-001: 移动端响应式适配

**风险级别**: low

**修复策略**: `convert_to_responsive_unit`

**检测模式**:
```regex
(width|height|padding|margin|font-size)\s*:\s*\d+px
```

**修复逻辑**:
1. 检测使用固定像素值的样式
2. 转换为响应式单位（rem/vw）
3. 添加基准设置

**修复示例**:

```vue
<!-- ========== 修复前 ========== -->
<template>
  <div class="container">
    <h1 class="title">标题</h1>
  </div>
</template>

<style scoped>
.container {
  width: 375px;
  padding: 20px;
}

.title {
  font-size: 18px;
  line-height: 24px;
  margin-bottom: 15px;
}
</style>

<!-- ========== 修复后 ========== -->
<template>
  <div class="container">
    <h1 class="title">标题</h1>
  </div>
</template>

<style scoped>
.container {
  width: 100%;
  max-width: 750px;
  padding: 0.5rem;
}

.title {
  font-size: 0.45rem;
  line-height: 0.6rem;
  margin-bottom: 0.375rem;
}

/* 媒体查询适配 */
@media screen and (min-width: 768px) {
  .container {
    max-width: 750px;
    margin: 0 auto;
  }
}
</style>
```

**单位转换规则**:

| 原单位 | 目标单位 | 转换公式 | 说明 |
|--------|----------|----------|------|
| px | rem | px / 40 | 设计稿750px宽度基准 |
| px | vw | px / 7.5 | 视口宽度百分比 |
| px | % | 保持100% | 容器宽度 |

**修复代码模板**:
```python
def fix_responsive_design(content, issue):
    """
    修复移动端响应式适配
    """
    import re

    # 像素转rem的基准（750设计稿）
    REM_BASE = 40  # 1rem = 40px

    # 需要转换的CSS属性
    px_properties = [
        'width', 'height', 'padding', 'margin',
        'font-size', 'line-height', 'border-radius',
        'top', 'left', 'right', 'bottom'
    ]

    # 排除不需要转换的情况
    exclude_patterns = [
        r'border\s*:',          # 边框通常保持px
        r'box-shadow',          # 阴影通常保持px
        r'min-width\s*:\s*1px', # 最小宽度限制
    ]

    def px_to_rem(match):
        value = float(match.group(1))

        # 特殊处理
        if value == 1:  # 1px 边框不转换
            return match.group(0)

        rem_value = value / REM_BASE
        return f'{rem_value:.4f}rem'.rstrip('0').rstrip('.')

    # 查找 <style> 块
    style_pattern = r'(<style[^>]*>)(.*?)(</style>)'

    def process_style_block(match):
        opening_tag = match.group(1)
        style_content = match.group(2)
        closing_tag = match.group(3)

        # 转换 px 为 rem
        px_pattern = r'(\d+)px'
        modified_style = re.sub(px_pattern, px_to_rem, style_content)

        # 添加媒体查询（如果不存在）
        if '@media' not in modified_style and '.container' in modified_style:
            media_query = '''

/* 媒体查询适配 */
@media screen and (min-width: 768px) {
  .container {
    max-width: 750px;
    margin: 0 auto;
  }
}
'''
            modified_style += media_query

        return opening_tag + modified_style + closing_tag

    modified_content = re.sub(style_pattern, process_style_block, content, flags=re.DOTALL)

    return modified_content
```

**响应式最佳实践**:

```css
/* ========== 推荐的响应式写法 ========== */

/* 1. 容器宽度 */
.container {
  width: 100%;
  max-width: 750px;  /* 最大宽度限制 */
  padding: 0 0.5rem;
  box-sizing: border-box;
}

/* 2. 字体大小 */
.text {
  font-size: 0.4rem;     /* 主要文字 */
}

.title {
  font-size: 0.5rem;     /* 标题 */
}

/* 3. 间距 */
.section {
  padding: 0.5rem;
  margin-bottom: 0.375rem;
}

/* 4. 媒体查询 */
@media screen and (max-width: 320px) {
  /* 小屏适配 */
  .text { font-size: 0.35rem; }
}

@media screen and (min-width: 768px) {
  /* 平板/桌面适配 */
  .container {
    max-width: 750px;
    margin: 0 auto;
  }
}
```

---

## 修复引擎接口

```python
class VueFixEngine:
    """Vue修复引擎"""

    def __init__(self):
        self.fix_strategies = {
            'COMMON-SEC-003': self.fix_xss_vulnerability,
            'AIMY-MOBILE-001': self.fix_responsive_design,
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
        语法检查（Vue SFC）
        """
        # 检查 template/script/style 标签匹配
        template_ok = content.count('<template>') == content.count('</template>')
        script_ok = content.count('<script') == content.count('</script>')
        style_ok = content.count('<style') == content.count('</style>')

        return template_ok and script_ok and style_ok
```

---

## 依赖检查

修复前需确认项目依赖：

### DOMPurify
```bash
npm install dompurify
# 或
yarn add dompurify
```

### TypeScript 类型（如使用 TS）
```bash
npm install -D @types/dompurify
```

---

## 注意事项

1. **XSS修复需确认依赖**: 确保 DOMPurify 已安装
2. **响应式转换需统一基准**: 确保团队使用相同的设计稿基准
3. **测试多端适配**: 修复后需在不同设备尺寸下测试
4. **Vue 2/3 兼容**: 根据项目版本选择合适的 API 风格
