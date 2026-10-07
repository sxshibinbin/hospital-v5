import 'dart:convert';
import 'package:flutter/material.dart';
import 'health_monitoring_screen.dart';
import 'iot_api_client.dart';

class DeviceDetailScreen extends StatefulWidget {
  final DeviceData device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final Map<String, dynamic> _params = {};
  final Set<String> _dirtyFields = {};

  // 新增参数状态
  late TextEditingController _heartRateIntervalController;
  late TextEditingController _temperatureIntervalController;
  late TextEditingController _fallSensitivityController;
  late TextEditingController _fallHeightController;
  late TextEditingController _unmannedTimerController;
  late TextEditingController _heartRateAlarmLowThresholdController;
  late TextEditingController _heartRateAlarmHighThresholdController;
  late TextEditingController _heartRateAlarmDurationController;
  late TextEditingController _breathingAlarmLowThresholdController;
  late TextEditingController _breathingAlarmHighThresholdController;
  late TextEditingController _breathingAlarmDurationController;
  late TextEditingController _leaveBedAlarmDurationController;
  late TextEditingController _unmannedAlarmDurationController;
  bool _pedometerEnabled = false;
  bool _fallAlarmEnabled = false;
  bool _personPresentAlarmEnabled = false;
  bool _personAbsentAlarmEnabled = false;
  bool _heartRateEnabled = true;
  bool _breathEnabled = true;
  bool _sleepEnabled = true;
  bool _unmannedTimerEnabled = true;
  bool _presenceEnabled = true;
  bool _struggleEnabled = false;
  bool _alarmPromptToneEnabled = false;
  bool _tamperAlarmEnabled = false;
  bool _pullRopeAlarmEnabled = false;
  bool _heartRateAbnormalAlarmEnabled = false;
  bool _breathingAbnormalAlarmEnabled = false;
  bool _leaveBedAlarmEnabled = false;
  bool _unmannedAlarmEnabled = false;
  int _detectionMode = 1;
  int _sleepRadarParamTabIndex = 0;
  TimeOfDay? _sleepStartTime;
  TimeOfDay? _sleepEndTime;

  bool _isLoading = true;
  bool _isSaving = false;
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, dynamic> _fallRadarParamValues = {};
  final Map<String, dynamic> _sleepRadarParamValues = {};
  final Map<String, dynamic> _sleepRadarAlarmParamValues = {};

  @override
  void initState() {
    super.initState();
    _heartRateIntervalController = TextEditingController(text: '');
    _temperatureIntervalController = TextEditingController(text: '');
    _fallSensitivityController = TextEditingController(text: '');
    _fallHeightController = TextEditingController(text: '');
    _unmannedTimerController = TextEditingController(text: '60');
    _heartRateAlarmLowThresholdController = TextEditingController(text: '0');
    _heartRateAlarmHighThresholdController = TextEditingController(text: '0');
    _heartRateAlarmDurationController = TextEditingController(text: '0');
    _breathingAlarmLowThresholdController = TextEditingController(text: '0');
    _breathingAlarmHighThresholdController = TextEditingController(text: '0');
    _breathingAlarmDurationController = TextEditingController(text: '0');
    _leaveBedAlarmDurationController = TextEditingController(text: '0');
    _unmannedAlarmDurationController = TextEditingController(text: '0');

    _focusNodes['heartRateInterval'] = FocusNode();
    _focusNodes['temperatureInterval'] = FocusNode();
    _focusNodes['fallSensitivity'] = FocusNode();
    _focusNodes['fallHeight'] = FocusNode();
    _focusNodes['unmannedTimerDuration'] = FocusNode();
    _focusNodes['heartRateAlarmLowThreshold'] = FocusNode();
    _focusNodes['heartRateAlarmHighThreshold'] = FocusNode();
    _focusNodes['heartRateAlarmDuration'] = FocusNode();
    _focusNodes['breathingAlarmLowThreshold'] = FocusNode();
    _focusNodes['breathingAlarmHighThreshold'] = FocusNode();
    _focusNodes['breathingAlarmDuration'] = FocusNode();
    _focusNodes['leaveBedAlarmDuration'] = FocusNode();
    _focusNodes['unmannedAlarmDuration'] = FocusNode();

    // Add focus listeners for auto-save on focus loss
    for (final entry in _focusNodes.entries) {
      final fieldName = entry.key;
      entry.value.addListener(() {
        if (!entry.value.hasFocus) {
          if (widget.device.type == '睡眠雷达' &&
              _isSleepRadarBatchField(fieldName)) {
            return;
          }
          final controller = _getControllerForField(fieldName);
          if (controller != null) {
            final defaultValues = <String, String>{
              'heartRateInterval': '300',
              'temperatureInterval': '1',
              'fallSensitivity': '1',
              'fallHeight': '10',
              'unmannedTimerDuration': '60',
              'heartRateAlarmLowThreshold': '0',
              'heartRateAlarmHighThreshold': '0',
              'heartRateAlarmDuration': '0',
              'breathingAlarmLowThreshold': '0',
              'breathingAlarmHighThreshold': '0',
              'breathingAlarmDuration': '0',
              'leaveBedAlarmDuration': '0',
              'unmannedAlarmDuration': '0',
            };
            _onSaveField(fieldName, controller, defaultValues[fieldName] ?? '');
          }
        }
      });
    }

    _loadDeviceParams();
  }

