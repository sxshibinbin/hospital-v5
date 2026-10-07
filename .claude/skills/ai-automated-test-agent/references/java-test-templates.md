# Java/Spring Boot 测试模板

## 1. JUnit 5 + Mockito Service 测试

```java
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class PatientServiceTest {

    @Mock
    private PatientMapper patientMapper;

    @Mock
    private PatientValidator patientValidator;

    @InjectMocks
    private PatientService patientService;

    @Test
    void 正常场景_创建患者成功() {
        // given
        PatientCreateDto dto = new PatientCreateDto();
        dto.setName("张三");
        dto.setIdCard("110101199001011234");
        dto.setAge(30);

        when(patientValidator.validate(dto)).thenReturn(ValidationResult.success());
        when(patientMapper.insert(any(Patient.class))).thenReturn(1);

        // when
        Result<Patient> result = patientService.createPatient(dto);

        // then
        assertTrue(result.isSuccess());
        assertNotNull(result.getData());
        verify(patientMapper).insert(any(Patient.class));
    }

    @Test
    void 异常场景_患者年龄为负数_应返回校验失败() {
        // given
        PatientCreateDto dto = new PatientCreateDto();
        dto.setName("李四");
        dto.setAge(-5);

        when(patientValidator.validate(dto)).thenReturn(
            ValidationResult.failure("年龄不能为负数"));

        // when
        Result<Patient> result = patientService.createPatient(dto);

        // then
        assertFalse(result.isSuccess());
        assertEquals("年龄不能为负数", result.getErrorMsg());
        verify(patientMapper, never()).insert(any());
    }

    @Test
    void 边界值场景_患者年龄为0_应正常创建() {
        PatientCreateDto dto = new PatientCreateDto();
        dto.setName("新生儿");
        dto.setAge(0);

        when(patientValidator.validate(dto)).thenReturn(ValidationResult.success());
        when(patientMapper.insert(any(Patient.class))).thenReturn(1);

        Result<Patient> result = patientService.createPatient(dto);

        assertTrue(result.isSuccess());
        verify(patientMapper).insert(any());
    }
}
```

## 2. Spring Boot Controller 接口测试

```java
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.bean.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;

@WebMvcTest(PatientController.class)
class PatientControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PatientService patientService;

    @Test
    void 正常场景_获取患者信息_返回200() throws Exception {
        PatientDto dto = new PatientDto();
        dto.setId(1L);
        dto.setName("张三");
        dto.setGender("男");

        when(patientService.getPatientById(1L)).thenReturn(Result.success(dto));

        mockMvc.perform(get("/api/patient/1")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.name").value("张三"))
            .andDo(print());
    }

    @Test
    void 异常场景_患者不存在_返回404() throws Exception {
        when(patientService.getPatientById(999L))
            .thenReturn(Result.failure("患者不存在"));

        mockMvc.perform(get("/api/patient/999")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.errorMsg").value("患者不存在"));
    }

    @Test
    void 参数校验失败_返回400() throws Exception {
        String invalidBody = "{\"name\":\"\",\"age\":200}";

        mockMvc.perform(post("/api/patient")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidBody))
            .andExpect(status().isBadRequest());
    }
}
```

## 3. MyBatis Mapper 测试（TestContainers）

```java
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.MSSQLServerContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

// 注意：实际项目中建议使用 Flyway/Liquibase + TestContainers
// 此处为示意模板
@SpringBootTest
@Testcontainers
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class PatientMapperTest {

    @Container
    static MSSQLServerContainer<?> sqlServer = new MSSQLServerContainer<>("mcr.microsoft.com/mssql/server:2019-latest")
        .acceptLicense();

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", sqlServer::getJdbcUrl);
        registry.add("spring.datasource.username", sqlServer::getUsername);
        registry.add("spring.datasource.password", sqlServer::getPassword);
    }

    @Autowired
    private PatientMapper patientMapper;

    @Test
    void 正常场景_插入并查询() {
        Patient patient = new Patient();
        patient.setName("测试患者");
        patient.setIdCard("110101199001011234");

        int insertCount = patientMapper.insert(patient);
        assertEquals(1, insertCount);

        Patient found = patientMapper.selectById(patient.getId());
        assertNotNull(found);
        assertEquals("测试患者", found.getName());
    }
}
```

## 4. 权限场景测试

```java
@Test
void 权限场景_护士不能删除患者_返回403() throws Exception {
    // 模拟护士角色
    UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
        "nurse001", null, Collections.singletonList(new SimpleGrantedAuthority("ROLE_NURSE")));

    SecurityContextHolder.getContext().setAuthentication(auth);

    mockMvc.perform(delete("/api/patient/1")
            .accept(MediaType.APPLICATION_JSON))
        .andExpect(status().isForbidden());
}
```

## 5. 参数化边界值测试

```java
@ParameterizedTest
@ValueSource(strings = {"", "ab", "a".repeat(255), "姓名_with_symbol_!@#"})
void 边界值场景_患者姓名字段_各种长度与特殊字符(String name) {
    PatientCreateDto dto = new PatientCreateDto();
    dto.setName(name);
    dto.setAge(30);

    Result<ValidationResult> validationResult = patientValidator.validateName(name);
    // 根据业务规则断言
    assertNotNull(validationResult);
}
```
