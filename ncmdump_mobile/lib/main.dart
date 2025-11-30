import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ncmdump_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => FileListModel(),
      child: const MyApp(),
    ),
  );
}

// ------ 数据模型 ------
enum ProcessStatus { pending, processing, success, failed }

class NcmFile {
  final String path;
  final String name;
  ProcessStatus status;
  String errorMessage;

  NcmFile(this.path)
      : name = path.split(Platform.pathSeparator).last,
        status = ProcessStatus.pending,
        errorMessage = "";
}

class FileGroup {
  final String groupName;
  final List<NcmFile> files;

  FileGroup(this.groupName, this.files);
}

class FileListModel extends ChangeNotifier {
  final List<FileGroup> _fileGroups = [];
  
  String? _outputDirectory;
  bool _isProcessing = false;
  bool _isFinished = false;
  bool _isExpandedMode = false; 

  List<String> _directoryHistory = [];

  List<FileGroup> get fileGroups => _fileGroups;
  String? get outputDirectory => _outputDirectory;
  bool get isProcessing => _isProcessing;
  bool get isFinished => _isFinished;
  bool get isExpandedMode => _isExpandedMode;
  List<String> get directoryHistory => _directoryHistory;
  
  int get totalFiles => _fileGroups.fold(0, (sum, group) => sum + group.files.length);
  bool get isEmpty => _fileGroups.isEmpty;

  FileListModel() {
    _loadHistory();
  }

  void toggleExpandMode() {
    _isExpandedMode = !_isExpandedMode;
    notifyListeners();
  }

