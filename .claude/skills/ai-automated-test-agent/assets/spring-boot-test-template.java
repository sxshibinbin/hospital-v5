import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.bean.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.*;

/**
 * {ControllerName} 接口测试
 * 生成时间: {timestamp}
 * 覆盖场景: 正常接口调用、参数校验、异常返回、权限校验
 */
@WebMvcTest({ControllerName}.class)
@DisplayName("{Description}")
class {ControllerName}Test {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private {ServiceName} {service};

    // ==================== 正常场景测试 ====================

    @Test
    @DisplayName("正常场景: GET 请求成功返回数据")
    void 正常场景_获取资源成功() throws Exception {
        // given
        {DataType} data = {createTestData};
        when({service}.{method}(any())).thenReturn(Result.success(data));

        // when & then
        mockMvc.perform(get("/api/{resource}/{id}", {testId})
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data").exists())
            .andDo(print());
    }

    @Test
    @DisplayName("正常场景: POST 创建资源成功")
    void 正常场景_创建资源成功() throws Exception {
        // given
        String requestBody = """
            {
                "name": "{testName}",
                "age": {testAge},
                "gender": "{testGender}"
            }
            """;

        when({service}.{method}(any())).thenReturn(Result.success({testData}));

        // when & then
        mockMvc.perform(post("/api/{resource}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true));
    }

    // ==================== 参数校验测试 ====================

    @Test
    @DisplayName("参数校验: 缺少必填字段返回400")
    void 参数校验_缺少必填字段_返回400() throws Exception {
        String invalidBody = """
            {
                "age": 30
            }
            """;

        mockMvc.perform(post("/api/{resource}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidBody))
            .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("参数校验: 字段格式错误返回400")
    void 参数校验_手机号格式错误_返回400() throws Exception {
        String invalidBody = """
            {
                "name": "测试",
                "phone": "12345"
            }
            """;

        mockMvc.perform(post("/api/{resource}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidBody))
            .andExpect(status().isBadRequest());
    }

    // ==================== 异常场景测试 ====================

    @Test
    @DisplayName("异常场景: 资源不存在返回404")
    void 异常场景_资源不存在_返回404() throws Exception {
        when({service}.{method}(eq({notExistId})))
            .thenReturn(Result.failure("资源不存在"));

        mockMvc.perform(get("/api/{resource}/{id}", {notExistId})
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("异常场景: 服务异常返回500")
    void 异常场景_服务内部异常_返回500() throws Exception {
        when({service}.{method}(any()))
            .thenThrow(new RuntimeException("数据库异常"));

        mockMvc.perform(get("/api/{resource}/{id}", {testId}))
            .andExpect(status().is5xxServerError());
    }

    // ==================== 权限场景测试 ====================

    @Test
    @DisplayName("权限场景: 无权限访问返回403")
    void 权限场景_无权限_返回403() throws Exception {
        // 模拟无权限的安全上下文（根据实际权限框架调整）
        // Spring Security 示例:
        // SecurityMockMvcConfigurers.springSecurity()
        // 以及 mock 用户: .with(user("user").roles("GUEST")))

        mockMvc.perform(delete("/api/{resource}/{id}", {testId}))
            .andExpect(status().isForbidden());
    }
}