  Future<void> _loadDeviceParams() async {
    setState(() => _isLoading = true);
    try {
      final data = await iotPostJson(
        context,
        '/api/iot/device/param/get',
        body: {'deviceImei': widget.device.imei},
        operation: 'load IoT device params',
      );

      if (data['success'] == true && data['data'] != null) {
        _parseParamsFromApi(data['data'] as List<dynamic>);
      }
    } on IotApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      debugPrint('Load params error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseParamsFromApi(List<dynamic> params) {
    final deviceType = widget.device.type;
    final isWearable = deviceType == '智能手表' || deviceType == '智能手环';
    final isSleepRadar = deviceType == '睡眠雷达';
    final isFallRadar = deviceType == '跌倒雷达';

    for (var param in params) {
      final paramCode = param['paramCode']?.toString() ?? '';
      final paramValue = param['paramValue']?.toString() ?? '';

      if (isWearable) {
        _parseWearableParam(paramCode, paramValue);
      } else if (isSleepRadar) {
        _parseSleepRadarParam(paramCode, paramValue);
      } else if (isFallRadar) {
        _parseFallRadarParam(paramCode, paramValue);
      }
    }
  }

  void _parseWearableParam(String paramCode, String paramValue) {
    switch (paramCode) {
      case '667': // 心率上传间隔
        _heartRateIntervalController.text = paramValue;
        _params['heartRateInterval'] = int.tryParse(paramValue);
        break;
      case '670': // 体温上传间隔
        _temperatureIntervalController.text = paramValue;
        _params['temperatureInterval'] = int.tryParse(paramValue);
        break;
      case '654': // 计步器开关
        final enabled = paramValue == '1';
        setState(() => _pedometerEnabled = enabled);
        _params['pedometerEnabled'] = enabled;
        break;
      case '666': // 睡眠时间段
        try {
          final json = jsonDecode(paramValue);
          final start = json['start0']?.toString() ?? '22:00:00';
          final end = json['end0']?.toString() ?? '06:00:00';
          // 解析 HH:mm:ss 格式，只取 HH:mm
          final startParts = start.split(':');
          final endParts = end.split(':');
          if (startParts.length >= 2 && endParts.length >= 2) {
            final startHour = int.tryParse(startParts[0]) ?? 22;
            final startMinute = int.tryParse(startParts[1]) ?? 0;
            final endHour = int.tryParse(endParts[0]) ?? 6;
            final endMinute = int.tryParse(endParts[1]) ?? 0;
            setState(() {
              _sleepStartTime = TimeOfDay(hour: startHour, minute: startMinute);
              _sleepEndTime = TimeOfDay(hour: endHour, minute: endMinute);
            });
            _params['sleepStartTime'] =
                '${startParts[0].padLeft(2, '0')}:${startParts[1].padLeft(2, '0')}';
            _params['sleepEndTime'] =
                '${endParts[0].padLeft(2, '0')}:${endParts[1].padLeft(2, '0')}';
          }
        } catch (e) {
          debugPrint('Parse sleep time error: $e');
        }
        break;
      case '678': // 跌倒报警开关
        try {
          final json = jsonDecode(paramValue);
          final enabled = json['switchAlarm']?.toString() == '1';
          setState(() => _fallAlarmEnabled = enabled);
          _params['fallAlarmEnabled'] = enabled;
        } catch (e) {
          debugPrint('Parse fall alarm error: $e');
        }
        break;
      case '687': // 跌倒灵敏度
        _fallSensitivityController.text = paramValue;
        _params['fallSensitivity'] = int.tryParse(paramValue);
        break;
    }
  }

  void _parseSleepRadarParam(String paramCode, String paramValue) {
    if (paramCode == '381') {
      _parseSleepRadarAlarmParam(paramValue);
      return;
    }
    if (paramCode != '360') return;
    try {
      final json = jsonDecode(paramValue);
      json.forEach((key, value) {
        _sleepRadarParamValues[key.toString()] = value;
        final strValue = value.toString();
        switch (key) {
          case 'detectionMode':
            setState(() => _detectionMode = int.tryParse(strValue) ?? 0);
            _params['detectionMode'] = int.tryParse(strValue);
            break;
          case 'heartRateSwitch':
            setState(() => _heartRateEnabled = strValue == '1');
            _params['heartRateEnabled'] = strValue == '1';
            break;
          case 'breathingSwitch':
            setState(() => _breathEnabled = strValue == '1');
            _params['breathEnabled'] = strValue == '1';
            break;
          case 'sleepSwitch':
            setState(() => _sleepEnabled = strValue == '1');
            _params['sleepEnabled'] = strValue == '1';
            break;
          case 'longTimeNoTimerSwitch':
            setState(() => _unmannedTimerEnabled = strValue == '1');
            _params['unmannedTimerEnabled'] = strValue == '1';
            break;
          case 'unmanneDuration':
            _unmannedTimerController.text = strValue;
            _params['unmannedTimerDuration'] = int.tryParse(strValue);
            break;
          case 'existSwitch':
            setState(() => _presenceEnabled = strValue == '1');
            _params['presenceEnabled'] = strValue == '1';
            break;
          case 'abnormalStruggleSwitch':
            setState(() => _struggleEnabled = strValue == '1');
            _params['struggleEnabled'] = strValue == '1';
            break;
        }
      });
    } catch (e) {
      debugPrint('Parse sleep radar param error: $e');
    }
  }

  void _parseSleepRadarAlarmParam(String paramValue) {
    try {
      final json = jsonDecode(paramValue);
      json.forEach((key, value) {
        _sleepRadarAlarmParamValues[key.toString()] = value;
        final strValue = value.toString();
        switch (key) {
          case 'promptTone':
            setState(() => _alarmPromptToneEnabled = strValue == '1');
            _params['alarmPromptToneEnabled'] = strValue == '1';
            break;
          case 'FC_ALM_SW':
            setState(() => _tamperAlarmEnabled = strValue == '1');
            _params['tamperAlarmEnabled'] = strValue == '1';
            break;
          case 'LS_ALM_SW':
            setState(() => _pullRopeAlarmEnabled = strValue == '1');
            _params['pullRopeAlarmEnabled'] = strValue == '1';
            break;
          case 'HEARTRATE_ALM_SW_SWITCH':
            setState(() => _heartRateAbnormalAlarmEnabled = strValue == '1');
            _params['heartRateAbnormalAlarmEnabled'] = strValue == '1';
            break;
          case 'HEARTRATE_ALM_SW_LOW':
            _heartRateAlarmLowThresholdController.text = strValue;
            _params['heartRateAlarmLowThreshold'] = int.tryParse(strValue);
            break;
          case 'HEARTRATE_ALM_SW_HIGH':
            _heartRateAlarmHighThresholdController.text = strValue;
            _params['heartRateAlarmHighThreshold'] = int.tryParse(strValue);
            break;
          case 'HEARTRATE_ALM_SW_TIME':
            _heartRateAlarmDurationController.text = strValue;
            _params['heartRateAlarmDuration'] = int.tryParse(strValue);
            break;
          case 'BREATHING_ALM_SW_SWITCH':
            setState(() => _breathingAbnormalAlarmEnabled = strValue == '1');
            _params['breathingAbnormalAlarmEnabled'] = strValue == '1';
            break;
          case 'BREATHING_ALM_SW_LOW':
            _breathingAlarmLowThresholdController.text = strValue;
            _params['breathingAlarmLowThreshold'] = int.tryParse(strValue);
            break;
          case 'BREATHING_ALM_SW_HIGH':
            _breathingAlarmHighThresholdController.text = strValue;
            _params['breathingAlarmHighThreshold'] = int.tryParse(strValue);
            break;
          case 'BREATHING_ALM_SW_TIME':
            _breathingAlarmDurationController.text = strValue;
            _params['breathingAlarmDuration'] = int.tryParse(strValue);
            break;
          case 'BED_ALM_SW_SWITCH':
            setState(() => _leaveBedAlarmEnabled = strValue == '1');
            _params['leaveBedAlarmEnabled'] = strValue == '1';
            break;
          case 'BED_ALM_SW_TIME':
            _leaveBedAlarmDurationController.text = strValue;
            _params['leaveBedAlarmDuration'] = int.tryParse(strValue);
            break;
          case 'UNMANNED_ALM_SW_SWITCH':
            setState(() => _unmannedAlarmEnabled = strValue == '1');
            _params['unmannedAlarmEnabled'] = strValue == '1';
            break;
          case 'UNMANNED_ALM_SW_TIME':
            _unmannedAlarmDurationController.text = strValue;
            _params['unmannedAlarmDuration'] = int.tryParse(strValue);
            break;
        }
      });
    } catch (e) {
      debugPrint('Parse sleep radar alarm param error: $e');
    }
  }

  void _parseFallRadarParam(String paramCode, String paramValue) {
    if (paramCode != '43') return;
    try {
      final json = jsonDecode(paramValue);
      json.forEach((key, value) {
        _fallRadarParamValues[key.toString()] = value;
        final strValue = value.toString();
        switch (key) {
          case 'someoneAlmSwitch':
            setState(() => _personPresentAlarmEnabled = strValue == '1');
            _params['personPresentAlarm'] = strValue == '1';
            break;
          case 'unmannedAlmSwitch':
            setState(() => _personAbsentAlarmEnabled = strValue == '1');
            _params['personAbsentAlarm'] = strValue == '1';
            break;
          case 'fall_Height':
            _fallHeightController.text = strValue;
            _params['fallHeight'] = int.tryParse(strValue);
            break;
        }
      });
    } catch (e) {
      debugPrint('Parse fall radar param error: $e');
    }
  }

  @override
  void dispose() {
    _heartRateIntervalController.dispose();
    _temperatureIntervalController.dispose();
    _fallSensitivityController.dispose();
    _fallHeightController.dispose();
    _unmannedTimerController.dispose();
    _heartRateAlarmLowThresholdController.dispose();
    _heartRateAlarmHighThresholdController.dispose();
    _heartRateAlarmDurationController.dispose();
    _breathingAlarmLowThresholdController.dispose();
    _breathingAlarmHighThresholdController.dispose();
    _breathingAlarmDurationController.dispose();
    _leaveBedAlarmDurationController.dispose();
    _unmannedAlarmDurationController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDE8FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2F266F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '设备详情',
          style: TextStyle(
            color: Color(0xFF2F266F),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Device header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF0EAFF), Color(0xFFF8F5FD)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.type,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2F266F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.device.model} · ${widget.device.imei}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9891B8),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