  // --- 历史记录逻辑 ---
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _directoryHistory = prefs.getStringList('dir_history') ?? [];
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dir_history', _directoryHistory);
  }

  void addToHistory(String path) {
    if (!_directoryHistory.contains(path)) {
      _directoryHistory.insert(0, path);
      if (_directoryHistory.length > 20) _directoryHistory.removeLast();
      _saveHistory();
    } else {
      _directoryHistory.remove(path);
      _directoryHistory.insert(0, path);
      _saveHistory();
    }
    notifyListeners();
  }

  void removeFromHistory(String path) {
    _directoryHistory.remove(path);
    _saveHistory();
    notifyListeners();
  }

  void clearHistory() {
    _directoryHistory.clear();
    _saveHistory();
    notifyListeners();
  }

  // --- 权限逻辑 ---
  Future<bool> checkAndRequestPermission(BuildContext context) async {
    if (Platform.isWindows || Platform.isLinux) return true;

    if (!Platform.isAndroid) return true;
    
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final int sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;
    } else {
      if (await Permission.storage.isGranted) return true;
      final status = await Permission.storage.request();
      if (status.isGranted) return true;
    }

    if (context.mounted) {
      _showPermissionDialog(context);
    }
    return false;
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("需要权限"),
        content: const Text("为了扫描目录和保存音乐文件，本应用需要“所有文件访问权限”。\n\n请点击“去设置”，然后在列表中找到本应用并开启权限。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("去设置"),
          ),
        ],
      ),
    );
  }

  // --- 扫描与添加逻辑 ---

  void addManualFiles(List<String> paths) {
    List<NcmFile> newFiles = [];
    for (var path in paths) {
      if (path.toLowerCase().endsWith('.ncm')) {
        bool exists = _fileGroups.any((g) => g.files.any((f) => f.path == path));
        if (!exists) {
          newFiles.add(NcmFile(path));
        }
      }
    }

    if (newFiles.isNotEmpty) {
      var manualGroupIndex = _fileGroups.indexWhere((g) => g.groupName == "手动添加");
      if (manualGroupIndex != -1) {
        _fileGroups[manualGroupIndex].files.addAll(newFiles);
      } else {
        _fileGroups.insert(0, FileGroup("手动添加", newFiles));
      }
      _isFinished = false;
      notifyListeners();
    }
  }

  Future<void> scanDirectory(String path, BuildContext context, {bool silent = false}) async {
    if (!await checkAndRequestPermission(context)) return;

    final dir = Directory(path);
    if (!await dir.exists()) {
      if (!silent) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("目录不存在: $path")));
        }
      }
      return;
    }

    try {
       List<NcmFile> ncmFiles = [];
       await for (var entity in dir.list(recursive: false)) {
         if (entity is File && entity.path.toLowerCase().endsWith('.ncm')) {
           bool exists = _fileGroups.any((g) => g.files.any((f) => f.path == entity.path));
           if (!exists) {
             ncmFiles.add(NcmFile(entity.path));
           }
         }
       }
       
       if (ncmFiles.isNotEmpty) {
         var groupIndex = _fileGroups.indexWhere((g) => g.groupName == path);
         if (groupIndex != -1) {
           _fileGroups[groupIndex].files.addAll(ncmFiles);
         } else {
           _fileGroups.add(FileGroup(path, ncmFiles));
         }
         addToHistory(path);
         _isFinished = false;
         notifyListeners();
       } else {
         if (!silent && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("该目录下未发现新 NCM 文件")));
         }
       }
    } catch (e) {
       if (!silent && context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("读取失败: $e")));
       }
    }
  }

  Future<void> scanAllHistory(BuildContext context) async {
    if (_directoryHistory.isEmpty) return;
    if (!await checkAndRequestPermission(context)) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("正在扫描所有历史目录..."), duration: Duration(milliseconds: 800))
      );
    }
    await Future.wait(_directoryHistory.map((path) => scanDirectory(path, context, silent: true)));
    notifyListeners();
  }

  void removeFile(FileGroup group, int fileIndex) {
    group.files.removeAt(fileIndex);
    if (group.files.isEmpty) {
      _fileGroups.remove(group);
    }
    if (isEmpty) _isFinished = false;
    notifyListeners();
  }

  void removeGroup(FileGroup group) {
    _fileGroups.remove(group);
    if (isEmpty) _isFinished = false;
    notifyListeners();
  }

  void clearAll() {
    _fileGroups.clear();
    _isFinished = false;
    notifyListeners();
  }

  void setOutputDirectory(String? path) {
    _outputDirectory = path;
    notifyListeners();
  }

  Future<void> startProcessing(BuildContext context) async {
    if (isEmpty) return;
    _isFinished = false;
    
    if (!await checkAndRequestPermission(context)) return;

    _isProcessing = true;
    notifyListeners();

    String defaultDir = (Platform.isWindows || Platform.isLinux) ? "" : "/storage/emulated/0/Music";
    String targetDir = _outputDirectory ?? defaultDir;

    if (targetDir.isNotEmpty) {
       try {
        final dir = Directory(targetDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (e) {
        targetDir = ""; 
      }
    }

    for (var group in _fileGroups) {
      for (var file in group.files) {
        if (file.status == ProcessStatus.success) continue;

        file.status = ProcessStatus.processing;
        file.errorMessage = "";
        notifyListeners();

        String? error = await NcmDumpService.convertFile(file.path, targetDir);
        
        if (error == null) {
          file.status = ProcessStatus.success;
        } else {
          file.status = ProcessStatus.failed;
          file.errorMessage = error;
        }
        notifyListeners();
      }
    }

    _isProcessing = false;
    _isFinished = true;
    notifyListeners();
  }
}

// ------ UI 部分 ------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NCM Dump Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
        fontFamilyFallback: const ["Microsoft YaHei", "SimHei", "Noto Sans SC"],
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        //Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  
  String _compactPath(String path) {
    if (path.length <= 30) return path;
    return "...${path.substring(path.length - 25)}";
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FileListModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NCM 转换器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // [新增] 刷新按钮，用于桌面端备份或手动刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新扫描所有目录',
            onPressed: model.isProcessing ? null : () => model.scanAllHistory(context),
          ),
          IconButton(
            icon: Icon(model.isExpandedMode ? Icons.compress : Icons.expand),
            tooltip: model.isExpandedMode ? "收起文件名" : "展开完整文件名",
            onPressed: () => model.toggleExpandMode(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空列表',
            onPressed: model.isProcessing ? null : () => model.clearAll(),
          )
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Tooltip(
              message: model.outputDirectory ?? 
                  ((Platform.isWindows || Platform.isLinux) ? "默认：源文件所在目录" : "默认：Music 文件夹"),
              child: Text(
                model.outputDirectory == null 
                    ? ((Platform.isWindows || Platform.isLinux) ? "默认：保存在源文件所在目录" : "默认：保存在 Music 文件夹")
                    : _compactPath(model.outputDirectory!),
                style: TextStyle(
                  color: model.outputDirectory == null ? Colors.grey[700] : Colors.black,
                  fontStyle: FontStyle.normal, 
                ),
              ),
            ),
            subtitle: const Text("点击切换输出目录"),
            onTap: model.isProcessing ? null : () async {
              if (await model.checkAndRequestPermission(context)) {
                if (!context.mounted) return;
                
                String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                if (selectedDirectory != null) {
                  model.setOutputDirectory(selectedDirectory);
                }
              }
            },
            trailing: model.outputDirectory != null 
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => model.setOutputDirectory(null)) 
              : null,
          ),
          const Divider(height: 1),
          
          Expanded(
            child: model.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.library_music, size: 64, color: Colors.black12),
                        SizedBox(height: 16),
                        Text("点击下方按钮添加，或使用右上角刷新历史", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => model.scanAllHistory(context),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: model.fileGroups.length,
                      itemBuilder: (context, groupIndex) {
                        final group = model.fileGroups[groupIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              color: Colors.grey[200],
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(group.groupName == "手动添加" ? Icons.touch_app : Icons.folder, size: 18, color: Colors.grey[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      group.groupName,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: model.isProcessing ? null : () => model.removeGroup(group),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: group.files.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 56),
                              itemBuilder: (ctx, fileIndex) {
                                final file = group.files[fileIndex];
                                return ListTile(
                                  dense: true,
                                  leading: _buildStatusIcon(file.status),
                                  title: Text(
                                    file.name,
                                    maxLines: model.isExpandedMode ? null : 1, 
                                    overflow: model.isExpandedMode ? null : TextOverflow.ellipsis,
                                  ),
                                  subtitle: file.errorMessage.isNotEmpty 
                                      ? Text(file.errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)) 
                                      : (model.isExpandedMode 
                                          ? Text(file.path, style: const TextStyle(fontSize: 10, color: Colors.grey)) 
                                          : null),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: model.isProcessing ? null : () => model.removeFile(group, fileIndex),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: Column(
              children: [
                if (model.isProcessing) const LinearProgressIndicator(),
                if (model.isProcessing) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.note_add),
                        label: const Text("添加文件"),
                        onPressed: model.isProcessing ? null : () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            type: FileType.custom,
                            allowedExtensions: ['ncm'],
                          );
                          if (result != null) {
                            model.addManualFiles(result.paths.whereType<String>().toList());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.create_new_folder),
                        label: const Text("添加目录"),
                        onPressed: model.isProcessing ? null : () async {
                           if (await model.checkAndRequestPermission(context)) {
                             if (!context.mounted) return;

                             String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                             if (selectedDirectory != null) {
                               if (!context.mounted) return;
                               await model.scanDirectory(selectedDirectory, context);
                             }
                           }
                        },
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.history),
                      tooltip: "目录历史",
                      onPressed: model.isProcessing ? null : () {
                        _showHistorySheet(context, model);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: (model.isEmpty || model.isProcessing) 
                        ? null 
                        : () => model.startProcessing(context), 
                    child: Text(
                      model.isProcessing 
                        ? "处理中..." 
                        : (model.isFinished ? "处理完成 (点击再次处理)" : "开始处理 (${model.totalFiles})"),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showHistorySheet(BuildContext context, FileListModel model) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Consumer<FileListModel>(
          builder: (context, innerModel, child) {
            final history = innerModel.directoryHistory;
            if (history.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text("暂无历史记录", style: TextStyle(color: Colors.grey))),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("目录历史记录", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: () {
                          innerModel.clearHistory();
                          Navigator.pop(ctx);
                        },
                        child: const Text("全部清空", style: TextStyle(color: Colors.red)),
                      )
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (ctx, index) {
                      final path = history[index];
                      return ListTile(
                        leading: const Icon(Icons.folder, color: Colors.grey),
                        title: Text(_compactPath(path)),
                        onTap: () {
                          Navigator.pop(ctx); 
                          model.scanDirectory(path, context);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => innerModel.removeFromHistory(path),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusIcon(ProcessStatus status) {
    switch (status) {
      case ProcessStatus.pending:
        return const Icon(Icons.music_note, color: Colors.grey, size: 20);
      case ProcessStatus.processing:
        return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
      case ProcessStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case ProcessStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 20);
    }
  }
}
