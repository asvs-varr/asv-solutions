// BANAAG Dev Ticket Model (Local persistence for issues, ideas, and feature requests)

class DevTicket {
  final String id;
  final String title;
  final String description;
  final String type; // 'fix' | 'remove' | 'add' | 'note'
  final String priority; // 'low' | 'medium' | 'high'
  final DateTime createdAt;
  final String status; // 'open' | 'in_progress' | 'resolved'
  final String? projectContext; // Associated project title or screen
  final String? resolutionSummary;

  DevTicket({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    this.priority = 'medium',
    required this.createdAt,
    this.status = 'open',
    this.projectContext,
    this.resolutionSummary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type,
        'priority': priority,
        'createdAt': createdAt.toIso8601String(),
        'status': status,
        if (projectContext != null) 'projectContext': projectContext,
        if (resolutionSummary != null) 'resolutionSummary': resolutionSummary,
      };

  factory DevTicket.fromJson(Map<String, dynamic> json) {
    return DevTicket(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'fix',
      priority: json['priority'] as String? ?? 'medium',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'open',
      projectContext: json['projectContext'] as String?,
      resolutionSummary: json['resolutionSummary'] as String?,
    );
  }

  DevTicket copyWith({
    String? title,
    String? description,
    String? type,
    String? priority,
    String? status,
    String? projectContext,
    String? resolutionSummary,
  }) {
    return DevTicket(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      status: status ?? this.status,
      projectContext: projectContext ?? this.projectContext,
      resolutionSummary: resolutionSummary ?? this.resolutionSummary,
    );
  }
}
