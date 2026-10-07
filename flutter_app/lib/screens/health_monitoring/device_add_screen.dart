import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'iot_api_client.dart';

class _DeviceType {
  final int id;
  final String code;
  final String name;

  _DeviceType({required this.id, required this.code, required this.name});

  factory _DeviceType.fromJson(Map<String, dynamic> json) {
    return _DeviceType(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

String _failureMessageFrom(dynamic message) {
  if (message is String && message.trim().isNotEmpty) {
    return message.trim();
  }
  if (message is Map) {
    final value = message['msg'] ?? message['message'] ?? message['data'];
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  if (message is List && message.isNotEmpty) {
    final parts = message
        .map((item) {
          if (item is Map) {
            return item['msg'] ?? item['message'];
          }
          return item;
        })
        .where((item) => item != null && item.toString().trim().isNotEmpty)
        .map((item) => item.toString().trim())
        .toList();
    if (parts.isNotEmpty) {
      return parts.join('；');
    }
  }
  return '添加失败';
}

class DeviceAddScreen extends StatefulWidget {
  const DeviceAddScreen({super.key});

  @override
  State<DeviceAddScreen> createState() => _DeviceAddScreenState();
}

class _DeviceAddScreenState extends State<DeviceAddScreen> {
  _DeviceType? _selectedDeviceType;
  List<_DeviceType> _deviceTypes = [];
  bool _isLoadingTypes = false;

  final _imeiController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDeviceTypes();
  }

  Future<void> _loadDeviceTypes() async {
    setState(() => _isLoadingTypes = true);
    try {
      final data = await iotGetJson(
        context,
        '/api/iot/device/type_dict',
        operation: 'load IoT device types',
      );
      if (data['success'] == true && data['message'] != null) {
        final List<dynamic> typeList = data['message']['data'] ?? [];
        if (!mounted) return;
        setState(() {
          _deviceTypes = typeList
              .map((item) => _DeviceType.fromJson(item))
              .toList();
          if (_deviceTypes.isNotEmpty) {
            _selectedDeviceType = _deviceTypes.first;
          }
          _isLoadingTypes = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoadingTypes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_failureMessageFrom(data['message'])),
            backgroundColor: const Color(0xFFE88D0C),
          ),
        );
      }
    } on IotApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTypes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFE88D0C),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTypes = false);
    }
  }

  @override
  void dispose() {
    _imeiController.dispose();
    _addressController.dispose();
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '新增设备',
          style: TextStyle(
            color: Color(0xFF2F266F),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device model
                  _buildLabel('设备型号'),
                  const SizedBox(height: 6),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6FF),
                      border: Border.all(
                        color: const Color(0xFFE7E3F5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isLoadingTypes
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF5B57F7),
                              ),
                            ),
                          )
                        : _selectedDeviceType == null
                        ? const Center(
                            child: Text(
                              '暂无设备类型',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9891B8),
                              ),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<_DeviceType>(
                              value: _selectedDeviceType,
                              isExpanded: true,
                              items: _deviceTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2F266F),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedDeviceType = value);
                                }
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // IMEI
                  _buildLabel('IMEI'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _imeiController,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2F266F),
                    ),
                    decoration: InputDecoration(
                      hintText: '请输入IMEI编号',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9891B8),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE7E3F5),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE7E3F5),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF5B57F7),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Installation location
                  _buildLabel('安装位置'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addressController,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2F266F),
                    ),
                    decoration: InputDecoration(
                      hintText: '请输入安装位置，如：居然创客大厦',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9891B8),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE7E3F5),
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE7E3F5),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF5B57F7),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Save button at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF0ECF8), width: 1),
              ),
              color: Colors.white,
            ),
            child: GestureDetector(
              onTap: _saveDevice,
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B57F7),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B57F7).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '确认添加',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B6490),
      ),
    );
  }

  void _saveDevice() async {
    if (_selectedDeviceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择设备型号'),
          backgroundColor: Color(0xFFE88D0C),
        ),
      );
      return;
    }

    if (_imeiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入IMEI编号'),
          backgroundColor: Color(0xFFE88D0C),
        ),
      );
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入安装位置'),
          backgroundColor: Color(0xFFE88D0C),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    var userId = authProvider.currentUser?.id;
    if (userId == null) {
      await authProvider.refreshCurrentUser();
      if (!mounted) {
        return;
      }
      userId = authProvider.currentUser?.id;
    }

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先登录后再添加设备'),
          backgroundColor: Color(0xFFE88D0C),
        ),
      );
      return;
    }

    try {
      final body = {
        'deviceImei': _imeiController.text.trim(),
        'deviceModelId': _selectedDeviceType!.id,
        'deviceModelName': _selectedDeviceType!.code,
        'roomName': _addressController.text.trim(),
        'deviceType': _selectedDeviceType!.name,
        'userId': userId,
      };

      final data = await iotPostJson(
        context,
        '/api/iot/devices/add',
        body: body,
        operation: 'add IoT device',
      );

      if (!mounted) {
        return;
      }

      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设备添加成功'),
            backgroundColor: Color(0xFF22A06B),
            duration: Duration(seconds: 1),
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_failureMessageFrom(data['message'])),
            backgroundColor: const Color(0xFFE88D0C),
          ),
        );
      }
    } on IotApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFE88D0C),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('网络异常，请稍后重试'),
          backgroundColor: Color(0xFFE88D0C),
        ),
      );
    }
  }
}
