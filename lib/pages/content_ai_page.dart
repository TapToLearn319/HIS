import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:provider/provider.dart';

import '../../provider/hub_provider.dart';
import '../models/generated_quiz_models.dart';
import '../services/openrouter_quiz_service.dart';
import '../services/quiz_firestore_service.dart';

class ContentAiPage extends StatefulWidget {
  const ContentAiPage({
    super.key,
    required this.openRouterApiKey,
    this.topicSelectionRouteName = '/tools/quiz',
  });

  final String openRouterApiKey;
  final String topicSelectionRouteName;

  @override
  State<ContentAiPage> createState() => _ContentAiPageState();
}

class _ContentAiPageState extends State<ContentAiPage> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  final QuizFirestoreService _firestoreService = QuizFirestoreService();
  late final OpenRouterQuizService _quizService;

  DropzoneViewController? _dropzoneController;

  Uint8List? _pdfBytes;
  String? _fileName;

  bool _isGenerating = false;
  bool _isSaving = false;
  String? _errorMessage;

  String _bundleTitle = '';
  List<GeneratedQuizQuestion> _questions = [];

  final QuizSettingsModel _settings =
    QuizSettingsModel()..isPublic = true;

  @override
  void initState() {
    super.initState();
    _quizService = OpenRouterQuizService(
      apiKey: widget.openRouterApiKey,
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool get _hasResult => _questions.isNotEmpty;

  Future<void> _pickPdfFile() async {
    setState(() {
      _errorMessage = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) {
      setState(() {
        _errorMessage = '파일을 읽지 못했습니다.';
      });
      return;
    }

    setState(() {
      _pdfBytes = bytes;
      _fileName = file.name;
      _questions = [];
      _bundleTitle = '';
      _titleController.clear();
    });
  }

  Future<void> _handleDrop(dynamic event) async {
    if (_dropzoneController == null) return;

    try {
      final mime = await _dropzoneController!.getFileMIME(event);
      final name = await _dropzoneController!.getFilename(event);
      final bytes = await _dropzoneController!.getFileData(event);

      final isPdf =
          name.toLowerCase().endsWith('.pdf') ||
          mime.toLowerCase() == 'application/pdf';

      if (!isPdf) {
        setState(() {
          _errorMessage = 'PDF 파일만 업로드할 수 있습니다.';
        });
        return;
      }

      setState(() {
        _errorMessage = null;
        _pdfBytes = bytes;
        _fileName = name;
        _questions = [];
        _bundleTitle = '';
        _titleController.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = '파일을 불러오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _generateQuiz() async {
    if (_isGenerating) return;

    if (_pdfBytes == null || _fileName == null) {
      setState(() {
        _errorMessage = 'PDF 파일 1개를 먼저 업로드해 주세요.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final bundle = await _quizService.generateQuizBundle(
        pdfBytes: _pdfBytes!,
        fileName: _fileName!,
        userPrompt: _promptController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _bundleTitle = bundle.title;
        _titleController.text = bundle.title;
        _questions = bundle.questions;
      });
    } on QuizGenerationException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = '알 수 없는 오류가 발생했습니다.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _generateDevDummyQuiz() {
    setState(() {
      _errorMessage = null;
      _bundleTitle = 'Developer Test Quiz';
      _titleController.text = _bundleTitle;
      _fileName ??= 'dev_test.pdf';

      _questions = List.generate(5, (index) {
        return GeneratedQuizQuestion(
          question: '문제 ${index + 1}',
          correctIndex: 0,
          isEnabled: true,
          isExpanded: false,
          options: [
            QuizOptionItem(text: '정답 1'),
            QuizOptionItem(text: '보기 2'),
            QuizOptionItem(text: '보기 3'),
            QuizOptionItem(text: '보기 4'),
          ],
        );
      });
    });
  }

  Future<void> _saveQuizSet() async {
    if (_questions.isEmpty || _fileName == null || _isSaving) return;

    final hubId = context.read<HubProvider>().hubId;

    if (hubId == null || hubId.isEmpty) {
      setState(() {
        _errorMessage = 'Hub ID를 찾을 수 없습니다.';
      });
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? (_bundleTitle.isEmpty ? 'Generated Quiz' : _bundleTitle)
        : _titleController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _firestoreService.createAndSaveGeneratedQuizSet(
        hubId: hubId,
        sourceFileName: _fileName!,
        bundleTitle: title,
        questions: _questions,
        settings: _settings,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, widget.topicSelectionRouteName);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = '저장 중 오류가 발생했습니다: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      _questions[index] = _questions[index].copyWith(
        isExpanded: !_questions[index].isExpanded,
      );
    });
  }

  void _toggleQuestionEnabled(int index, bool value) {
    setState(() {
      _questions[index] = _questions[index].copyWith(isEnabled: value);
    });
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _updateQuestionText(int index, String value) {
    setState(() {
      _questions[index] = _questions[index].copyWith(question: value);
    });
  }

  void _updateOptionText(int qIndex, int oIndex, String value) {
    final updatedOptions = List<QuizOptionItem>.from(_questions[qIndex].options);
    updatedOptions[oIndex] = QuizOptionItem(text: value);

    setState(() {
      _questions[qIndex] = _questions[qIndex].copyWith(options: updatedOptions);
    });
  }

  void _updateCorrectIndex(int qIndex, int correctIndex) {
    setState(() {
      _questions[qIndex] =
          _questions[qIndex].copyWith(correctIndex: correctIndex);
    });
  }

  Widget _customSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Switch(
      value: value,
      activeColor: const Color(0xFFB6E214),
      activeTrackColor: Colors.white,
      inactiveThumbColor: const Color(0xFF9E9E9E),
      inactiveTrackColor: Colors.white,
      trackOutlineColor: WidgetStateProperty.all(
        const Color(0xFFD0D0D0),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () {
                if (!_isGenerating) Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _DotLoader(),
                    const SizedBox(height: 28),
                    const Text(
                      'Making your Recipe',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A2342),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "using ‘${_fileName ?? 'file.pdf'}’ ...",
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF9A9A9A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(title: 'AI Helper', showTries: true),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'Make your own Recipe',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A2342),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD8D8D8)),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _promptController,
                          decoration: const InputDecoration(
                            hintText: 'Ask me anything.',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              fontSize: 18,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isGenerating ? null : _generateQuiz,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0A2342)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'MAKE',
                          style: TextStyle(
                            color: Color(0xFF0A2342),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _chipButton('Create a Quiz'),
                  _devButton(),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFD9D9D9)),
              const SizedBox(height: 22),
              if (_fileName != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD9D9D9)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _fileName = null;
                            _pdfBytes = null;
                            _questions = [];
                            _bundleTitle = '';
                            _titleController.clear();
                          });
                        },
                        child:
                            const Icon(Icons.close, color: Color(0xFFB3B3B3)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Color(0xFFB3B3B3),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _fileName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _buildUploadArea(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _errorBox(_errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultTopBar(),
              const SizedBox(height: 18),
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                ),
                child: Center(
                  child: TextField(
                    controller: _titleController,
                    onChanged: (value) {
                      _bundleTitle = value;
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter quiz title',
                      hintStyle: TextStyle(
                        color: Color(0xFFA8A8A8),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A2342),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Questions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2342),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Public',
                          style: TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 18,
                          color: Color(0xFFC0C0C0),
                        ),
                        const SizedBox(width: 8),
                        _customSwitch(
                          value: _settings.isPublic,
                          onChanged: (value) {
                            setState(() {
                              _settings.isPublic = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(_questions.length, (index) {
                      final item = _questions[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 42,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: Text(
                                  '${index + 1}.',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _buildQuestionAccordion(index, item),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Quiz Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2342),
                ),
              ),
              const SizedBox(height: 16),
              _buildQuizSettingsCard(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _errorBox(_errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionAccordion(int index, GeneratedQuizQuestion item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: item.question)
                      ..selection = TextSelection.collapsed(
                        offset: item.question.length,
                      ),
                    onChanged: (value) => _updateQuestionText(index, value),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _toggleExpanded(index),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: Icon(
                    item.isExpanded ? Icons.expand_less : Icons.edit_outlined,
                    color: const Color(0xFF9E9E9E),
                    size: 18,
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteQuestion(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFFF8B5E),
                  ),
                ),
                _customSwitch(
                  value: item.isEnabled,
                  onChanged: (value) => _toggleQuestionEnabled(index, value),
                ),
              ],
            ),
          ),
          if (item.isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                ),
                child: Column(
                  children: List.generate(item.options.length, (oIndex) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item.options[oIndex].text,
                              onChanged: (value) => _updateOptionText(index, oIndex, value),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: '${oIndex + 1}. Choice',
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Radio<int>(
                            value: oIndex,
                            groupValue: item.correctIndex,
                            activeColor: const Color(0xFFB6E214),
                            onChanged: (value) {
                              if (value == null) return;
                              _updateCorrectIndex(index, value);
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: Column(
        children: [
          _settingsRow(
            title: 'Show results',
            child: Row(
              children: [
                _radioText(
                  selected: _settings.showResultsInRealTime,
                  label: 'in real time',
                  onTap: () {
                    setState(() {
                      _settings.showResultsInRealTime = true;
                    });
                  },
                ),
                const SizedBox(width: 28),
                _radioText(
                  selected: !_settings.showResultsInRealTime,
                  label: 'after quiz ends',
                  onTap: () {
                    setState(() {
                      _settings.showResultsInRealTime = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _settingsRow(
            title: 'Anonymous',
            child: Row(
              children: [
                _radioText(
                  selected: _settings.anonymous,
                  label: 'yes',
                  onTap: () {
                    setState(() {
                      _settings.anonymous = true;
                    });
                  },
                ),
                const SizedBox(width: 28),
                _radioText(
                  selected: !_settings.anonymous,
                  label: 'no',
                  onTap: () {
                    setState(() {
                      _settings.anonymous = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _settingsRow(
            title: 'Multiple selections',
            child: Row(
              children: [
                _radioText(
                  selected: _settings.multipleSelections,
                  label: 'yes',
                  onTap: () {
                    setState(() {
                      _settings.multipleSelections = true;
                    });
                  },
                ),
                const SizedBox(width: 28),
                _radioText(
                  selected: !_settings.multipleSelections,
                  label: 'no',
                  onTap: () {
                    setState(() {
                      _settings.multipleSelections = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _settingsRow(
            title: 'Time Limit',
            child: Row(
              children: [
                _timeNumberField(
                  initialValue: _settings.timeLimitHours.toString(),
                  onChanged: (v) {
                    _settings.timeLimitHours = int.tryParse(v) ?? 0;
                  },
                ),
                const SizedBox(width: 6),
                const Text('h'),
                const SizedBox(width: 16),
                _timeNumberField(
                  initialValue: _settings.timeLimitMinutes.toString(),
                  onChanged: (v) {
                    _settings.timeLimitMinutes = int.tryParse(v) ?? 0;
                  },
                ),
                const SizedBox(width: 6),
                const Text('m'),
                const SizedBox(width: 16),
                _timeNumberField(
                  initialValue: _settings.timeLimitSeconds.toString(),
                  onChanged: (v) {
                    _settings.timeLimitSeconds = int.tryParse(v) ?? 0;
                  },
                ),
                const SizedBox(width: 6),
                const Text('s'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required String title,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2342),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: Color(0xFFC0C0C0),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _radioText({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Radio<bool>(
            value: true,
            groupValue: selected,
            activeColor: const Color(0xFFB6E214),
            onChanged: (_) => onTap(),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeNumberField({
    required String initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: TextEditingController(text: initialValue)
          ..selection = TextSelection.collapsed(offset: initialValue.length),
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 6),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildResultTopBar() {
    return Row(
      children: [
        Expanded(
          child: _buildTopBar(
            title: _titleController.text.trim().isEmpty
                ? (_bundleTitle.isEmpty ? 'Food' : _bundleTitle)
                : _titleController.text.trim(),
            showTries: true,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isGenerating ? null : _generateQuiz,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF0A2342)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text(
            'AGAIN',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveQuizSet,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0A2342),
            side: const BorderSide(color: Color(0xFF0A2342)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text(
            'SAVE',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar({
    required String title,
    bool showTries = false,
  }) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (showTries)
          const Text(
            'You can try 3 / 10 times',
            style: TextStyle(
              color: Color(0xFFA4A4A4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _chipButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD0D0D0)),
        color: Colors.white,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0A2342),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _devButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _generateDevDummyQuiz,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFF8B5E)),
          color: const Color(0xFFFFF3EE),
        ),
        child: const Text(
          'Developer Test',
          style: TextStyle(
            color: Color(0xFFFF8B5E),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD3D8DE)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _pickPdfFile,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 42,
                      color: Color(0xFFA8A8A8),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Upload a file',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFFA8A8A8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Click or drag and drop a PDF here',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB8B8B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (kIsWeb)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: DropzoneView(
                  operation: DragOperation.copy,
                  cursor: CursorType.grab,
                  onCreated: (ctrl) => _dropzoneController = ctrl,
                  onDropFile: _handleDrop,
                  onError: (error) {
                    setState(() {
                      _errorMessage =
                          '파일 드래그 앤 드롭 중 오류가 발생했습니다: $error';
                    });
                  },
                ),
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _pickPdfFile,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC8C8)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) return _buildLoadingView();
    if (_hasResult) return _buildResultView();
    return _buildInitialView();
  }
}

class _DotLoader extends StatefulWidget {
  const _DotLoader();

  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _scaleFor(int index) {
    final value = (_controller.value + (index * 0.15)) % 1.0;
    if (value < 0.5) {
      return 0.8 + (value * 0.8);
    }
    return 1.2 - ((value - 0.5) * 0.8);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.scale(
                scale: _scaleFor(index),
                child: const CircleAvatar(
                  radius: 5,
                  backgroundColor: Color(0xFF0A2342),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}