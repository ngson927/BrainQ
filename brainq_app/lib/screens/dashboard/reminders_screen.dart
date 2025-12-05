import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';

import '../../services/notification_service.dart';
import '../../services/reminder_service.dart';
import '../../models/reminder.dart';
import '../../providers/deck_provider.dart';
import '../dashboard/reminder_form.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  List<ReminderModel> _reminders = [];
  bool _loading = true;
  bool _showForm = false;
  bool _isEditing = false;
  
  ReminderModel? _editingReminder;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<String> _selectedDays = [];
  


  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final List<String> _weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];


  late final ReminderService _reminderService;

  @override
  void initState() {
    super.initState();

    
    NotificationService.instance.init();

    
    _reminderService =
        ReminderService(NotificationService.instance.flutterLocalNotificationsPlugin);

    _loadReminders();
  }



  Future<void> _loadReminders() async {
    setState(() => _loading = true);
    final fetched = await _reminderService.fetchReminders();
    _reminders = fetched;
    setState(() => _loading = false);
  }

  List<ReminderModel> _getRemindersForDay(DateTime day) {
    return _reminders.where((r) {
      final local = r.remindAt.toLocal();

      final isSameDate = local.year == day.year &&
          local.month == day.month &&
          local.day == day.day;

      if (isSameDate) return true;

      if (r.daysOfWeek != null && r.daysOfWeek!.isNotEmpty) {
        final weekdayStr = _weekDays[day.weekday - 1];
        return r.daysOfWeek!.contains(weekdayStr);
      }

      return false;
    }).toList();
  }


  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  void _openFormForEdit(ReminderModel reminder) {
    final local = reminder.remindAt.toLocal();
    setState(() {
      _showForm = true;
      _isEditing = true;
      _editingReminder = reminder;

      _titleController.text = reminder.title ?? '';
      _messageController.text = reminder.message;

      _selectedDate = DateTime(local.year, local.month, local.day);
      _selectedTime = TimeOfDay.fromDateTime(local);

      _selectedDays = reminder.daysOfWeek ?? [];
    });
  }

  Future<void> _submitForm() async {
    final isRecurring = _selectedDays.isNotEmpty;

    if (_messageController.text.isEmpty ||
        (!isRecurring && _selectedDate == null) ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Message and time are required. Pick date or recurring days."),
        ),
      );
      return;
    }

    final deckProv = Provider.of<DeckProvider>(context, listen: false);

    DateTime localRemindAt = DateTime(
      (_selectedDate ?? DateTime.now()).year,
      (_selectedDate ?? DateTime.now()).month,
      (_selectedDate ?? DateTime.now()).day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final reminder = ReminderModel(
      id: _editingReminder?.id,
      title: _titleController.text.isNotEmpty ? _titleController.text : null,
      message: _messageController.text,
      deckId: deckProv.selectedDeck?.id,
      remindAt: localRemindAt,
      daysOfWeek: isRecurring ? List<String>.from(_selectedDays) : null,
      status: _editingReminder?.status ?? "active",
    );


    late final Response response;
    if (_isEditing) {
      response = await _reminderService.updateReminder(reminder);
    } else {
      response = await _reminderService.createReminder(reminder);
    }

    if (!mounted) return;

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final int notificationId = data["id"];

      if (_isEditing) {
        await NotificationService.instance.cancelNotification(notificationId);
      }


      _resetForm();
      _loadReminders();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
    }
  }


  void _deleteReminder(ReminderModel r) async {
    if (r.id != null) {
      await NotificationService.instance.cancelNotification(r.id!);
      await _reminderService.deleteReminder(r);
    }
    _loadReminders();
  }


  void _resetForm() {
    setState(() {
      _titleController.clear();
      _messageController.clear();
      _selectedDate = null;
      _selectedTime = null;
      _selectedDays = [];
      _showForm = false;
      _isEditing = false;
      _editingReminder = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reminders"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final router = GoRouter.of(context);
            router.canPop() ? router.pop() : router.go('/dashboard');
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime.utc(2000, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          final reminders = _getRemindersForDay(day);

                          if (reminders.isNotEmpty) {
                            return Positioned(
                              bottom: 4,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: reminders.map((r) {
                                  final isRecurring = r.daysOfWeek != null &&
                                      r.daysOfWeek!.isNotEmpty;
                                  final color = isRecurring
                                      ? Colors.orange
                                      : Theme.of(context).primaryColor;

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color,
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                    ),

                    const SizedBox(height: 16),
                    Expanded(
                      child: _selectedDay == null
                          ? const Center(child: Text("Select a date to view reminders"))
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: _getRemindersForDay(_selectedDay!)
                                  .map((reminder) {
                                final localTime = reminder.remindAt.toLocal();
                                final isRecurring = reminder.daysOfWeek != null &&
                                    reminder.daysOfWeek!.isNotEmpty;

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    title: Text(reminder.title ?? reminder.message),
                                    subtitle: Text(
                                      "Time: ${TimeOfDay.fromDateTime(localTime).format(context)}\n"
                                      "Status: ${reminder.status == "active" ? "Active" : "Paused"}",
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isRecurring)
                                          Switch(
                                            value: reminder.status == "active",
                                            onChanged: (val) async {
                                              final updated = ReminderModel(
                                                id: reminder.id,
                                                title: reminder.title,
                                                message: reminder.message,
                                                deckId: reminder.deckId,
                                                remindAt: reminder.remindAt,
                                                daysOfWeek: reminder.daysOfWeek,
                                                status: val ? "active" : "paused",
                                              );

                                              await _reminderService.updateReminder(updated);
                                              _loadReminders();
                                            },
                                          )
                                        else
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              reminder.status == "active" ? "Active" : "Paused",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: reminder.status == "active"
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _openFormForEdit(reminder),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => _deleteReminder(reminder),
                                        ),
                                      ],
                                    ),

                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
                if (_showForm)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: ReminderForm(
                          titleController: _titleController,
                          messageController: _messageController,
                          selectedDate: _selectedDate,
                          selectedTime: _selectedTime,
                          selectedDays: _selectedDays,
                          weekDays: _weekDays,
                          pickDate: _pickDate,
                          pickTime: _pickTime,
                          toggleDay: (dayStr) {
                            setState(() {
                              if (_selectedDays.contains(dayStr)) {
                                _selectedDays.remove(dayStr);
                              } else {
                                _selectedDays.add(dayStr);
                              }
                            });
                          },
                          submitForm: _submitForm,
                          cancel: _resetForm,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: !_showForm
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => setState(() => _showForm = true),
            )
          : null,
    );
  }
}
