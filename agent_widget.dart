import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

// Enhanced Agent Processing Panel integrated into message UI
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
  bool _isExpanded = true; // Start expanded for better visibility
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    // Listen to agent service changes
    widget.agentService.addListener(_onAgentServiceChanged);
    
    // Start animations
    _expandController.forward();
    _fadeController.forward();
    
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
    _fadeController.dispose();
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

  String _getCurrentPhaseIcon() {
    final phase = widget.agentService.currentPhase.toLowerCase();
    if (phase.contains('thinking')) return '🧠';
    if (phase.contains('planning')) return '📋';
    if (phase.contains('executing')) return '⚙️';
    if (phase.contains('responding')) return '📝';
    return '🤖';
  }

  Color _getPhaseColor() {
    final phase = widget.agentService.currentPhase.toLowerCase();
    if (phase.contains('thinking')) return const Color(0xFF6366F1);
    if (phase.contains('planning')) return const Color(0xFF8B5CF6);
    if (phase.contains('executing')) return const Color(0xFF10B981);
    if (phase.contains('responding')) return const Color(0xFFF59E0B);
    return const Color(0xFF000000);
  }

  String _getPhaseDescription() {
    final phase = widget.agentService.currentPhase.toLowerCase();
    if (phase.contains('thinking')) return 'Analyzing request and understanding context';
    if (phase.contains('planning')) return 'Creating strategic execution plan';
    if (phase.contains('executing')) return 'Running tools and gathering data';
    if (phase.contains('responding')) return 'Compiling comprehensive response';
    return 'Processing your request';
  }

  String _getPhaseProgress() {
    if (!widget.agentService.isProcessing) {
      return 'Completed';
    }
    
    final totalSteps = widget.agentService.processingSteps.length;
    final phase = widget.agentService.currentPhase.toLowerCase();
    
    if (phase.contains('thinking')) return 'Step $totalSteps • Thinking';
    if (phase.contains('planning')) return 'Step $totalSteps • Planning';
    if (phase.contains('executing')) return 'Step $totalSteps • Executing';
    if (phase.contains('responding')) return 'Step $totalSteps • Responding';
    return 'Step $totalSteps • Processing';
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFF8F9FA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.agentService.isProcessing 
                ? _getPhaseColor().withOpacity(0.3)
                : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.agentService.isProcessing 
                  ? _getPhaseColor().withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header with current phase
            InkWell(
              onTap: _toggleExpansion,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Animated phase icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: widget.agentService.isProcessing 
                              ? 1.0 + (_pulseAnimation.value * 0.1)
                              : 1.0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: widget.agentService.isProcessing 
                                  ? _getPhaseColor().withOpacity(0.1)
                                  : const Color(0xFFEAE9E5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: widget.agentService.isProcessing 
                                    ? _getPhaseColor()
                                    : const Color(0xFFD1D5DB),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getCurrentPhaseIcon(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Phase title with progress
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.agentService.isProcessing 
                                      ? widget.agentService.currentPhase.isNotEmpty 
                                          ? widget.agentService.currentPhase
                                          : 'Agent Processing'
                                      : 'Agent Analysis Complete',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: widget.agentService.isProcessing 
                                        ? _getPhaseColor()
                                        : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Text(
                                _getPhaseProgress(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: widget.agentService.isProcessing 
                                      ? _getPhaseColor().withOpacity(0.7)
                                      : const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 2),
                          
                          // Phase description
                          Text(
                            widget.agentService.isProcessing
                                ? _getPhaseDescription()
                                : '${_getDisplaySteps().length} steps completed successfully',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF6B7280),
                              fontStyle: FontStyle.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          // Current step details (only if processing)
                          if (widget.agentService.isProcessing && widget.agentService.currentStep.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.agentService.currentStep,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF9CA3AF),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Progress indicator or expand button
                    if (widget.agentService.isProcessing)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_getPhaseColor()),
                        ),
                      )
                    else
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Expandable content with steps
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(
                      color: Color(0xFFE5E7EB),
                      height: 1,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Real-time processing steps
                    ..._getDisplaySteps().asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      final isLatest = index == _getDisplaySteps().length - 1;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isLatest && widget.agentService.isProcessing
                              ? _getPhaseColor().withOpacity(0.05)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLatest && widget.agentService.isProcessing
                                ? _getPhaseColor().withOpacity(0.2)
                                : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step icon/emoji
                            Container(
                              width: 20,
                              height: 20,
                              child: Center(
                                child: Text(
                                  step.split(' ').first, // Get the emoji
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            Expanded(
                              child: Text(
                                step.contains(' ') 
                                    ? step.substring(step.indexOf(' ') + 1)
                                    : step,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: const Color(0xFF374151),
                                  fontWeight: isLatest && widget.agentService.isProcessing
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            
                            // Status indicator
                            if (isLatest && widget.agentService.isProcessing)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _getPhaseColor(),
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    // Phase summary if completed
                    if (!widget.agentService.isProcessing && widget.processingResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF10B981),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Agent analysis completed successfully',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF065F46),
                                ),
                              ),
                            ),
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
      ),
    );
  }
}