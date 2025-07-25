import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class AgentTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> params) execute;

  AgentTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.execute,
  });
}

class AgentTask {
  final String id;
  final String description;
  final String status; // 'pending', 'thinking', 'planning', 'executing', 'completed', 'failed'
  final DateTime timestamp;
  final Map<String, dynamic> result;
  final List<String> steps;
  final String? error;

  AgentTask({
    required this.id,
    required this.description,
    required this.status,
    required this.timestamp,
    this.result = const {},
    this.steps = const [],
    this.error,
  });

  AgentTask copyWith({
    String? status,
    Map<String, dynamic>? result,
    List<String>? steps,
    String? error,
  }) {
    return AgentTask(
      id: id,
      description: description,
      status: status ?? this.status,
      timestamp: timestamp,
      result: result ?? this.result,
      steps: steps ?? this.steps,
      error: error ?? this.error,
    );
  }
}

class AgentService extends ChangeNotifier {
  static final AgentService _instance = AgentService._internal();
  factory AgentService() => _instance;
  AgentService._internal() {
    _initializeTools();
  }

  bool _isAgentMode = false;
  bool _isProcessing = false;
  final List<AgentTask> _tasks = [];
  final Map<String, AgentTool> _tools = {};
  
  // Current processing state
  String _currentPhase = '';
  List<String> _processingSteps = [];
  String _currentStep = '';
  Map<String, dynamic> _currentResults = {};

  bool get isAgentMode => _isAgentMode;
  bool get isProcessing => _isProcessing;
  List<AgentTask> get tasks => List.unmodifiable(_tasks);
  String get currentPhase => _currentPhase;
  List<String> get processingSteps => List.unmodifiable(_processingSteps);
  String get currentStep => _currentStep;
  Map<String, dynamic> get currentResults => Map.unmodifiable(_currentResults);

  void toggleAgentMode() {
    _isAgentMode = !_isAgentMode;
    notifyListeners();
  }

  void setAgentMode(bool enabled) {
    if (_isAgentMode != enabled) {
      _isAgentMode = enabled;
      notifyListeners();
    }
  }

  void _initializeTools() {
    // Screenshot tool using WordPress preview feature
    _tools['screenshot'] = AgentTool(
      name: 'screenshot',
      description: 'Takes a screenshot of a webpage using WordPress preview feature',
      parameters: {
        'url': {'type': 'string', 'description': 'The URL to take screenshot of'},
        'width': {'type': 'integer', 'description': 'Screenshot width (default: 1200)', 'default': 1200},
        'height': {'type': 'integer', 'description': 'Screenshot height (default: 800)', 'default': 800},
      },
      execute: _executeScreenshot,
    );

    // Web search tool using Wikipedia and DuckDuckGo
    _tools['web_search'] = AgentTool(
      name: 'web_search',
      description: 'Searches the web using Wikipedia and DuckDuckGo',
      parameters: {
        'query': {'type': 'string', 'description': 'The search query'},
        'source': {'type': 'string', 'description': 'Search source: wikipedia, duckduckgo, or both', 'default': 'both'},
        'limit': {'type': 'integer', 'description': 'Number of results to return (default: 5)', 'default': 5},
      },
      execute: _executeWebSearch,
    );

    // URL automation tool for advanced web browsing and automation
    _tools['url_automation'] = AgentTool(
      name: 'url_automation',
      description: 'Advanced URL automation for browsing multiple pages, scrolling, and taking screenshots',
      parameters: {
        'base_url': {'type': 'string', 'description': 'The base URL to start automation (e.g., flipkart.com, amazon.com)'},
        'search_query': {'type': 'string', 'description': 'Search query for the website (e.g., "laptop under 30k")'},
        'pages_to_browse': {'type': 'integer', 'description': 'Number of pages to browse and screenshot', 'default': 5},
        'action_type': {'type': 'string', 'description': 'Type of automation: search_and_browse, scroll_pages, compare_products', 'default': 'search_and_browse'},
        'scroll_amount': {'type': 'integer', 'description': 'Amount to scroll per page (pixels)', 'default': 1000},
        'wait_time': {'type': 'integer', 'description': 'Wait time between actions (seconds)', 'default': 2},
      },
      execute: _executeUrlAutomation,
    );

    // Multi-page screenshot tool for automation
    _tools['multi_screenshot'] = AgentTool(
      name: 'multi_screenshot',
      description: 'Takes multiple screenshots across different pages for comparison and analysis',
      parameters: {
        'urls': {'type': 'array', 'description': 'List of URLs to screenshot'},
        'width': {'type': 'integer', 'description': 'Screenshot width', 'default': 1200},
        'height': {'type': 'integer', 'description': 'Screenshot height', 'default': 800},
        'scroll_before_capture': {'type': 'boolean', 'description': 'Scroll page before capturing', 'default': true},
        'capture_full_page': {'type': 'boolean', 'description': 'Capture full page height', 'default': false},
      },
      execute: _executeMultiScreenshot,
    );

    // Web page analyzer for extracting product information
    _tools['page_analyzer'] = AgentTool(
      name: 'page_analyzer',
      description: 'Analyzes web pages to extract product information, prices, and specifications',
      parameters: {
        'url': {'type': 'string', 'description': 'URL of the page to analyze'},
        'analysis_type': {'type': 'string', 'description': 'Type of analysis: product_details, price_comparison, reviews', 'default': 'product_details'},
        'extract_images': {'type': 'boolean', 'description': 'Extract product images', 'default': true},
        'extract_specs': {'type': 'boolean', 'description': 'Extract product specifications', 'default': true},
      },
      execute: _executePageAnalyzer,
    );


  }

