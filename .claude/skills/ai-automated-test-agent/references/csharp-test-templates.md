# C# WinForms/WebView2 测试模板

## 1. NUnit + Moq 单元测试

```csharp
using NUnit.Framework;
using Moq;
using System;
using System.Threading.Tasks;

[TestFixture]
public class TtsServiceTests
{
    private Mock<ITtsEngine> _mockEngine;
    private TtsService _service;

    [SetUp]
    public void Setup()
    {
        _mockEngine = new Mock<ITtsEngine>();
        _service = new TtsService(_mockEngine.Object);
    }

    [Test]
    public async Task 正常场景_语音合成成功()
    {
        // Arrange
        var text = "患者体温正常";
        var expectedAudio = new byte[] { 0x01, 0x02, 0x03 };

        _mockEngine.Setup(e => e.SynthesizeAsync(text))
            .ReturnsAsync(expectedAudio);

        // Act
        var result = await _service.SpeakTextAsync(text);

        // Assert
        Assert.IsTrue(result.Success);
        Assert.AreEqual(expectedAudio, result.AudioData);
        _mockEngine.Verify(e => e.SynthesizeAsync(text), Times.Once);
    }

    [Test]
    public async Task 异常场景_空文本_返回错误()
    {
        var result = await _service.SpeakTextAsync(string.Empty);

        Assert.IsFalse(result.Success);
        Assert.AreEqual("文本内容不能为空", result.ErrorMessage);
        _mockEngine.Verify(e => e.SynthesizeAsync(It.IsAny<string>()), Times.Never);
    }

    [Test]
    public async Task 异常场景_引擎超时_返回超时错误()
    {
        _mockEngine.Setup(e => e.SynthesizeAsync(It.IsAny<string>()))
            .ThrowsAsync(new TimeoutException("TTS引擎响应超时"));

        var result = await _service.SpeakTextAsync("测试文本");

        Assert.IsFalse(result.Success);
        Assert.IsTrue(result.ErrorMessage.Contains("超时"));
    }
}
```

## 2. WebView2 交互测试

```csharp
using NUnit.Framework;
using Moq;
using Microsoft.Web.WebView2.WinForms;
using Microsoft.Web.WebView2.Core;

[TestFixture]
public class WebView2HostObjectTests
{
    private Mock<CoreWebView2> _mockWebView2;
    private WebView2Bridge _bridge;

    [SetUp]
    public void Setup()
    {
        _mockWebView2 = new Mock<CoreWebView2>();
        _bridge = new WebView2Bridge();
    }

    [Test]
    public void 正常场景_HostObject注入成功()
    {
        // Arrange
        var mockHostObject = new Mock<IBrowserHost>();

        // Act
        _bridge.RegisterHostObject("browser", mockHostObject.Object);

        // Assert
        Assert.IsTrue(_bridge.IsHostObjectRegistered("browser"));
    }

    [Test]
    public void 异常场景_重复注册_抛出异常()
    {
        var mockHostObject = new Mock<IBrowserHost>();
        _bridge.RegisterHostObject("browser", mockHostObject.Object);

        Assert.Throws<InvalidOperationException>(() =>
            _bridge.RegisterHostObject("browser", mockHostObject.Object));
    }

    [Test]
    public void PluginOK_中间件初始化_COM组件加载成功()
    {
        var pluginOk = new PluginOkMiddleware();

        var result = pluginOk.Initialize();

        Assert.IsTrue(result);
        Assert.IsTrue(pluginOk.IsConnected);
    }
}
```

## 3. WinForms 表单交互测试

```csharp
[TestFixture]
public class PatientFormTests
{
    [Test]
    public void 正常场景_保存按钮状态_字段完整时可用()
    {
        var form = new PatientForm();
        form.SetPatientName("张三");
        form.SetAge("30");
        form.SetGender("男");

        Assert.IsTrue(form.SaveButton.Enabled);
    }

    [Test]
    public void 边界值场景_姓名为空_保存按钮禁用()
    {
        var form = new PatientForm();
        form.SetPatientName("");  // 空字符串
        form.SetAge("30");
        form.SetGender("男");

        Assert.IsFalse(form.SaveButton.Enabled);
    }

    [Test]
    public void 异常场景_年龄格式错误_显示校验提示()
    {
        var form = new PatientForm();
        form.SetAge("abc");

        Assert.IsFalse(form.IsValid);
        StringAssert.Contains("请输入有效数字", form.ValidationMessage);
    }
}
```
