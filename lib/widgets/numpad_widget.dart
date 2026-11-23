import 'package:flutter/material.dart';

class NumpadWidget extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const NumpadWidget({
    Key? key,
    required this.onKeyPress,
    required this.onBackspace,
    required this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          children: [
            // Tombol Clear (C)
            Expanded(
              child: _buildButton(
                child: const Text(
                  'C',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: onClear,
                bgColor: Colors.red.shade50,
              ),
            ),
            const SizedBox(width: 8),
            // Tombol 0
            Expanded(
              child: _buildButton(
                child: const Text(
                  '0',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                onTap: () => onKeyPress('0'),
              ),
            ),
            const SizedBox(width: 8),
            // Tombol 000
            Expanded(
              child: _buildButton(
                child: const Text(
                  '000',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onTap: () => onKeyPress('000'),
              ),
            ),
            const SizedBox(width: 8),
            // Tombol Backspace
            Expanded(
              child: _buildButton(
                child: const Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: Colors.black87,
                ),
                onTap: onBackspace,
                bgColor: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildButton(
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              onTap: () => onKeyPress(key),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildButton({
    required Widget child,
    required VoidCallback onTap,
    Color? bgColor,
  }) {
    return Material(
      color: bgColor ?? Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.teal.withOpacity(0.2),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: child,
        ),
      ),
    );
  }
}