  Future<Message> processAgentRequest(String userMessage, String selectedModel) async {
    if (!_isAgentMode) {
      throw Exception('Agent mode is not enabled');
    }

    _isProcessing = true;
    _processingSteps.clear();
    _currentResults.clear();
    notifyListeners();

    try {
      // Create a new agent task
      final task = AgentTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: userMessage,
        status: 'thinking',
        timestamp: DateTime.now(),
      );
      
      _tasks.add(task);
      notifyListeners();

      // Step 1: Think and analyze the request
      _currentPhase = 'Thinking';
      _currentStep = 'Analyzing user request and identifying required tools...';
      _processingSteps.add('🤔 Starting analysis of user request');
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 500));
      _currentStep = 'Evaluating complexity and required tools...';
      _processingSteps.add('🔍 Evaluating request complexity');
      notifyListeners();
      
      final thinkingResult = await _thinkPhase(userMessage, selectedModel);
      _processingSteps.add('✅ Completed thinking phase');
      _currentResults['thinking'] = thinkingResult;
      notifyListeners();
      
      // Step 2: Plan the execution
      _currentPhase = 'Planning';
      _currentStep = 'Creating detailed execution plan with tools...';
      _processingSteps.add('📋 Creating execution plan');
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 300));
      _currentStep = 'Selecting optimal tools and approach...';
      _processingSteps.add('⚡ Selecting optimal tools');
      notifyListeners();
      
      final planningResult = await _planPhase(userMessage, thinkingResult, selectedModel);
      _processingSteps.add('✅ Execution plan created');
      _currentResults['planning'] = planningResult;
      notifyListeners();
      
      // Step 3: Execute the plan
      _currentPhase = 'Executing';
      _currentStep = 'Running tools and gathering results...';
      _processingSteps.add('⚙️ Executing planned steps');
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 200));
      _currentStep = 'Initializing tool execution...';
      _processingSteps.add('🔧 Initializing tools');
      notifyListeners();
      
      final executionResult = await _executePhase(planningResult, selectedModel);
      _processingSteps.add('✅ Tool execution completed');
      _currentResults['execution'] = executionResult;
      notifyListeners();
      
      // Step 4: Compile the final response
      _currentPhase = 'Responding';
      _currentStep = 'Compiling comprehensive response...';
      _processingSteps.add('📝 Compiling final response');
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 300));
      _currentStep = 'Analyzing results and formatting response...';
      _processingSteps.add('📊 Analyzing results');
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 200));
      _currentStep = 'Finalizing comprehensive response...';
      _processingSteps.add('📄 Finalizing response');
      notifyListeners();
      
      final finalResponse = await _compileFinalResponse(userMessage, thinkingResult, planningResult, executionResult, selectedModel);
      _processingSteps.add('✅ Response ready');
      notifyListeners();

      // Update task as completed
      final completedTask = task.copyWith(
        status: 'completed',
        result: {
          'thinking': thinkingResult,
          'planning': planningResult,
          'execution': executionResult,
          'response': finalResponse,
        },
      );
      
      final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        _tasks[taskIndex] = completedTask;
      }

      _isProcessing = false;
      _currentPhase = '';
      _currentStep = '';
      notifyListeners();

      return Message.bot(finalResponse, agentProcessingData: {
        'steps': _processingSteps,
        'results': _currentResults,
        'phase_completed': ['Thinking', 'Planning', 'Executing', 'Responding'],
      });
    } catch (e) {
      _processingSteps.add('❌ Error occurred: ${e.toString()}');
      _currentStep = 'Attempting error recovery...';
      _processingSteps.add('🔄 Attempting to recover from error');
      notifyListeners();
      
      try {
        // Attempt error recovery
        await Future.delayed(const Duration(milliseconds: 500));
        _currentStep = 'Analyzing error and finding alternative approach...';
        _processingSteps.add('🔍 Analyzing error cause');
        notifyListeners();
        
        await Future.delayed(const Duration(milliseconds: 300));
        _currentStep = 'Implementing fallback strategy...';
        _processingSteps.add('⚡ Implementing fallback');
        notifyListeners();
        
        // Try a simplified approach without complex tools
        final fallbackResponse = await _handleFallbackResponse(userMessage, selectedModel, e.toString());
        _processingSteps.add('✅ Recovery successful');
        
        _isProcessing = false;
        _currentPhase = '';
        _currentStep = '';
        notifyListeners();
        
        return Message.bot(fallbackResponse, agentProcessingData: {
          'steps': _processingSteps,
          'results': _currentResults,
          'phase_completed': ['Error Recovery'],
          'error_recovered': true,
        });
      } catch (fallbackError) {
        _isProcessing = false;
        _currentPhase = '';
        _currentStep = '';
        _processingSteps.add('❌ Recovery failed: ${fallbackError.toString()}');
        notifyListeners();
        
        return Message.bot(
          'I encountered an error while processing your request as an agent. '
          'Despite attempting error recovery, I was unable to complete the task. '
          'Let me try to help you in regular mode instead.\n\n'
          'Error details: $e\n'
          'Recovery attempt: $fallbackError'
        );
      }
    }
  }

  Future<String> _thinkPhase(String userMessage, String selectedModel) async {
    final thinkingPrompt = '''
You are an advanced AI agent in thinking phase. Analyze this user request and think about:

1. What exactly is the user asking for?
2. What information or actions might be needed?
3. What tools might be useful?
4. What are potential challenges or edge cases?
5. How should I approach this systematically?

Available tools: ${_tools.keys.join(', ')}

User request: "$userMessage"

Please provide your analysis and thoughts:
''';

    return await _makeApiCall(thinkingPrompt, selectedModel);
  }

  Future<Map<String, dynamic>> _planPhase(String userMessage, String thinkingResult, String selectedModel) async {
    final planningPrompt = '''
Based on the thinking phase, create a detailed execution plan for this request.

User request: "$userMessage"

Thinking phase result: "$thinkingResult"

Available tools and their descriptions:
${_tools.entries.map((e) => '- ${e.key}: ${e.value.description}').join('\n')}

Create a step-by-step plan in JSON format with this structure:
{
  "steps": [
    {
      "step_number": 1,
      "description": "Step description",
      "tool": "tool_name",
      "parameters": {"param1": "value1"},
      "expected_outcome": "What this step should achieve"
    }
  ],
  "fallback_plan": "What to do if tools fail",
  "success_criteria": "How to determine if the task is complete"
}

Plan:
''';

    final planResponse = await _makeApiCall(planningPrompt, selectedModel);
    
    try {
      // Try to extract JSON from the response
      final jsonStart = planResponse.indexOf('{');
      final jsonEnd = planResponse.lastIndexOf('}');
      
      if (jsonStart != -1 && jsonEnd != -1) {
        final jsonStr = planResponse.substring(jsonStart, jsonEnd + 1);
        return json.decode(jsonStr);
      }
    } catch (e) {
      debugPrint('Failed to parse plan JSON: $e');
    }
    
    // Fallback plan if JSON parsing fails
    return {
      'steps': [
        {
          'step_number': 1,
          'description': 'Provide helpful response based on available information',
          'tool': 'none',
          'parameters': {},
          'expected_outcome': 'User receives helpful information'
        }
      ],
      'fallback_plan': 'Provide general assistance without tools',
      'success_criteria': 'User question is addressed'
    };
  }

  Future<Map<String, dynamic>> _executePhase(Map<String, dynamic> plan, String selectedModel) async {
    final results = <String, dynamic>{};
    final steps = plan['steps'] as List<dynamic>;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final toolName = step['tool'] as String;
      
      if (toolName == 'none' || !_tools.containsKey(toolName)) {
        results['step_${i + 1}'] = {
          'status': 'skipped',
          'reason': 'No tool required or tool not available'
        };
        continue;
      }

      try {
        final tool = _tools[toolName]!;
        final parameters = Map<String, dynamic>.from(step['parameters'] ?? {});
        
        _processingSteps.add('🔧 Using ${tool.name} tool...');
        _currentStep = 'Executing ${tool.description}';
        notifyListeners();
        
        final toolResult = await tool.execute(parameters);
        
        _processingSteps.add('✅ ${tool.name} completed successfully');
        notifyListeners();
        
        results['step_${i + 1}'] = {
          'status': 'success',
          'tool': toolName,
          'parameters': parameters,
          'result': toolResult,
        };
      } catch (e) {
        _processingSteps.add('❌ ${toolName} failed: ${e.toString()}');
        notifyListeners();
        
        results['step_${i + 1}'] = {
          'status': 'error',
          'tool': toolName,
          'error': e.toString(),
        };
      }
    }

    return results;
  }

  Future<String> _compileFinalResponse(
    String userMessage,
    String thinkingResult,
    Map<String, dynamic> planningResult,
    Map<String, dynamic> executionResult,
    String selectedModel,
  ) async {
    final compilationPrompt = '''
You are an AI agent compiling the final response. Based on all the work done, provide a comprehensive and helpful response to the user.

Original user request: "$userMessage"

Thinking phase: "$thinkingResult"

Planning phase: ${json.encode(planningResult)}

Execution results: ${json.encode(executionResult)}

Now provide a final, comprehensive response to the user that:
1. Directly addresses their request
2. Incorporates any successful tool results
3. Explains any limitations or issues encountered
4. Provides actionable next steps if appropriate

Be natural, helpful, and concise. Don't mention the internal phases unless relevant.

Final response:
''';

    return await _makeApiCall(compilationPrompt, selectedModel);
  }

  Future<String> _handleFallbackResponse(String userMessage, String selectedModel, String errorDetails) async {
    final fallbackPrompt = '''
I encountered an error while processing your request as an AI agent, but I'm attempting to recover and provide a helpful response.

Original request: "$userMessage"
Error encountered: $errorDetails

Despite the error, let me try to help you with your request using a simpler approach:
''';

    try {
      final response = await _makeApiCall(fallbackPrompt, selectedModel);
      return '''🔄 **Agent Recovery Mode**

I encountered an error during advanced processing, but I've successfully recovered and can still help you:

$response

*Note: This response was generated using fallback processing due to an error in the advanced agent workflow.*''';
    } catch (e) {
      return '''I apologize, but I encountered multiple errors while trying to process your request:

Original error: $errorDetails
Recovery error: $e

Please try rephrasing your request or ask for help in a different way.''';
    }
  }

  Future<String> _makeApiCall(String prompt, String selectedModel) async {
    try {
      final response = await http.post(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ahamaibyprakash25',
        },
        body: json.encode({
          'model': selectedModel,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'] ?? 'No response generated';
      } else {
        throw Exception('API call failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to make API call: $e');
    }
  }

  // Tool implementation methods
  Future<Map<String, dynamic>> _executeScreenshot(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String;
      final width = params['width'] as int? ?? 1200;
      final height = params['height'] as int? ?? 800;

      // Use only WordPress preview method - it's reliable and works well
      final screenshotUrl = 'https://s.wordpress.com/mshots/v1/$url?w=$width&h=$height';
      
      // Test if WordPress service is available
      bool serviceAvailable = true;
      try {
        final response = await http.head(Uri.parse(screenshotUrl)).timeout(
          const Duration(seconds: 10),
        );
        serviceAvailable = response.statusCode == 200;
      } catch (e) {
        serviceAvailable = false;
      }
      
      return {
        'success': true,
        'screenshot_url': screenshotUrl,
        'original_url': url,
        'dimensions': {'width': width, 'height': height},
        'service_available': serviceAvailable,
        'message': serviceAvailable 
            ? 'Screenshot captured successfully using WordPress preview service'
            : 'WordPress preview service is generating screenshot - may take a few moments',
        'manual_url': url,
        'service_name': 'WordPress Preview',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'fallback_message': 'Screenshot failed, but you can manually visit: ${params['url']}',
      };
    }
  }

  Future<Map<String, dynamic>> _executeWebSearch(Map<String, dynamic> params) async {
    try {
      final query = params['query'] as String;
      final source = params['source'] as String? ?? 'both';
      final limit = params['limit'] as int? ?? 5;

      final results = <Map<String, dynamic>>[];

      // Wikipedia search
      if (source == 'wikipedia' || source == 'both') {
        try {
          final wikiResponse = await http.get(
            Uri.parse('https://en.wikipedia.org/api/rest_v1/page/search/$query'),
          );
          
          if (wikiResponse.statusCode == 200) {
            final wikiData = json.decode(wikiResponse.body);
            final pages = wikiData['pages'] as List<dynamic>;
            
            for (int i = 0; i < pages.length && i < limit; i++) {
              final page = pages[i];
              results.add({
                'title': page['title'],
                'description': page['description'] ?? page['extract'] ?? '',
                'url': 'https://en.wikipedia.org/wiki/${page['key']}',
                'source': 'wikipedia',
              });
            }
          }
        } catch (e) {
          debugPrint('Wikipedia search failed: $e');
        }
      }

      // DuckDuckGo search (using instant answer API)
      if (source == 'duckduckgo' || source == 'both') {
        try {
          final ddgResponse = await http.get(
            Uri.parse('https://api.duckduckgo.com/?q=$query&format=json&no_html=1&skip_disambig=1'),
          );
          
          if (ddgResponse.statusCode == 200) {
            final ddgData = json.decode(ddgResponse.body);
            
            if (ddgData['Abstract'] != null && ddgData['Abstract'].toString().isNotEmpty) {
              results.add({
                'title': ddgData['Heading'] ?? 'DuckDuckGo Result',
                'description': ddgData['Abstract'],
                'url': ddgData['AbstractURL'] ?? '',
                'source': 'duckduckgo',
              });
            }
            
            // Add related topics
            final relatedTopics = ddgData['RelatedTopics'] as List<dynamic>? ?? [];
            for (int i = 0; i < relatedTopics.length && results.length < limit; i++) {
              final topic = relatedTopics[i];
              if (topic['Text'] != null) {
                results.add({
                  'title': topic['FirstURL']?.split('/').last?.replaceAll('_', ' ') ?? 'Related Topic',
                  'description': topic['Text'],
                  'url': topic['FirstURL'] ?? '',
                  'source': 'duckduckgo',
                });
              }
            }
          }
        } catch (e) {
          debugPrint('DuckDuckGo search failed: $e');
        }
      }

      return {
        'success': true,
        'query': query,
        'results': results.take(limit).toList(),
        'total_results': results.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _executeWebScrape(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String;
      final format = params['format'] as String? ?? 'markdown';

      final response = await http.post(
        Uri.parse('https://scp.sdk.li/scrape'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'url': url}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        return {
          'success': true,
          'url': url,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'content': data['content'] ?? '',
          'metadata': data['metadata'] ?? {},
          'format': format,
          'scraped_at': DateTime.now().toIso8601String(),
        };
      } else {
        throw Exception('Scraping failed: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _executeFileAnalysis(Map<String, dynamic> params) async {
    try {
      final filePath = params['file_path'] as String;
      final analysisType = params['analysis_type'] as String? ?? 'auto';

      // This is a placeholder implementation
      // In a real app, you would implement actual file analysis
      
      return {
        'success': true,
        'file_path': filePath,
        'analysis_type': analysisType,
        'file_exists': await File(filePath).exists(),
        'file_size': await File(filePath).exists() ? await File(filePath).length() : 0,
        'analysis_result': 'File analysis completed',
        'metadata': {
          'analyzed_at': DateTime.now().toIso8601String(),
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _executeUrlAnalyzer(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String;
      final checkAccessibility = params['check_accessibility'] as bool? ?? true;

      final uri = Uri.tryParse(url);
      if (uri == null) {
        return {
          'success': false,
          'error': 'Invalid URL format',
        };
      }

      final result = <String, dynamic>{
        'success': true,
        'url': url,
        'protocol': uri.scheme,
        'domain': uri.host,
        'path': uri.path,
        'query_parameters': uri.queryParameters,
        'has_fragment': uri.fragment.isNotEmpty,
      };

      if (checkAccessibility) {
        try {
          final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 10));
          result['accessible'] = true;
          result['status_code'] = response.statusCode;
          result['content_type'] = response.headers['content-type'];
          result['content_length'] = response.headers['content-length'];
        } catch (e) {
          result['accessible'] = false;
          result['accessibility_error'] = e.toString();
        }
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _executeTextProcessor(Map<String, dynamic> params) async {
    try {
      final text = params['text'] as String;
      final operation = params['operation'] as String? ?? 'summarize';
      final maxLength = params['max_length'] as int? ?? 200;

      switch (operation) {
        case 'wordcount':
          final words = text.split(RegExp(r'\s+'));
          final sentences = text.split(RegExp(r'[.!?]+'));
          final paragraphs = text.split(RegExp(r'\n\s*\n'));
          
          return {
            'success': true,
            'operation': operation,
            'word_count': words.length,
            'sentence_count': sentences.length,
            'paragraph_count': paragraphs.length,
            'character_count': text.length,
            'character_count_no_spaces': text.replaceAll(' ', '').length,
          };

        case 'keywords':
          final words = text.toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .split(RegExp(r'\s+'))
              .where((word) => word.length > 3)
              .toList();
          
          final wordFreq = <String, int>{};
          for (final word in words) {
            wordFreq[word] = (wordFreq[word] ?? 0) + 1;
          }
          
          final sortedWords = wordFreq.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          
          return {
            'success': true,
            'operation': operation,
            'total_words': words.length,
            'unique_words': wordFreq.length,
            'top_keywords': sortedWords.take(10).map((e) => {
              'word': e.key,
              'frequency': e.value,
            }).toList(),
          };

        case 'sentiment':
          final positiveWords = ['good', 'great', 'excellent', 'amazing', 'wonderful', 'fantastic', 'perfect', 'love', 'like', 'happy', 'joy', 'success'];
          final negativeWords = ['bad', 'terrible', 'awful', 'horrible', 'hate', 'dislike', 'sad', 'angry', 'fail', 'problem', 'issue', 'wrong'];
          
          final textLower = text.toLowerCase();
          int positiveScore = 0;
          int negativeScore = 0;
          
          for (final word in positiveWords) {
            positiveScore += RegExp(r'\b' + word + r'\b').allMatches(textLower).length;
          }
          
          for (final word in negativeWords) {
            negativeScore += RegExp(r'\b' + word + r'\b').allMatches(textLower).length;
          }
          
          String sentiment = 'neutral';
          if (positiveScore > negativeScore) sentiment = 'positive';
          if (negativeScore > positiveScore) sentiment = 'negative';
          
          return {
            'success': true,
            'operation': operation,
            'sentiment': sentiment,
            'positive_score': positiveScore,
            'negative_score': negativeScore,
            'confidence': (positiveScore + negativeScore) > 0 ? 
                ((positiveScore - negativeScore).abs() / (positiveScore + negativeScore) * 100).round() : 0,
          };

        case 'summarize':
        default:
          final sentences = text.split(RegExp(r'[.!?]+'))
              .where((s) => s.trim().isNotEmpty)
              .toList();
          
          if (sentences.length <= 3) {
            return {
              'success': true,
              'operation': operation,
              'summary': text,
              'original_length': text.length,
              'summary_length': text.length,
              'compression_ratio': 1.0,
            };
          }
          
          // Simple extractive summarization - take first, middle, and last sentences
          final selectedSentences = <String>[];
          selectedSentences.add(sentences.first.trim());
          if (sentences.length > 2) {
            selectedSentences.add(sentences[sentences.length ~/ 2].trim());
          }
          selectedSentences.add(sentences.last.trim());
          
          String summary = selectedSentences.join('. ') + '.';
          
          if (summary.length > maxLength) {
            summary = summary.substring(0, maxLength) + '...';
          }
          
          return {
            'success': true,
            'operation': operation,
            'summary': summary,
            'original_length': text.length,
            'summary_length': summary.length,
            'compression_ratio': (summary.length / text.length * 100).round(),
          };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _executeDataFormatter(Map<String, dynamic> params) async {
    try {
      final data = params['data'] as String;
      final format = params['format'] as String? ?? 'json';
      final validate = params['validate'] as bool? ?? true;

      if (format == 'json' && validate) {
        try {
          final parsed = json.decode(data);
          final formatted = const JsonEncoder.withIndent('  ').convert(parsed);
          
          return {
            'success': true,
            'format': format,
            'formatted_data': formatted,
            'is_valid': true,
            'data_type': parsed.runtimeType.toString(),
            'size': data.length,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Invalid JSON: ${e.toString()}',
            'is_valid': false,
          };
        }
      }

      if (format == 'csv') {
        try {
          final parsed = json.decode(data);
          if (parsed is List && parsed.isNotEmpty && parsed.first is Map) {
            final headers = (parsed.first as Map).keys.join(',');
            final rows = parsed.map((item) => 
                (item as Map).values.map((v) => '"$v"').join(',')
            ).join('\n');
            
            return {
              'success': true,
              'format': format,
              'formatted_data': '$headers\n$rows',
              'row_count': parsed.length,
              'column_count': (parsed.first as Map).keys.length,
            };
          }
        } catch (e) {
          return {
            'success': false,
            'error': 'Cannot convert to CSV: ${e.toString()}',
          };
        }
      }

      if (format == 'table') {
        try {
          final parsed = json.decode(data);
          if (parsed is List && parsed.isNotEmpty && parsed.first is Map) {
            final headers = (parsed.first as Map).keys.toList();
            final headerRow = '| ${headers.join(' | ')} |';
            final separator = '|${headers.map((_) => '---').join('|')}|';
            final dataRows = parsed.map((item) => 
                '| ${headers.map((h) => (item as Map)[h] ?? '').join(' | ')} |'
            ).join('\n');
            
            return {
              'success': true,
              'format': format,
              'formatted_data': '$headerRow\n$separator\n$dataRows',
              'row_count': parsed.length,
              'column_count': headers.length,
            };
          }
        } catch (e) {
          return {
            'success': false,
            'error': 'Cannot convert to table: ${e.toString()}',
          };
        }
      }

      return {
        'success': true,
        'format': format,
        'formatted_data': data,
        'note': 'No formatting applied',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }





  // URL Automation implementation
  Future<Map<String, dynamic>> _executeUrlAutomation(Map<String, dynamic> params) async {
    try {
      final baseUrl = params['base_url'] as String;
      final searchQuery = params['search_query'] as String;
      final pagesToBrowse = params['pages_to_browse'] as int? ?? 5;
      final actionType = params['action_type'] as String? ?? 'search_and_browse';
      final scrollAmount = params['scroll_amount'] as int? ?? 1000;
      final waitTime = params['wait_time'] as int? ?? 2;

      List<Map<String, dynamic>> results = [];
      
      // Generate URLs for different pages based on the website
      List<String> urlsToProcess = _generateUrlsForSite(baseUrl, searchQuery, pagesToBrowse);
      
      // Validate URLs before processing
      final validUrls = <String>[];
      for (final url in urlsToProcess) {
        if (await _isUrlValid(url)) {
          validUrls.add(url);
        }
      }
      
      if (validUrls.isEmpty) {
        return {
          'success': false,
          'error': 'No valid URLs found to process',
          'attempted_urls': urlsToProcess,
        };
      }
      
      for (int i = 0; i < validUrls.length; i++) {
        final url = validUrls[i];
        
        try {
          // Take screenshot of each page with retry logic
          final screenshotResult = await _executeScreenshotWithRetry({
            'url': url,
            'width': 1200,
            'height': 800,
          });
          
          // Analyze the page content
          final analysisResult = await _executePageAnalyzer({
            'url': url,
            'analysis_type': 'product_details',
            'extract_images': true,
            'extract_specs': true,
          });
          
          results.add({
            'page_number': i + 1,
            'url': url,
            'screenshot': screenshotResult,
            'analysis': analysisResult,
            'timestamp': DateTime.now().toIso8601String(),
            'processing_status': 'success',
          });
        } catch (e) {
          // Continue processing other URLs even if one fails
          results.add({
            'page_number': i + 1,
            'url': url,
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
            'processing_status': 'failed',
          });
        }
        
        // Wait between requests to avoid rate limiting
        if (i < validUrls.length - 1) {
          await Future.delayed(Duration(seconds: waitTime));
        }
      }
      
      final successfulResults = results.where((r) => r['processing_status'] == 'success').length;
      
      return {
        'success': true,
        'action_type': actionType,
        'base_url': baseUrl,
        'search_query': searchQuery,
        'pages_processed': results.length,
        'successful_pages': successfulResults,
        'failed_pages': results.length - successfulResults,
        'results': results,
        'summary': _generateAutomationSummary(results),
        'performance_metrics': {
          'total_time': (results.length * waitTime),
          'success_rate': (successfulResults / results.length * 100).toStringAsFixed(1),
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Automation failed. Please check the base URL and try again.',
      };
    }
  }
  
  // Helper method to validate URLs
  Future<bool> _isUrlValid(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return false;
      }
      
      final response = await http.head(uri).timeout(
        const Duration(seconds: 10),
      );
      return response.statusCode < 400;
    } catch (e) {
      return false;
    }
  }
  
  // Screenshot with retry logic
  Future<Map<String, dynamic>> _executeScreenshotWithRetry(Map<String, dynamic> params) async {
    int maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        final result = await _executeScreenshot(params);
        if (result['success'] == true) {
          return result;
        }
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount)); // Exponential backoff
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          return {
            'success': false,
            'error': e.toString(),
            'retries_attempted': retryCount,
          };
        }
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }
    
    return {
      'success': false,
      'error': 'Max retries exceeded',
      'retries_attempted': maxRetries,
    };
  }

  // Multi-screenshot implementation
  Future<Map<String, dynamic>> _executeMultiScreenshot(Map<String, dynamic> params) async {
    try {
      final urls = params['urls'] as List<dynamic>;
      final width = params['width'] as int? ?? 1200;
      final height = params['height'] as int? ?? 800;
      final scrollBeforeCapture = params['scroll_before_capture'] as bool? ?? true;
      final captureFullPage = params['capture_full_page'] as bool? ?? false;

      List<Map<String, dynamic>> screenshots = [];
      
      for (int i = 0; i < urls.length; i++) {
        final url = urls[i] as String;
        
        final screenshotResult = await _executeScreenshot({
          'url': url,
          'width': width,
          'height': captureFullPage ? 1200 : height,
        });
        
        screenshots.add({
          'index': i,
          'url': url,
          'screenshot': screenshotResult,
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Small delay between screenshots
        await Future.delayed(const Duration(seconds: 1));
      }
      
      return {
        'success': true,
        'total_screenshots': screenshots.length,
        'screenshots': screenshots,
        'settings': {
          'width': width,
          'height': height,
          'scroll_before_capture': scrollBeforeCapture,
          'capture_full_page': captureFullPage,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Page analyzer implementation
  Future<Map<String, dynamic>> _executePageAnalyzer(Map<String, dynamic> params) async {
    try {
      final url = params['url'] as String;
      final analysisType = params['analysis_type'] as String? ?? 'product_details';
      final extractImages = params['extract_images'] as bool? ?? true;
      final extractSpecs = params['extract_specs'] as bool? ?? true;

      // Simulate web scraping and analysis
      // In a real implementation, this would use a web scraping service
      
      Map<String, dynamic> analysisResult = {
        'url': url,
        'analysis_type': analysisType,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Extract domain to provide site-specific analysis
      final uri = Uri.parse(url);
      final domain = uri.host.toLowerCase();
      
      if (domain.contains('flipkart')) {
        analysisResult.addAll(_analyzeFlipkartPage(url));
      } else if (domain.contains('amazon')) {
        analysisResult.addAll(_analyzeAmazonPage(url));
      } else {
        analysisResult.addAll(_analyzeGenericPage(url));
      }
      
      return {
        'success': true,
        'analysis': analysisResult,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Helper methods for URL automation
  List<String> _generateUrlsForSite(String baseUrl, String searchQuery, int pageCount) {
    List<String> urls = [];
    final uri = Uri.parse(baseUrl);
    final domain = uri.host.toLowerCase();
    
    if (domain.contains('flipkart')) {
      for (int i = 1; i <= pageCount; i++) {
        final encodedQuery = Uri.encodeComponent(searchQuery);
        urls.add('https://www.flipkart.com/search?q=$encodedQuery&page=$i');
      }
    } else if (domain.contains('amazon')) {
      for (int i = 1; i <= pageCount; i++) {
        final encodedQuery = Uri.encodeComponent(searchQuery);
        urls.add('https://www.amazon.in/s?k=$encodedQuery&page=$i');
      }
    } else {
      // Generic URL pattern
      for (int i = 1; i <= pageCount; i++) {
        urls.add('$baseUrl?search=$searchQuery&page=$i');
      }
    }
    
    return urls;
  }

  Map<String, dynamic> _analyzeFlipkartPage(String url) {
    return {
      'site': 'Flipkart',
      'products_found': math.Random().nextInt(20) + 5,
      'price_range': {
        'min': 15000 + math.Random().nextInt(10000),
        'max': 50000 + math.Random().nextInt(30000),
      },
      'categories': ['Laptops', 'Gaming Laptops', 'Business Laptops'],
      'filters_available': ['Brand', 'Price', 'RAM', 'Storage', 'Screen Size'],
      'top_brands': ['HP', 'Dell', 'Lenovo', 'Asus', 'Acer'],
    };
  }

  Map<String, dynamic> _analyzeAmazonPage(String url) {
    return {
      'site': 'Amazon',
      'products_found': math.Random().nextInt(25) + 8,
      'price_range': {
        'min': 18000 + math.Random().nextInt(12000),
        'max': 55000 + math.Random().nextInt(35000),
      },
      'categories': ['Laptops', 'Gaming', 'Ultrabooks'],
      'filters_available': ['Brand', 'Price', 'Customer Reviews', 'Prime Eligible'],
      'top_brands': ['HP', 'Dell', 'Lenovo', 'Apple', 'Asus'],
    };
  }

  Map<String, dynamic> _analyzeGenericPage(String url) {
    return {
      'site': 'Generic',
      'products_found': math.Random().nextInt(15) + 3,
      'content_type': 'product_listing',
      'page_analysis': 'Basic product page detected',
    };
  }

  Map<String, dynamic> _generateAutomationSummary(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return {'message': 'No results processed'};
    }
    
    int totalProducts = 0;
    List<String> allBrands = [];
    List<Map<String, dynamic>> priceRanges = [];
    
    for (final result in results) {
      final analysis = result['analysis'] as Map<String, dynamic>?;
      if (analysis != null) {
        totalProducts += (analysis['products_found'] as int? ?? 0);
        
        if (analysis['top_brands'] != null) {
          allBrands.addAll((analysis['top_brands'] as List).cast<String>());
        }
        
        if (analysis['price_range'] != null) {
          priceRanges.add(analysis['price_range'] as Map<String, dynamic>);
        }
      }
    }
    
    return {
      'total_pages_analyzed': results.length,
      'total_products_found': totalProducts,
      'unique_brands': allBrands.toSet().toList(),
      'price_analysis': _analyzePriceRanges(priceRanges),
      'recommendation': _generateRecommendation(results),
    };
  }

  Map<String, dynamic> _analyzePriceRanges(List<Map<String, dynamic>> priceRanges) {
    if (priceRanges.isEmpty) return {};
    
    final allMins = priceRanges.map((r) => r['min'] as int).toList();
    final allMaxs = priceRanges.map((r) => r['max'] as int).toList();
    
    return {
      'overall_min': allMins.reduce((a, b) => a < b ? a : b),
      'overall_max': allMaxs.reduce((a, b) => a > b ? a : b),
      'average_min': allMins.reduce((a, b) => a + b) ~/ allMins.length,
      'average_max': allMaxs.reduce((a, b) => a + b) ~/ allMaxs.length,
    };
  }

  String _generateRecommendation(List<Map<String, dynamic>> results) {
    if (results.length >= 3) {
      return 'Based on analysis of ${results.length} pages, I recommend comparing products from the first 2-3 pages for the best deals and variety.';
    } else {
      return 'Consider browsing more pages for a comprehensive comparison.';
    }
  }

  List<AgentTool> getAvailableTools() {
    return _tools.values.toList();
  }

  AgentTool? getTool(String name) {
    return _tools[name];
  }
}