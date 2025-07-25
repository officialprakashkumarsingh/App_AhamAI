import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'agent_service.dart';

class AgentStatusWidget extends StatefulWidget {
  final AgentService agentService;

  const AgentStatusWidget({
    super.key,
    required this.agentService,
  });

  @override
  State<AgentStatusWidget> createState() => _AgentStatusWidgetState();
}

class _AgentStatusWidgetState extends State<AgentStatusWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    widget.agentService.addListener(_onAgentServiceChanged);
    
    // Start pulse animation if processing
    if (widget.agentService.isProcessing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    widget.agentService.removeListener(_onAgentServiceChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onAgentServiceChanged() {
    if (mounted) {
      setState(() {});
      
      // Control pulse animation
      if (widget.agentService.isProcessing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Remove the agent mode banner as requested
    return const SizedBox.shrink();
  }

}



// Agent Processing Panel similar to Code Panel
class AgentProcessingPanel extends StatefulWidget {
  final AgentService agentService;
  final Map<String, dynamic> processingResults;

  const AgentProcessingPanel({
    super.key,
    required this.agentService,
    required this.processingResults,
  });

  @override
  State<AgentProcessingPanel> createState() => _AgentProcessingPanelState();
}

class _AgentProcessingPanelState extends State<AgentProcessingPanel> with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Listen to agent service changes
    widget.agentService.addListener(_onAgentServiceChanged);
    
    // Start pulse animation if processing
    if (widget.agentService.isProcessing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    widget.agentService.removeListener(_onAgentServiceChanged);
    _expandController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _onAgentServiceChanged() {
    if (mounted) {
      setState(() {});
      
      // Control pulse animation
      if (widget.agentService.isProcessing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  String _getProcessingPreview() {
    if (widget.agentService.isProcessing) {
      return '${widget.agentService.currentPhase}: ${widget.agentService.currentStep}';
    } else if (widget.agentService.processingSteps.isNotEmpty) {
      return 'Processing completed (${widget.agentService.processingSteps.length} steps)';
    } else if (widget.processingResults['steps'] != null) {
      final steps = widget.processingResults['steps'] as List<dynamic>? ?? [];
      return 'Agent processing completed (${steps.length} steps)';
    }
    return 'Agent processing data available';
  }

  List<String> _getDisplaySteps() {
    if (widget.agentService.isProcessing) {
      return widget.agentService.processingSteps;
    } else if (widget.processingResults['steps'] != null) {
      final steps = widget.processingResults['steps'] as List<dynamic>? ?? [];
      return steps.cast<String>();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // Show panel if currently processing OR if we have processing results to show
    final hasProcessingData = widget.processingResults.isNotEmpty && 
        (widget.processingResults['steps'] != null || widget.processingResults['results'] != null);
    
    if (!widget.agentService.isProcessing && !hasProcessingData) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: const Color(0xFF000000),
                  ),
                  const SizedBox(width: 8),
                                      Expanded(
                      child: Text(
                        _isExpanded 
                            ? widget.agentService.isProcessing 
                                ? 'Agent Processing (${widget.agentService.processingSteps.length} steps) - ${widget.agentService.currentPhase}'
                                : 'Agent Processing Complete (${widget.agentService.processingSteps.length} steps)'
                            : widget.agentService.isProcessing
                                ? widget.agentService.currentStep.isNotEmpty 
                                    ? widget.agentService.currentStep
                                    : 'Processing...'
                                : _getProcessingPreview(),
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.agentService.isProcessing 
                              ? const Color(0xFF000000)
                              : const Color(0xFFA3A3A3),
                          fontWeight: widget.agentService.isProcessing 
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        maxLines: _isExpanded ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (widget.agentService.isProcessing)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000000)),
                      ),
                    )
                  else
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: const Color(0xFF000000),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current status if processing
                  if (widget.agentService.isProcessing) ...[
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color.lerp(
                                const Color(0xFFE0E0E0),
                                const Color(0xFF000000),
                                _pulseAnimation.value,
                              )!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF000000).withOpacity(_pulseAnimation.value * 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.lerp(
                                      const Color(0xFFA3A3A3),
                                      const Color(0xFF000000),
                                      _pulseAnimation.value,
                                    )!,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.agentService.currentPhase.isNotEmpty 
                                          ? 'Phase: ${widget.agentService.currentPhase}'
                                          : 'Processing...',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF000000),
                                      ),
                                    ),
                                    if (widget.agentService.currentStep.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.agentService.currentStep,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFA3A3A3),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                                     // Processing steps - show current steps if processing, or saved steps from results
                  ..._getDisplaySteps().map((step) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.split(' ').first, // Get the emoji
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.substring(step.indexOf(' ') + 1), // Get text after emoji
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF000000),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  // Results preview
                  if (widget.processingResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    

                    
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F3F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Results Summary:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF000000),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...widget.processingResults.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• ${entry.key}: ${entry.value.toString().length > 50 ? entry.value.toString().substring(0, 50) + "..." : entry.value.toString()}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFA3A3A3),
                              ),
                            ),
                          )).toList(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}