                // Content - 直接显示设备参数
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 50),
                    child: _buildParamsSection(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildParamsSection() {
    final deviceType = widget.device.type;
    final isWearable = deviceType == '智能手表' || deviceType == '智能手环';
    final isFallRadar = deviceType == '跌倒雷达';
    final isSleepRadar = deviceType == '睡眠雷达';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0ECF8), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F266F).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSleepRadar) ...[
                _buildSleepRadarParamTabs(),
                const SizedBox(height: 16),
                if (_sleepRadarParamTabIndex == 0)
                  ..._buildSleepRadarDeviceParamRows()
                else
                  ..._buildSleepRadarAlarmParamRows(),
              ],

              if (isWearable) ...[
                _buildIntervalInputRow(
                  '心率上传间隔',
                  'heartRateInterval',
                  _heartRateIntervalController,
                  _focusNodes['heartRateInterval']!,
                  '秒',
                  '300~65535',
                ),
                const SizedBox(height: 12),

                _buildIntervalInputRow(
                  '体温上传间隔',
                  'temperatureInterval',
                  _temperatureIntervalController,
                  _focusNodes['temperatureInterval']!,
                  '时',
                  '1~168',
                ),
                const SizedBox(height: 12),

                _buildSwitchRow('计步器开关', _pedometerEnabled, (value) {
                  _saveImmediateSwitch(
                    previousValue: _pedometerEnabled,
                    value: value,
                    applyValue: (v) => _pedometerEnabled = v,
                    paramCode: '654',
                    buildParamValue: (v) => v ? '1' : '0',
                  );
                }),
                const SizedBox(height: 12),

                _buildSleepTimeRow(),
                const SizedBox(height: 12),

                _buildSwitchRow('跌倒报警开关', _fallAlarmEnabled, (value) {
                  _saveImmediateSwitch(
                    previousValue: _fallAlarmEnabled,
                    value: value,
                    applyValue: (v) => _fallAlarmEnabled = v,
                    paramCode: '678',
                    buildParamValue: (value) => jsonEncode({
                      'switchAlarm': value ? '1' : '0',
                      'switchCall': '0',
                    }),
                  );
                }),
                const SizedBox(height: 12),

                _buildIntervalInputRow(
                  '跌倒灵敏度',
                  'fallSensitivity',
                  _fallSensitivityController,
                  _focusNodes['fallSensitivity']!,
                  '',
                  '1~8',
                ),
              ],

              if (isFallRadar) ...[
                _buildSwitchRow('有人报警开关', _personPresentAlarmEnabled, (value) {
                  setState(() => _personPresentAlarmEnabled = value);
                  _saveFallRadarParams();
                }),
                const SizedBox(height: 12),

                _buildSwitchRow('无人报警开关', _personAbsentAlarmEnabled, (value) {
                  setState(() => _personAbsentAlarmEnabled = value);
                  _saveFallRadarParams();
                }),
                const SizedBox(height: 12),

                _buildIntervalInputRow(
                  '跌倒高度',
                  'fallHeight',
                  _fallHeightController,
                  _focusNodes['fallHeight']!,
                  'cm',
                  '10~100',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSleepRadarParamTabs() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E3F5), width: 1),
      ),
      child: Row(
        children: [
          _buildSleepRadarParamTab('设备参数', 0),
          const SizedBox(width: 4),
          _buildSleepRadarParamTab('报警参数', 1),
        ],
      ),
    );
  }

  Widget _buildSleepRadarParamTab(String label, int index) {
    final selected = _sleepRadarParamTabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _sleepRadarParamTabIndex = index);
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2F266F).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF5B57F7)
                  : const Color(0xFF9891B8),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSleepRadarDeviceParamRows() {
    return [
      _buildKeyValueSelectRow(
        '探测模式',
        _detectionMode,
        {0: '实时探测模式', 1: '睡眠探测模式'},
        (value) {
          setState(() => _detectionMode = value);
          _markSleepRadarFieldDirty('detectionMode');
        },
      ),
      const SizedBox(height: 12),
      _buildSwitchRow('心率开关', _heartRateEnabled, (value) {
        setState(() => _heartRateEnabled = value);
        _markSleepRadarFieldDirty('heartRateEnabled');
      }),
      const SizedBox(height: 12),
      _buildSwitchRow('呼吸开关', _breathEnabled, (value) {
        setState(() => _breathEnabled = value);
        _markSleepRadarFieldDirty('breathEnabled');
      }),
      const SizedBox(height: 12),
      _buildSwitchRow('睡眠开关', _sleepEnabled, (value) {
        setState(() => _sleepEnabled = value);
        _markSleepRadarFieldDirty('sleepEnabled');
      }),
      const SizedBox(height: 12),
      _buildSwitchRow('长时间无人计时开关', _unmannedTimerEnabled, (value) {
        setState(() => _unmannedTimerEnabled = value);
        _markSleepRadarFieldDirty('unmannedTimerEnabled');
      }),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '无人计时时长',
        'unmannedTimerDuration',
        _unmannedTimerController,
        _focusNodes['unmannedTimerDuration']!,
        '分钟',
        '30~180',
      ),
      const SizedBox(height: 12),
      _buildSwitchRow('存在开关', _presenceEnabled, (value) {
        setState(() => _presenceEnabled = value);
        _markSleepRadarFieldDirty('presenceEnabled');
      }),
      const SizedBox(height: 12),
      _buildSwitchRow('异常挣扎开关', _struggleEnabled, (value) {
        setState(() => _struggleEnabled = value);
        _markSleepRadarFieldDirty('struggleEnabled');
      }),
      const SizedBox(height: 18),
      _buildConfirmButton('确定', _saveSleepRadarDeviceParams),
    ];
  }

  List<Widget> _buildSleepRadarAlarmParamRows() {
    return [
      _buildSwitchRow('报警提示音开关', _alarmPromptToneEnabled, (value) {
        setState(() => _alarmPromptToneEnabled = value);
        _markSleepRadarFieldDirty('alarmPromptToneEnabled');
      }),
      const SizedBox(height: 12),
      _buildSwitchRow('防拆报警开关', _tamperAlarmEnabled, (value) {
        setState(() => _tamperAlarmEnabled = value);
        _markSleepRadarFieldDirty('tamperAlarmEnabled');
      }),
      const SizedBox(height: 12),
      _buildSwitchRow('拉绳报警开关', _pullRopeAlarmEnabled, (value) {
        setState(() => _pullRopeAlarmEnabled = value);
        _markSleepRadarFieldDirty('pullRopeAlarmEnabled');
      }),
      const SizedBox(height: 12),
      _buildSwitchRow('连续心率异常报警开关', _heartRateAbnormalAlarmEnabled, (value) {
        setState(() => _heartRateAbnormalAlarmEnabled = value);
        _markSleepRadarFieldDirty('heartRateAbnormalAlarmEnabled');
      }),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '连续心率异常报警低阈值',
        'heartRateAlarmLowThreshold',
        _heartRateAlarmLowThresholdController,
        _focusNodes['heartRateAlarmLowThreshold']!,
        '',
        '0~200',
      ),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '连续心率异常报警高阈值',
        'heartRateAlarmHighThreshold',
        _heartRateAlarmHighThresholdController,
        _focusNodes['heartRateAlarmHighThreshold']!,
        '',
        '0~200',
      ),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '连续心率异常报警持续时间',
        'heartRateAlarmDuration',
        _heartRateAlarmDurationController,
        _focusNodes['heartRateAlarmDuration']!,
        '秒',
        '0~3600',
      ),
      const SizedBox(height: 12),
      _buildSwitchRow('连续呼吸异常报警开关', _breathingAbnormalAlarmEnabled, (value) {
        setState(() => _breathingAbnormalAlarmEnabled = value);
        _markSleepRadarFieldDirty('breathingAbnormalAlarmEnabled');
      }),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '连续呼吸异常报警低阈值',
        'breathingAlarmLowThreshold',
        _breathingAlarmLowThresholdController,
        _focusNodes['breathingAlarmLowThreshold']!,
        '',
        '0~200',
      ),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '连续呼吸异常报警高阈值',
        'breathingAlarmHighThreshold',
        _breathingAlarmHighThresholdController,
        _focusNodes['breathingAlarmHighThreshold']!,
        '',
        '0~200',
      ),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '连续呼吸异常报警持续时间',
        'breathingAlarmDuration',
        _breathingAlarmDurationController,
        _focusNodes['breathingAlarmDuration']!,
        '秒',
        '0~3600',
      ),
      const SizedBox(height: 12),
      _buildSwitchRow('离床报警开关', _leaveBedAlarmEnabled, (value) {
        setState(() => _leaveBedAlarmEnabled = value);
        _markSleepRadarFieldDirty('leaveBedAlarmEnabled');
      }),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '离床报警持续时间',
        'leaveBedAlarmDuration',
        _leaveBedAlarmDurationController,
        _focusNodes['leaveBedAlarmDuration']!,
        '分钟',
        '0~1440',
      ),
      const SizedBox(height: 12),
      _buildSwitchRow('无人报警开关', _unmannedAlarmEnabled, (value) {
        setState(() => _unmannedAlarmEnabled = value);
        _markSleepRadarFieldDirty('unmannedAlarmEnabled');
      }),
      const SizedBox(height: 12),
      _buildIntervalInputRow(
        '无人报警持续时间',
        'unmannedAlarmDuration',
        _unmannedAlarmDurationController,
        _focusNodes['unmannedAlarmDuration']!,
        '分钟',
        '0~1440',
      ),
      const SizedBox(height: 18),
      _buildConfirmButton('确定', _saveSleepRadarAlarmParams),
    ];
  }

  void _markSleepRadarFieldDirty(String fieldName) {
    setState(() => _dirtyFields.add(fieldName));
  }

  Set<String> _sleepRadarDeviceBatchFields() {
    return const {
      'detectionMode',
      'heartRateEnabled',
      'breathEnabled',
      'sleepEnabled',
      'unmannedTimerEnabled',
      'unmannedTimerDuration',
      'presenceEnabled',
      'struggleEnabled',
    };
  }

  Set<String> _sleepRadarAlarmBatchFields() {
    return const {
      'alarmPromptToneEnabled',
      'tamperAlarmEnabled',
      'pullRopeAlarmEnabled',
      'heartRateAbnormalAlarmEnabled',
      'breathingAbnormalAlarmEnabled',
      'leaveBedAlarmEnabled',
      'unmannedAlarmEnabled',
      'heartRateAlarmLowThreshold',
      'heartRateAlarmHighThreshold',
      'heartRateAlarmDuration',
      'breathingAlarmLowThreshold',
      'breathingAlarmHighThreshold',
      'breathingAlarmDuration',
      'leaveBedAlarmDuration',
      'unmannedAlarmDuration',
    };
  }

  bool _isSleepRadarBatchField(String fieldName) {
    return _sleepRadarDeviceBatchFields().contains(fieldName) ||
        _sleepRadarAlarmBatchFields().contains(fieldName);
  }

  Widget _buildConfirmButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5B57F7),
          disabledBackgroundColor: const Color(0xFFC8C3E8),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          _isSaving ? '保存中...' : label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String? _validateIntField(
    String label,
    TextEditingController controller,
    int min,
    int max,
    int defaultValue,
  ) {
    final value = controller.text.trim().isEmpty
        ? defaultValue.toString()
        : controller.text.trim();
    final parsedValue = int.tryParse(value);
    if (parsedValue == null || parsedValue < min || parsedValue > max) {
      _showError('$label范围为 $min~$max');
      return null;
    }
    return value;
  }

  void _saveSleepRadarDeviceParams() {
    FocusScope.of(context).unfocus();
    final unmannedTimerValue = _validateIntField(
      '无人计时时长',
      _unmannedTimerController,
      30,
      180,
      60,
    );
    if (unmannedTimerValue == null) {
      return;
    }

    _unmannedTimerController.text = unmannedTimerValue;
    _saveSleepRadarParams(
      unmannedTimerValue: unmannedTimerValue,
      onSuccess: () {
        setState(() => _dirtyFields.removeAll(_sleepRadarDeviceBatchFields()));
      },
    );
  }

  void _saveSleepRadarAlarmParams() {
    FocusScope.of(context).unfocus();
    final fieldRules = [
      (
        label: '连续心率异常报警低阈值',
        controller: _heartRateAlarmLowThresholdController,
        max: 200,
      ),
      (
        label: '连续心率异常报警高阈值',
        controller: _heartRateAlarmHighThresholdController,
        max: 200,
      ),
      (
        label: '连续心率异常报警持续时间',
        controller: _heartRateAlarmDurationController,
        max: 3600,
      ),
      (
        label: '连续呼吸异常报警低阈值',
        controller: _breathingAlarmLowThresholdController,
        max: 200,
      ),
      (
        label: '连续呼吸异常报警高阈值',
        controller: _breathingAlarmHighThresholdController,
        max: 200,
      ),
      (
        label: '连续呼吸异常报警持续时间',
        controller: _breathingAlarmDurationController,
        max: 3600,
      ),
      (
        label: '离床报警持续时间',
        controller: _leaveBedAlarmDurationController,
        max: 1440,
      ),
      (
        label: '无人报警持续时间',
        controller: _unmannedAlarmDurationController,
        max: 1440,
      ),
    ];

    for (final rule in fieldRules) {
      final value = _validateIntField(
        rule.label,
        rule.controller,
        0,
        rule.max,
        0,
      );
      if (value == null) {
        return;
      }
      rule.controller.text = value;
    }

    _saveSleepRadarAlarmParamSet(
      onSuccess: () {
        setState(() => _dirtyFields.removeAll(_sleepRadarAlarmBatchFields()));
      },
    );
  }

  Widget _buildIntervalInputRow(
    String label,
    String fieldName,
    TextEditingController controller,
    FocusNode focusNode,
    String unit,
    String range,
  ) {
    final isDirty = _dirtyFields.contains(fieldName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9891B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F266F),
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8F6FF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDirty
                      ? const Color(0xFFFF9800)
                      : const Color(0xFFE7E3F5),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDirty
                      ? const Color(0xFFFF9800)
                      : const Color(0xFFE7E3F5),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF5B57F7),
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) {
              setState(() => _dirtyFields.add(fieldName));
            },
          ),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              unit,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9891B8)),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          '范围：$range',
          style: const TextStyle(fontSize: 10, color: Color(0xFFB8B0D0)),
        ),
      ],
    );
  }

  TextEditingController? _getControllerForField(String fieldName) {
    switch (fieldName) {
      case 'heartRateInterval':
        return _heartRateIntervalController;
      case 'temperatureInterval':
        return _temperatureIntervalController;
      case 'fallSensitivity':
        return _fallSensitivityController;
      case 'fallHeight':
        return _fallHeightController;
      case 'unmannedTimerDuration':
        return _unmannedTimerController;
      case 'heartRateAlarmLowThreshold':
        return _heartRateAlarmLowThresholdController;
      case 'heartRateAlarmHighThreshold':
        return _heartRateAlarmHighThresholdController;
      case 'heartRateAlarmDuration':
        return _heartRateAlarmDurationController;
      case 'breathingAlarmLowThreshold':
        return _breathingAlarmLowThresholdController;
      case 'breathingAlarmHighThreshold':
        return _breathingAlarmHighThresholdController;
      case 'breathingAlarmDuration':
        return _breathingAlarmDurationController;
      case 'leaveBedAlarmDuration':
        return _leaveBedAlarmDurationController;
      case 'unmannedAlarmDuration':
        return _unmannedAlarmDurationController;
      default:
        return null;
    }
  }

  int _parseIntOrDefault(String value, int defaultValue) {
    return int.tryParse(value.trim()) ?? defaultValue;
  }

  String _buildSleepRadarParamValue({String? unmannedTimerValue}) {
    final duration = _parseIntOrDefault(
      unmannedTimerValue ?? _unmannedTimerController.text,
      60,
    );

    final payload = <String, dynamic>{..._sleepRadarParamValues}
      ..removeWhere(
        (key, value) => _sleepRadarLegacyAlarmParamKeys().contains(key),
      );
    payload.addAll({
      'detectionMode': '$_detectionMode',
      'sleepSwitch': _sleepEnabled ? '1' : '0',
      'heartRateSwitch': _heartRateEnabled ? '1' : '0',
      'unmanneDuration': duration,
      'existSwitch': _presenceEnabled ? '1' : '0',
      'breathingSwitch': _breathEnabled ? '1' : '0',
      'longTimeNoTimerSwitch': _unmannedTimerEnabled ? '1' : '0',
      'abnormalStruggleSwitch': _struggleEnabled ? '1' : '0',
    });

    return jsonEncode(payload);
  }

  Set<String> _sleepRadarLegacyAlarmParamKeys() {
    return const {
      'promptTone',
      'tamperAlarmSwitch',
      'pullRopeAlarmSwitch',
      'continuousHeartRateAlarmSwitch',
      'continuousBreathingAlarmSwitch',
      'leaveBedAlarmSwitch',
      'unmannedAlarmSwitch',
      'heartRateAlarmLowThreshold',
      'heartRateAlarmHighThreshold',
      'heartRateAlarmDuration',
      'breathingAlarmLowThreshold',
      'breathingAlarmHighThreshold',
      'breathingAlarmDuration',
      'leaveBedAlarmDuration',
      'unmannedAlarmDuration',
    };
  }

  String _buildSleepRadarAlarmParamValue() {
    final payload = <String, dynamic>{..._sleepRadarAlarmParamValues};
    payload.addAll({
      'promptTone': _alarmPromptToneEnabled ? '1' : '0',
      'FC_ALM_SW': _tamperAlarmEnabled ? '1' : '0',
      'LS_ALM_SW': _pullRopeAlarmEnabled ? '1' : '0',
      'HEARTRATE_ALM_SW_SWITCH': _heartRateAbnormalAlarmEnabled ? '1' : '0',
      'HEARTRATE_ALM_SW_LOW': _parseIntOrDefault(
        _heartRateAlarmLowThresholdController.text,
        0,
      ).toString(),
      'HEARTRATE_ALM_SW_HIGH': _parseIntOrDefault(
        _heartRateAlarmHighThresholdController.text,
        0,
      ).toString(),
      'HEARTRATE_ALM_SW_TIME': _parseIntOrDefault(
        _heartRateAlarmDurationController.text,
        0,
      ).toString(),
      'BREATHING_ALM_SW_SWITCH': _breathingAbnormalAlarmEnabled ? '1' : '0',
      'BREATHING_ALM_SW_LOW': _parseIntOrDefault(
        _breathingAlarmLowThresholdController.text,
        0,
      ).toString(),
      'BREATHING_ALM_SW_HIGH': _parseIntOrDefault(
        _breathingAlarmHighThresholdController.text,
        0,
      ).toString(),
      'BREATHING_ALM_SW_TIME': _parseIntOrDefault(
        _breathingAlarmDurationController.text,
        0,
      ).toString(),
      'BED_ALM_SW_SWITCH': _leaveBedAlarmEnabled ? '1' : '0',
      'BED_ALM_SW_TIME': _parseIntOrDefault(
        _leaveBedAlarmDurationController.text,
        0,
      ).toString(),
      'UNMANNED_ALM_SW_SWITCH': _unmannedAlarmEnabled ? '1' : '0',
      'UNMANNED_ALM_SW_TIME': _parseIntOrDefault(
        _unmannedAlarmDurationController.text,
        0,
      ).toString(),
    });

    return jsonEncode(payload);
  }

  Future<bool> _saveSleepRadarParams({
    String? unmannedTimerValue,
    VoidCallback? onSuccess,
  }) {
    return _saveSingleParam(
      '360',
      _buildSleepRadarParamValue(unmannedTimerValue: unmannedTimerValue),
      onSuccess: onSuccess,
    );
  }

  Future<bool> _saveSleepRadarAlarmParamSet({VoidCallback? onSuccess}) {
    return _saveSingleParam(
      '381',
      _buildSleepRadarAlarmParamValue(),
      onSuccess: onSuccess,
    );
  }

  String _buildFallRadarParamValue({String? fallHeightValue}) {
    final payload = <String, dynamic>{
      'AI_SW': _fallRadarSwitchValue('AI_SW'),
      'someoneAlmSwitch': _personPresentAlarmEnabled ? '1' : '0',
      'unmannedAlmSwitch': _personAbsentAlarmEnabled ? '1' : '0',
      'unmannedDuration': _fallRadarIntValue('unmannedDuration', 0),
      'tumbleAlmSwitch': _fallRadarSwitchValue('tumbleAlmSwitch'),
      'tumbleDuration': _fallRadarIntValue('tumbleDuration', 5),
      'resideAlmSwitch': _fallRadarSwitchValue('resideAlmSwitch'),
      'resideDuration': _fallRadarIntValue('resideDuration', 1),
      'stateresidealmSwitch': _fallRadarSwitchValue('stateresidealmSwitch'),
      'InstallationHeight': _fallRadarIntValue('InstallationHeight', 200),
      'promptTone': _fallRadarSwitchValue('promptTone'),
      'fall_Height': _parseIntOrDefault(
        fallHeightValue ?? _fallHeightController.text,
        10,
      ),
    };

    return jsonEncode(payload);
  }

  String _fallRadarSwitchValue(String fieldName) {
    final value = _fallRadarParamValues[fieldName]?.toString().trim();
    return value == '1' ? '1' : '0';
  }

  int _fallRadarIntValue(String fieldName, int defaultValue) {
    final value = _fallRadarParamValues[fieldName]?.toString().trim();
    if (value == null || value.isEmpty) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  Future<bool> _saveFallRadarParams({
    String? fallHeightValue,
    VoidCallback? onSuccess,
  }) {
    return _saveSingleParam(
      '43',
      _buildFallRadarParamValue(fallHeightValue: fallHeightValue),
      onSuccess: onSuccess,
    );
  }

  bool _isSleepRadarAlarmInputField(String fieldName) {
    return const {
      'heartRateAlarmLowThreshold',
      'heartRateAlarmHighThreshold',
      'heartRateAlarmDuration',
      'breathingAlarmLowThreshold',
      'breathingAlarmHighThreshold',
      'breathingAlarmDuration',
      'leaveBedAlarmDuration',
      'unmannedAlarmDuration',
    }.contains(fieldName);
  }

  int _sleepRadarAlarmInputMax(String fieldName) {
    switch (fieldName) {
      case 'heartRateAlarmDuration':
      case 'breathingAlarmDuration':
        return 3600;
      case 'leaveBedAlarmDuration':
      case 'unmannedAlarmDuration':
        return 1440;
      default:
        return 200;
    }
  }

  String _sleepRadarAlarmInputLabel(String fieldName) {
    switch (fieldName) {
      case 'heartRateAlarmLowThreshold':
        return '连续心率异常报警低阈值';
      case 'heartRateAlarmHighThreshold':
        return '连续心率异常报警高阈值';
      case 'heartRateAlarmDuration':
        return '连续心率异常报警持续时间';
      case 'breathingAlarmLowThreshold':
        return '连续呼吸异常报警低阈值';
      case 'breathingAlarmHighThreshold':
        return '连续呼吸异常报警高阈值';
      case 'breathingAlarmDuration':
        return '连续呼吸异常报警持续时间';
      case 'leaveBedAlarmDuration':
        return '离床报警持续时间';
      case 'unmannedAlarmDuration':
        return '无人报警持续时间';
      default:
        return '报警参数';
    }
  }

  void _onSaveField(
    String fieldName,
    TextEditingController controller,
    String defaultValue,
  ) {
    if (!_dirtyFields.contains(fieldName)) return;
    if (_isSleepRadarBatchField(fieldName)) return;
    final text = controller.text.trim();
    final value = text.isEmpty ? defaultValue : text;

    if (fieldName == 'fallHeight') {
      final parsedValue = int.tryParse(value);
      if (parsedValue == null || parsedValue < 10 || parsedValue > 100) {
        _showError('跌倒高度范围为 10~100 cm');
        return;
      }

      _saveFallRadarParams(
        fallHeightValue: value,
        onSuccess: () {
          controller.text = value;
          setState(() => _dirtyFields.remove(fieldName));
        },
      );
      return;
    }

    if (fieldName == 'unmannedTimerDuration') {
      final parsedValue = int.tryParse(value);
      if (parsedValue == null || parsedValue < 30 || parsedValue > 180) {
        _showError('无人计时时长范围为 30~180 分钟');
        return;
      }

      _saveSleepRadarParams(
        unmannedTimerValue: value,
        onSuccess: () {
          controller.text = value;
          setState(() => _dirtyFields.remove(fieldName));
        },
      );
      return;
    }

    if (_isSleepRadarAlarmInputField(fieldName)) {
      final parsedValue = int.tryParse(value);
      final maxValue = _sleepRadarAlarmInputMax(fieldName);
      final label = _sleepRadarAlarmInputLabel(fieldName);
      if (parsedValue == null || parsedValue < 0 || parsedValue > maxValue) {
        _showError('$label范围为 0~$maxValue');
        return;
      }

      _saveSleepRadarParams(
        onSuccess: () {
          controller.text = value;
          setState(() => _dirtyFields.remove(fieldName));
        },
      );
      return;
    }

    final paramCodeMap = <String, String>{
      'heartRateInterval': '667',
      'temperatureInterval': '670',
      'fallSensitivity': '687',
    };

    final paramCode = paramCodeMap[fieldName];
    if (paramCode == null || paramCode.isEmpty) {
      _showError('该参数暂不支持单独保存');
      return;
    }

    _saveSingleParam(
      paramCode,
      value,
      onSuccess: () {
        controller.text = value;
        setState(() => _dirtyFields.remove(fieldName));
      },
    );
  }

  Future<void> _saveImmediateSwitch({
    required bool previousValue,
    required bool value,
    required ValueChanged<bool> applyValue,
    required String paramCode,
    required String Function(bool value) buildParamValue,
  }) async {
    if (_isSaving) return;

    setState(() => applyValue(value));
    final saved = await _saveSingleParam(paramCode, buildParamValue(value));

    if (!saved && mounted) {
      setState(() => applyValue(previousValue));
    }
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9891B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          activeThumbColor: const Color(0xFF5B57F7),
          onChanged: _isSaving
              ? null
              : (val) {
                  onChanged(val);
                },
        ),
      ],
    );
  }

  Widget _buildKeyValueSelectRow<K>(
    String label,
    K value,
    Map<K, String> options,
    Function(K) onChanged,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9891B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              border: Border.all(color: const Color(0xFFE7E3F5), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<K>(
                value: value,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: Color(0xFF9891B8),
                ),
                iconEnabledColor: const Color(0xFF9891B8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                items: options.entries.map((entry) {
                  return DropdownMenuItem<K>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2F266F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(v);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSleepTimeRow() {
    final isDirty = _dirtyFields.contains('sleepTime');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '睡眠时间段',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9891B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectSleepTime(context, isStart: true),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6FF),
                      border: Border.all(
                        color: isDirty
                            ? const Color(0xFFFF9800)
                            : const Color(0xFFE7E3F5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: const Color(0xFF9891B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sleepStartTime != null
                              ? '${_sleepStartTime!.hour.toString().padLeft(2, '0')}:${_sleepStartTime!.minute.toString().padLeft(2, '0')}'
                              : '开始时间',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _sleepStartTime != null
                                ? const Color(0xFF2F266F)
                                : const Color(0xFFB8B0D0),
                            fontFamily: _sleepStartTime != null
                                ? 'monospace'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '至',
                  style: TextStyle(color: Color(0xFF9891B8), fontSize: 12),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectSleepTime(context, isStart: false),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6FF),
                      border: Border.all(
                        color: isDirty
                            ? const Color(0xFFFF9800)
                            : const Color(0xFFE7E3F5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: const Color(0xFF9891B8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sleepEndTime != null
                              ? '${_sleepEndTime!.hour.toString().padLeft(2, '0')}:${_sleepEndTime!.minute.toString().padLeft(2, '0')}'
                              : '结束时间',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _sleepEndTime != null
                                ? const Color(0xFF2F266F)
                                : const Color(0xFFB8B0D0),
                            fontFamily: _sleepEndTime != null
                                ? 'monospace'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onSaveSleepTime() {
    if (_sleepStartTime == null || _sleepEndTime == null) {
      _showError('请选择完整的睡眠时间段');
      return;
    }
    final paramValue = jsonEncode({
      'start0':
          '${_sleepStartTime!.hour.toString().padLeft(2, '0')}:${_sleepStartTime!.minute.toString().padLeft(2, '0')}:00',
      'end0':
          '${_sleepEndTime!.hour.toString().padLeft(2, '0')}:${_sleepEndTime!.minute.toString().padLeft(2, '0')}:00',
    });
    _saveSingleParam(
      '666',
      paramValue,
      onSuccess: () {
        setState(() => _dirtyFields.remove('sleepTime'));
      },
    );
  }

  Future<void> _selectSleepTime(
    BuildContext context, {
    required bool isStart,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_sleepStartTime ?? const TimeOfDay(hour: 22, minute: 0))
          : (_sleepEndTime ?? const TimeOfDay(hour: 6, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _sleepStartTime = picked;
          _params['sleepStartTime'] =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        } else {
          _sleepEndTime = picked;
          _params['sleepEndTime'] =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        }
        _dirtyFields.add('sleepTime');
      });
      // Auto-save when both times are set
      if (_sleepStartTime != null && _sleepEndTime != null) {
        _onSaveSleepTime();
      }
    }
  }

  Future<bool> _saveSingleParam(
    String paramCode,
    String paramValue, {
    VoidCallback? onSuccess,
  }) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    var saved = false;

    try {
      final data = await iotPostJson(
        context,
        '/api/iot/device/param/set',
        body: {
          'deviceImei': widget.device.imei,
          'createBy': 'admin',
          'paramCode': paramCode,
          'paramValue': paramValue,
        },
        operation: 'save IoT device param',
      );

      if (data['success'] == true) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存成功'),
            backgroundColor: Color(0xFF22A06B),
            duration: Duration(seconds: 1),
          ),
        );
        onSuccess?.call();
        saved = true;
      } else {
        if (!mounted) return false;
        _showError(data['message']?.toString() ?? '保存失败');
      }
    } on IotApiException catch (e) {
      if (!mounted) return false;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return false;
      _showError('网络异常，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    return saved;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE8453A),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
