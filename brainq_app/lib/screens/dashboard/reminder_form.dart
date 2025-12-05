import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController messageController;

  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final List<String> selectedDays;
  final List<String> weekDays;

  final VoidCallback pickDate;
  final VoidCallback pickTime;
  final void Function(String) toggleDay;
  final VoidCallback submitForm;
  final VoidCallback cancel;

  const ReminderForm({
    super.key,
    required this.titleController,
    required this.messageController,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDays,
    required this.weekDays,
    required this.pickDate,
    required this.pickTime,
    required this.toggleDay,
    required this.submitForm,
    required this.cancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title (optional)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(labelText: "Message"),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: pickDate,
                      child: Text(
                        selectedDate != null
                            ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                            : "Pick Date",
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: pickTime,
                      child: Text(
                        selectedTime != null
                            ? selectedTime!.format(context)
                            : "Pick Time",
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 6,
                children: weekDays.map((day) {
                  final isSelected = selectedDays.contains(day);
                  return ChoiceChip(
                    label: Text(day),
                    selected: isSelected,
                    onSelected: (_) => toggleDay(day),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: submitForm,
                child: const Text("Save"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: cancel,
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
